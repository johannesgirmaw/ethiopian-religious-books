"""Permanent deletion of *draft* books.

Deleting a book is irreversible and cascades to its revisions, chapters, pages,
content index, review notes, offline-download ledger rows and every reader's
study data for that book — so it is deliberately restricted to books that are
still in the draft stage of the editorial lifecycle and were never sold.

The rules (all must hold):

* the caller can manage the book (``can_manage_book``);
* ``review_status == draft`` — a book sitting ``in_review`` or already
  ``reviewed`` must be withdrawn/reset first;
* ``catalog_visibility != published`` — unpublish it first;
* no ``PaymentTransaction`` / ``RevenueLedger`` rows reference it (those FKs are
  ``PROTECT``, and purchase history must outlive any book).

Kept out of the views, like ``publishing.py``/``review.py``, so admin and Celery
can reuse it.
"""

from __future__ import annotations

import logging
from typing import Any

from django.db import transaction
from django.db.models import ProtectedError

from apps.catalog.models import Book
from apps.catalog.permissions import can_manage_book
from apps.catalog.storage_s3 import delete_objects

logger = logging.getLogger(__name__)


class DeleteBookOutcome:
    """Mirrors ``publishing.PublishBookOutcome`` so views can uniformly turn a
    service result into a DRF ``Response``."""

    __slots__ = ("ok", "error", "status_code")

    def __init__(
        self,
        *,
        ok: bool,
        error: dict[str, Any] | None = None,
        status_code: int = 204,
    ):
        self.ok = ok
        self.error = error
        self.status_code = status_code


def _error(code: str, message: str, status_code: int) -> DeleteBookOutcome:
    return DeleteBookOutcome(
        ok=False,
        error={"error": {"code": code, "message": message}},
        status_code=status_code,
    )


def book_is_deletable(book: Book) -> bool:
    """True when ``book`` is a draft that has never been published or sold.

    Ownership is NOT checked here — this is the lifecycle half of the rule, used
    by the API and serialized to clients so the UI can hide the action.
    """
    if book.catalog_visibility == Book.Visibility.PUBLISHED:
        return False
    if book.review_status != Book.ReviewStatus.DRAFT:
        return False
    if book.published_revision_id is not None:
        return False
    return not _has_financial_records(book)


def _has_financial_records(book: Book) -> bool:
    return book.transactions.exists() or book.revenue_entries.exists()


def _stored_object_keys(book: Book) -> list[str]:
    keys = [book.cover_object_key]
    for manifest_key, content_key in book.revisions.values_list(
        "manifest_object_key", "content_object_key"
    ):
        keys.append(manifest_key)
        keys.append(content_key)
    return [k for k in keys if k]


def delete_book(book: Book, user) -> DeleteBookOutcome:
    """Permanently delete a draft ``book`` after checking every guard above."""
    if not can_manage_book(book, user):
        return _error(
            "NOT_BOOK_CREATOR",
            "You can only delete books you created.",
            403,
        )
    if book.catalog_visibility == Book.Visibility.PUBLISHED:
        return _error(
            "BOOK_PUBLISHED",
            "Unpublish this book before deleting it.",
            409,
        )
    if book.review_status != Book.ReviewStatus.DRAFT:
        return _error(
            "BOOK_NOT_DRAFT",
            "Only books in draft can be deleted. Withdraw it from review first.",
            409,
        )
    if book.published_revision_id is not None:
        return _error(
            "BOOK_PREVIOUSLY_PUBLISHED",
            "This book has a published revision and cannot be deleted.",
            409,
        )
    if _has_financial_records(book):
        return _error(
            "BOOK_HAS_PURCHASES",
            "This book has purchase history and cannot be deleted.",
            409,
        )

    # Collect the blob keys before the cascade wipes the revision rows.
    object_keys = _stored_object_keys(book)
    book_id = book.id
    try:
        with transaction.atomic():
            book.delete()
    except ProtectedError:
        # Safety net: a PROTECT-ed relation added later would otherwise 500.
        logger.warning("refused to delete book %s: protected relations", book_id)
        return _error(
            "BOOK_IN_USE",
            "This book is referenced by other records and cannot be deleted.",
            409,
        )

    delete_objects(object_keys)
    logger.info("deleted draft book %s by user %s", book_id, getattr(user, "id", None))
    return DeleteBookOutcome(ok=True)
