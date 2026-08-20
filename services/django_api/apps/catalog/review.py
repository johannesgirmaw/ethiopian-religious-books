"""Editorial review workflow for books (submit / approve / request-changes /
withdraw). Kept separate from ``publishing.py`` so views stay thin and the
transitions are reusable from admin/Celery. Review status is orthogonal to
``catalog_visibility``: approving a book only marks it ``reviewed``; making it
catalog-visible remains a separate, gated Publish action (see ``publish_book``).
"""

from __future__ import annotations

import logging
from typing import Any

from django.db import transaction

from apps.catalog.models import Book, BookReviewNote
from apps.catalog.permissions import can_manage_book, is_platform_admin
from apps.catalog.publishing import (
    review_comment_plain,
    validate_bible_draft,
    validate_draft_warnings,
)

logger = logging.getLogger(__name__)


class ReviewOutcome:
    """Mirrors ``publishing.PublishBookOutcome`` so views can uniformly turn a
    service result into a DRF ``Response``."""

    def __init__(
        self,
        *,
        ok: bool,
        book: Book | None = None,
        error: dict[str, Any] | None = None,
        status_code: int = 200,
    ):
        self.ok = ok
        self.book = book
        self.error = error
        self.status_code = status_code


def _error(code: str, message: str, status_code: int) -> ReviewOutcome:
    return ReviewOutcome(
        ok=False,
        error={"error": {"code": code, "message": message}},
        status_code=status_code,
    )


def _not_book_creator() -> ReviewOutcome:
    return _error(
        "NOT_BOOK_CREATOR",
        "You can only manage books you created.",
        403,
    )


def _draft_is_publishable(book: Book) -> dict[str, Any] | None:
    """Return a validation dict if the draft is NOT ready to submit (mirrors the
    checks in ``publish_book``), else ``None``."""
    if book.is_bible:
        validation = validate_bible_draft(book)
        if int((validation.get("stats") or {}).get("verses", 0)) == 0:
            return validation
        return None

    # PDF books: require a completed PDF package, not chapters/pages.
    from apps.catalog.pdf_books import latest_pdf_draft, pdf_draft_summary

    pdf_rev = latest_pdf_draft(book)
    if pdf_rev is not None:
        summary = pdf_draft_summary(book) or {}
        if summary.get("ready"):
            return None
        return {
            "stats": {
                "chapters": 0,
                "pages": 0,
                "pdf": 1,
                "pdf_ready": False,
            },
            "warnings": [
                "Upload and complete the PDF package before sending for review."
            ],
        }

    chapters = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    validation = validate_draft_warnings(chapters)
    stats = validation.get("stats") or {}
    if int(stats.get("chapters", 0)) == 0 or int(stats.get("pages", 0)) == 0:
        return validation
    return None


def _invalid_draft_message(validation: dict[str, Any]) -> str:
    stats = validation.get("stats") or {}
    if int(stats.get("pdf", 0)) > 0:
        return "Upload and complete the PDF before sending for review."
    if "verses" in stats:
        return "Add Bible verse content before sending for review."
    return "Add chapters and pages before sending for review."


def submit_for_review(book: Book, user) -> ReviewOutcome:
    """draft -> in_review. Author (or admin) submits a validated draft."""
    if not can_manage_book(book, user):
        return _not_book_creator()
    with transaction.atomic():
        fresh = Book.objects.select_for_update().get(pk=book.pk)
        if fresh.review_status != Book.ReviewStatus.DRAFT:
            return _error(
                "INVALID_REVIEW_STATE",
                "Only a draft can be sent for review.",
                409,
            )
        invalid = _draft_is_publishable(fresh)
        if invalid is not None:
            return ReviewOutcome(
                ok=False,
                error={
                    "error": {
                        "code": "INVALID_DRAFT",
                        "message": _invalid_draft_message(invalid),
                    },
                    "validation": invalid,
                },
                status_code=400,
            )
        fresh.review_status = Book.ReviewStatus.IN_REVIEW
        fresh.save(update_fields=["review_status", "updated_at"])
        BookReviewNote.objects.create(
            book=fresh,
            decision=BookReviewNote.Decision.SUBMITTED,
            reviewer=user,
        )
    return ReviewOutcome(ok=True, book=fresh)


def approve_review(book: Book, reviewer) -> ReviewOutcome:
    """in_review -> reviewed. Reviewer (platform admin) approves."""
    if not is_platform_admin(reviewer):
        return _error("REVIEWER_REQUIRED", "Reviewer access required.", 403)
    with transaction.atomic():
        fresh = Book.objects.select_for_update().get(pk=book.pk)
        if fresh.review_status != Book.ReviewStatus.IN_REVIEW:
            return _error(
                "INVALID_REVIEW_STATE",
                "Only a book under review can be approved.",
                409,
            )
        fresh.review_status = Book.ReviewStatus.REVIEWED
        fresh.save(update_fields=["review_status", "updated_at"])
        BookReviewNote.objects.create(
            book=fresh,
            decision=BookReviewNote.Decision.APPROVED,
            reviewer=reviewer,
        )
    return ReviewOutcome(ok=True, book=fresh)


def reject_review(book: Book, reviewer, comment: str) -> ReviewOutcome:
    """in_review -> draft, with mandatory rich-text feedback. A reviewer cannot
    send a book back without a comment."""
    if not is_platform_admin(reviewer):
        return _error("REVIEWER_REQUIRED", "Reviewer access required.", 403)
    plain = review_comment_plain(comment)
    if not plain:
        return _error(
            "REVIEW_COMMENT_REQUIRED",
            "Write a comment describing the changes needed before sending it back.",
            400,
        )
    with transaction.atomic():
        fresh = Book.objects.select_for_update().get(pk=book.pk)
        if fresh.review_status != Book.ReviewStatus.IN_REVIEW:
            return _error(
                "INVALID_REVIEW_STATE",
                "Only a book under review can be sent back.",
                409,
            )
        fresh.review_status = Book.ReviewStatus.DRAFT
        fresh.save(update_fields=["review_status", "updated_at"])
        BookReviewNote.objects.create(
            book=fresh,
            decision=BookReviewNote.Decision.CHANGES_REQUESTED,
            comment=comment,
            comment_plain=plain,
            reviewer=reviewer,
        )
    return ReviewOutcome(ok=True, book=fresh)


def withdraw_review(book: Book, user) -> ReviewOutcome:
    """in_review -> draft. Author pulls a submission back before a decision."""
    if not can_manage_book(book, user):
        return _not_book_creator()
    with transaction.atomic():
        fresh = Book.objects.select_for_update().get(pk=book.pk)
        if fresh.review_status != Book.ReviewStatus.IN_REVIEW:
            return _error(
                "INVALID_REVIEW_STATE",
                "Only a book under review can be withdrawn.",
                409,
            )
        fresh.review_status = Book.ReviewStatus.DRAFT
        fresh.save(update_fields=["review_status", "updated_at"])
        BookReviewNote.objects.create(
            book=fresh,
            decision=BookReviewNote.Decision.WITHDRAWN,
            reviewer=user,
        )
    return ReviewOutcome(ok=True, book=fresh)
