"""Context for the custom admin index (dashboard)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone


def dashboard_callback(request, context: dict[str, Any]) -> dict[str, Any]:
    from apps.accounts.models import User
    from apps.catalog.models import Book, BookRevision
    from apps.legal.models import LegalAcceptance
    from apps.study.models import (
        ReaderEvent,
        UserBookmark,
        UserHighlight,
        UserNote,
        UserReadingProgress,
    )

    now = timezone.now()
    week_ago = now - timedelta(days=7)
    day_ago = now - timedelta(days=1)

    published_books = Book.objects.filter(catalog_visibility=Book.Visibility.PUBLISHED).count()
    hidden_books = Book.objects.filter(catalog_visibility=Book.Visibility.HIDDEN).count()
    draft_revisions = BookRevision.objects.filter(status=BookRevision.Status.DRAFT).count()

    reader_events_week = ReaderEvent.objects.filter(created_at__gte=week_ago).count()
    reader_events_day = ReaderEvent.objects.filter(created_at__gte=day_ago).count()

    signups_week = User.objects.filter(date_joined__gte=week_ago).count()

    events_by_name = list(
        ReaderEvent.objects.filter(created_at__gte=week_ago)
        .values("event_name")
        .annotate(total=Count("id"))
        .order_by("-total")[:12]
    )

    events_by_day = list(
        ReaderEvent.objects.filter(created_at__gte=week_ago)
        .annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(total=Count("id"))
        .order_by("day")
    )
    max_day_total = max((row["total"] for row in events_by_day), default=0)
    for row in events_by_day:
        if max_day_total:
            row["bar_height"] = max(6, int(8 + (row["total"] / max_day_total) * 112))
        else:
            row["bar_height"] = 6

    recent_events = list(
        ReaderEvent.objects.select_related("user", "book")
        .order_by("-created_at")[:15]
        .values(
            "id",
            "event_name",
            "created_at",
            "chapter_key",
            "page_number",
            "user__email",
            "book__title",
        )
    )

    context["dashboard"] = {
        "counts": {
            "users": User.objects.count(),
            "active_users": User.objects.filter(is_active=True).count(),
            "books": Book.objects.count(),
            "published_books": published_books,
            "hidden_books": hidden_books,
            "draft_revisions": draft_revisions,
            "bookmarks": UserBookmark.objects.count(),
            "highlights": UserHighlight.objects.count(),
            "notes": UserNote.objects.count(),
            "progress_rows": UserReadingProgress.objects.count(),
            "legal_acceptances": LegalAcceptance.objects.count(),
        },
        "activity": {
            "reader_events_week": reader_events_week,
            "reader_events_day": reader_events_day,
            "signups_week": signups_week,
        },
        "charts": {
            "events_by_name": events_by_name,
            "events_by_day": events_by_day,
        },
        "recent_events": recent_events,
    }
    return context
