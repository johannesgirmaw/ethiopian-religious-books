from django.core.management.base import BaseCommand

from apps.catalog.models import Book


def _genre_for(title: str, subtitle: str) -> str:
    t = f"{title} {subtitle}".lower()
    if any(k in t for k in ("mezmur", "psalm", "dawit")):
        return "psalms"
    if any(k in t for k in ("wudase", "weddase", "mary", "kidane")):
        return "marian"
    if any(k in t for k in ("kidase", "qeddase", "liturgy", "anaphora")):
        return "liturgy"
    if any(k in t for k in ("senkes", "synax", "calendar")):
        return "synaxarium"
    if any(k in t for k in ("gedle", "gedl", "saint", "hagi")):
        return "saints"
    return "other"


class Command(BaseCommand):
    help = (
        "Idempotent backfill of derivable book metadata. Sets `genre` from the "
        "title for books still on the default 'other' genre. Ratings/readers are "
        "left untouched (they accrue from real reviews/reads)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Re-derive genre for every book, not only those on 'other'.",
        )

    def handle(self, *args, **options):
        force = options["force"]
        updated = 0
        for book in Book.objects.all():
            if not force and book.genre and book.genre != "other":
                continue
            new_genre = _genre_for(book.title or "", book.subtitle or "")
            if new_genre != book.genre:
                book.genre = new_genre
                book.save(update_fields=["genre"])
                updated += 1
        self.stdout.write(self.style.SUCCESS(f"backfill_book_metadata: updated {updated} book(s)"))
