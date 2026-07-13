"""Domain logic for commissions, pricing and the revenue ledger.

Kept separate from views/serializers so it is unit-testable in isolation and can
be reused from the API, the Django admin and Celery tasks.
"""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction as db_transaction
from django.utils import timezone

from apps.catalog.models import Book
from apps.payments.enums import AuthorApplicationStatus, TransactionStatus
from apps.payments.models import (
    AuditLog,
    AuthorApplication,
    AuthorCommission,
    AuthorProfile,
    PaymentTransaction,
    PlatformSettings,
    RevenueLedger,
)

_CENTS = Decimal("0.01")
_HUNDRED = Decimal("100")


def _money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(_CENTS, rounding=ROUND_HALF_UP)


def final_price(book: Book) -> Decimal:
    """The amount a buyer actually pays: ``sale_price`` when set, else ``price``."""
    if book.sale_price is not None:
        return _money(book.sale_price)
    return _money(book.price or Decimal("0"))


def user_owns_book(user, book: Book) -> bool:
    """Whether ``user`` is entitled to read ``book`` (including offline).

    True when the book is free (``final_price`` <= 0) or the user has a COMPLETED
    purchase for it. This is the single gate shared by the download endpoint, the
    offline-license endpoint and the reader's buy-gate, so they never disagree.
    Mirrors the query in :class:`apps.payments.views.EntitlementsView`.
    """
    if final_price(book) <= 0:
        return True
    if user is None or not getattr(user, "is_authenticated", False):
        return False
    return PaymentTransaction.objects.filter(
        user=user, book=book, status=TransactionStatus.COMPLETED
    ).exists()


def resolve_commission_percent(
    book: Book, settings_obj: PlatformSettings | None = None
) -> Decimal:
    """Resolve the effective commission percent for a book.

    Priority (highest first):
      1. Book.commission_percent          (if book overrides are allowed)
      2. AuthorCommission.commission_percent for book.author (if author
         overrides are allowed)
      3. PlatformSettings.default_commission_percent
    """
    settings_obj = settings_obj or PlatformSettings.get_solo()

    if settings_obj.allow_book_override and book.commission_percent is not None:
        return Decimal(book.commission_percent)

    if settings_obj.allow_author_override and book.author_id:
        author_commission = AuthorCommission.objects.filter(
            author_id=book.author_id
        ).first()
        if author_commission is not None:
            return Decimal(author_commission.commission_percent)

    return Decimal(settings_obj.default_commission_percent)


def compute_amounts(
    book: Book, settings_obj: PlatformSettings | None = None
) -> dict[str, Decimal]:
    """Return sale/commission/author split for one purchase of ``book``."""
    settings_obj = settings_obj or PlatformSettings.get_solo()
    sale = final_price(book)
    percent = resolve_commission_percent(book, settings_obj)
    commission = _money(sale * percent / _HUNDRED)
    author = _money(sale - commission)
    return {
        "sale_amount": sale,
        "commission_percent": percent,
        "commission_amount": commission,
        "author_amount": author,
    }


@db_transaction.atomic
def create_revenue_ledger(txn: PaymentTransaction) -> RevenueLedger:
    """Create (idempotently) the ledger row for a transaction.

    The ledger is the reporting source of truth, so this is the single place a
    row is written. Safe to call more than once — returns the existing entry.
    """
    existing = RevenueLedger.objects.filter(transaction=txn).first()
    if existing is not None:
        return existing

    ledger = RevenueLedger.objects.create(
        transaction=txn,
        author_id=txn.book.author_id,
        book=txn.book,
        currency=txn.currency,
        sale_amount=txn.amount,
        commission_amount=txn.commission_amount,
        author_amount=txn.author_amount,
    )
    return ledger


@db_transaction.atomic
def complete_transaction(txn: PaymentTransaction, *, reviewer=None) -> PaymentTransaction:
    """Mark a transaction COMPLETED and write its revenue-ledger entry."""
    txn.status = TransactionStatus.COMPLETED
    if reviewer is not None:
        txn.reviewed_by = reviewer
        txn.reviewed_at = timezone.now()
    txn.save(update_fields=["status", "reviewed_by", "reviewed_at", "updated_at"])
    create_revenue_ledger(txn)
    return txn


@db_transaction.atomic
def reject_transaction(
    txn: PaymentTransaction, *, reviewer=None, note: str = ""
) -> PaymentTransaction:
    txn.status = TransactionStatus.REJECTED
    txn.review_note = note or txn.review_note
    if reviewer is not None:
        txn.reviewed_by = reviewer
        txn.reviewed_at = timezone.now()
    txn.save(
        update_fields=[
            "status",
            "review_note",
            "reviewed_by",
            "reviewed_at",
            "updated_at",
        ]
    )
    return txn


def notify_user(user, *, title: str, body: str = "") -> None:
    """Create an in-app notification for ``user`` (best-effort).

    Kept here so the study ``UserNotification`` model has a single writer reused
    by the API/admin/Celery, mirroring how ``record_audit`` centralises audit rows.
    """
    # Imported lazily to avoid a payments -> study import at module load.
    from apps.study.models import UserNotification

    if user is None or not getattr(user, "pk", None):
        return
    UserNotification.objects.create(
        user=user,
        kind=UserNotification.Kind.INFO,
        title=title[:200],
        body=(body or "")[:500],
    )


@db_transaction.atomic
def submit_author_application(user, validated_data: dict) -> AuthorApplication:
    """Create or update the user's pending author application.

    Idempotent on the one-to-one: re-submitting after a rejection resets the
    application to ``PENDING`` and clears the prior review decision.
    """
    defaults = {
        **validated_data,
        "status": AuthorApplicationStatus.PENDING,
        "reviewed_by": None,
        "reviewed_at": None,
        "review_note": "",
    }
    application, _ = AuthorApplication.objects.update_or_create(
        user=user, defaults=defaults
    )
    return application


@db_transaction.atomic
def approve_author_application(
    application: AuthorApplication, *, reviewer=None
) -> AuthorApplication:
    """Approve an application: promote the applicant and build their profile."""
    application.status = AuthorApplicationStatus.APPROVED
    application.review_note = ""
    if reviewer is not None:
        application.reviewed_by = reviewer
        application.reviewed_at = timezone.now()
    application.save(
        update_fields=[
            "status",
            "review_note",
            "reviewed_by",
            "reviewed_at",
            "updated_at",
        ]
    )

    applicant = application.user
    if getattr(applicant, "role", "") != "author":
        applicant.role = "author"
        applicant.save(update_fields=["role"])

    # Materialise a verified publishing profile from the application fields.
    AuthorProfile.objects.update_or_create(
        user=applicant,
        defaults={
            "pen_name": application.pen_name or application.full_name,
            "bio": application.bio,
            "photo_object_key": application.photo_object_key,
            "phone": application.phone,
            "country": application.country,
            "payment_email": application.payment_email,
            "telebirr_number": application.telebirr_number,
            "is_verified": True,
        },
    )

    notify_user(
        applicant,
        title="You're now an author",
        body="Your author application was approved. You can now publish books.",
    )
    return application


@db_transaction.atomic
def reject_author_application(
    application: AuthorApplication, *, reviewer=None, note: str = ""
) -> AuthorApplication:
    application.status = AuthorApplicationStatus.REJECTED
    application.review_note = note or application.review_note
    if reviewer is not None:
        application.reviewed_by = reviewer
        application.reviewed_at = timezone.now()
    application.save(
        update_fields=[
            "status",
            "review_note",
            "reviewed_by",
            "reviewed_at",
            "updated_at",
        ]
    )

    body = "Your author application was not approved."
    if application.review_note:
        body = f"{body} Reason: {application.review_note}"
    notify_user(application.user, title="Author application update", body=body)
    return application


def record_audit(
    *,
    actor=None,
    action: str,
    target_type: str = "",
    target_id: str = "",
    metadata: dict | None = None,
    request=None,
) -> AuditLog:
    """Append an immutable audit-trail entry for a sensitive action."""
    ip = None
    if request is not None:
        ip = (
            request.META.get("HTTP_X_FORWARDED_FOR", "").split(",")[0].strip()
            or request.META.get("REMOTE_ADDR")
            or None
        )
    return AuditLog.objects.create(
        actor=actor if (actor and getattr(actor, "pk", None)) else None,
        action=action,
        target_type=target_type,
        target_id=str(target_id),
        metadata=metadata or {},
        ip_address=ip,
    )
