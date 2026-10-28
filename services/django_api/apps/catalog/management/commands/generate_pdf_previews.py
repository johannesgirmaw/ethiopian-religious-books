"""Rebuild Look Inside sample PDFs for revisions with a page list."""

from __future__ import annotations

from django.core.management.base import BaseCommand

from apps.catalog.models import BookRevision
from apps.catalog.pdf_books import (
    CONTENT_FORMAT_PDF,
    PdfBookError,
    _coerce_preview_page_list,
    build_pdf_preview,
    is_pdf_revision,
)
from apps.catalog.storage_s3 import is_object_storage_configured


class Command(BaseCommand):
    help = (
        "Rebuild preview.pdf sample objects for PDF revisions that already have "
        "preview_page_numbers set. Does not invent page lists for older books."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--published-only",
            action="store_true",
            help="Only process published PDF revisions.",
        )
        parser.add_argument(
            "--book-id",
            type=str,
            default="",
            help="Limit to a single book UUID.",
        )

    def handle(self, *args, **options):
        if not is_object_storage_configured():
            self.stderr.write(self.style.ERROR("Object storage is not configured."))
            return

        qs = BookRevision.objects.filter(content_format=CONTENT_FORMAT_PDF).exclude(
            content_object_key__isnull=True
        ).exclude(content_object_key="")
        if options["published_only"]:
            qs = qs.filter(status=BookRevision.Status.PUBLISHED)
        book_id = (options.get("book_id") or "").strip()
        if book_id:
            qs = qs.filter(book_id=book_id)

        ok = 0
        skipped = 0
        failed = 0
        for rev in qs.iterator():
            if not is_pdf_revision(rev):
                skipped += 1
                continue
            pages = _coerce_preview_page_list(rev.preview_page_numbers)
            if not pages:
                skipped += 1
                continue
            try:
                build_pdf_preview(rev)
            except PdfBookError as exc:
                failed += 1
                self.stderr.write(f"  fail {rev.id}: {exc.code} {exc.message}")
                continue
            except Exception as exc:  # pragma: no cover - storage/runtime
                failed += 1
                self.stderr.write(f"  fail {rev.id}: {exc}")
                continue
            ok += 1
            self.stdout.write(
                f"  ok {rev.id} pages={pages} key={rev.preview_object_key}"
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"generate_pdf_previews: ok={ok} skipped={skipped} failed={failed}"
            )
        )
