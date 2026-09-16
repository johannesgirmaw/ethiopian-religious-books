from django.conf import settings
from django.db.models import Q

from apps.catalog.models import Book
from apps.payments.services import final_price, user_owns_book
from apps.study.models import BookReview, ReaderEvent, UserReadingProgress

REVIEW_REQUIRES_PURCHASE = "REVIEW_REQUIRES_PURCHASE"
REVIEW_REQUIRES_READING = "REVIEW_REQUIRES_READING"


def user_has_started_book(user, book: Book) -> bool:
    """True when the user has opened this book (progress or a reader event)."""
    if UserReadingProgress.objects.filter(user=user, book=book).filter(
        Q(progress_percent__gt=0) | ~Q(chapter_key="")
    ).exists():
        return True
    return ReaderEvent.objects.filter(user=user, book=book).exists()


def review_eligibility_error(user, book: Book) -> dict | None:
    """Return an error payload if ``user`` may not create a first review.

    Updating an existing review is always allowed. A priced premium title
    requires a completed purchase; otherwise the user must have started
    reading. When study tools are disabled we cannot observe progress, so
    only the purchase gate applies.
    """
    if book.is_premium and final_price(book) > 0 and not user_owns_book(user, book):
        return {
            "code": REVIEW_REQUIRES_PURCHASE,
            "message": "Purchase this book before leaving a review.",
        }
    if BookReview.objects.filter(user=user, book=book).exists():
        return None
    if not settings.FEATURE_STUDY_TOOLS:
        return None
    if not user_has_started_book(user, book):
        return {
            "code": REVIEW_REQUIRES_READING,
            "message": "Start reading this book before leaving a review.",
        }
    return None
