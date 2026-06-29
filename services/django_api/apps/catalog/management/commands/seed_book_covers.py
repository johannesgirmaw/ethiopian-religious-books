"""Generate and upload cover images for books missing ``cover_object_key``."""

from __future__ import annotations

from django.core.management.base import BaseCommand

from apps.catalog.cover_art import assign_cover_for_book, render_cover_png
from apps.catalog.cover_fetch import assign_internet_cover_for_book
from apps.catalog.models import Book
from apps.catalog.storage_s3 import ensure_bucket, is_object_storage_configured


class Command(BaseCommand):
    help = (
        "Fetch or generate cover art for books and upload to object storage. "
        "Default source tries Open Library / Wikimedia, then falls back to "
        "generated art. Skips books that already have a cover unless --force."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Replace existing covers.",
        )
        parser.add_argument(
            "--source",
            choices=("internet", "generated"),
            default="internet",
            help="internet (default): download from public sources; generated: local PNG art.",
        )
        parser.add_argument(
            "--book-id",
            type=str,
            default="",
            help="Only process a single book UUID.",
        )

    def handle(self, *args, **options):
        force = options["force"]
        book_id = (options["book_id"] or "").strip()
        source = options["source"]

        if not is_object_storage_configured():
            self.stderr.write(
                self.style.ERROR(
                    "Object storage is not configured (AWS_S3_ENDPOINT_URL / "
                    "AWS_STORAGE_BUCKET_NAME). Start MinIO with `make infra-up`."
                )
            )
            return

        try:
            ensure_bucket()
        except Exception as exc:  # pragma: no cover - dev convenience
            self.stderr.write(self.style.WARNING(f"ensure_bucket: {exc}"))

        qs = Book.objects.all().order_by("created_at")
        if book_id:
            qs = qs.filter(pk=book_id)
        elif not force:
            qs = qs.filter(cover_object_key="")

        books = list(qs)
        if not books:
            self.stdout.write(self.style.SUCCESS("seed_book_covers: nothing to do"))
            return

        updated = 0
        for idx, book in enumerate(books):
            try:
                ok = False
                if source == "internet":
                    ok = assign_internet_cover_for_book(
                        book,
                        force=force,
                        fallback_generator=lambda b: render_cover_png(
                            b.title,
                            subtitle=b.subtitle or "",
                            author=b.author_compiler or "",
                            index=idx,
                        ),
                    )
                else:
                    ok = assign_cover_for_book(book, index=idx, force=force)
                if ok:
                    updated += 1
                    self.stdout.write(f"  cover ({source}): {book.title}")
                else:
                    self.stderr.write(self.style.WARNING(f"  skipped: {book.title}"))
            except Exception as exc:
                self.stderr.write(self.style.WARNING(f"  failed: {book.title} — {exc}"))

        self.stdout.write(
            self.style.SUCCESS(f"seed_book_covers: uploaded {updated}/{len(books)} cover(s)")
        )
