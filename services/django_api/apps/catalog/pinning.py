"""Catalog pin order: pinned books lead Explore in ascending pin_order."""

from __future__ import annotations

from django.db.models import Max

from apps.catalog.models import Book


def pin_book(book: Book) -> Book:
    """Pin ``book`` after the current last pin (incrementing order).

    Already-pinned books keep their existing rank.
    """
    if book.pin_order is not None:
        return book
    current_max = Book.objects.exclude(pin_order__isnull=True).aggregate(
        m=Max("pin_order")
    )["m"]
    book.pin_order = 1 if current_max is None else int(current_max) + 1
    book.save(update_fields=["pin_order", "updated_at"])
    return book


def unpin_book(book: Book) -> Book:
    """Clear the pin. Remaining pins keep their ranks (no renumber)."""
    if book.pin_order is None:
        return book
    book.pin_order = None
    book.save(update_fields=["pin_order", "updated_at"])
    return book
