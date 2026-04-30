from django.core.management.base import BaseCommand

from apps.catalog.models import BookRevision
from apps.catalog.search_index import rebuild_revision_index


class Command(BaseCommand):
    help = "Backfill chapter/page/search index for published revisions."

    def add_arguments(self, parser):
        parser.add_argument("--book-id", type=str, default="")

    def handle(self, *args, **options):
        book_id = (options.get("book_id") or "").strip()
        qs = BookRevision.objects.filter(status=BookRevision.Status.PUBLISHED).select_related("book")
        if book_id:
            qs = qs.filter(book_id=book_id)
        count = 0
        for rev in qs.iterator():
            rebuild_revision_index(rev)
            count += 1
            self.stdout.write(self.style.SUCCESS(f"Indexed revision {rev.id}"))
        self.stdout.write(self.style.SUCCESS(f"Completed. Indexed {count} revision(s)."))
