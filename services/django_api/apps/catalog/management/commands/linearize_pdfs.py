"""Re-linearize existing PDF revisions for Fast Web View streaming."""

from __future__ import annotations

import json

from django.core.management.base import BaseCommand

from apps.catalog.models import BookRevision
from apps.catalog.pdf_books import (
    CONTENT_FORMAT_PDF,
    PdfBookError,
    is_pdf_revision,
    linearize_pdf_object,
)
from apps.catalog.storage_s3 import is_object_storage_configured, put_bytes


class Command(BaseCommand):
    help = (
        "Rewrite PDF content objects as linearized (Fast Web View) files so web "
        "readers can paint page 1 via HTTP Range before the full download finishes."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            action="store_true",
            help="Re-linearize even when pikepdf reports the file is already linearized.",
        )
        parser.add_argument(
            "--published-only",
            action="store_true",
            help="Only process published PDF revisions (default: all with a content key).",
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

        force = bool(options["force"])
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
            if not is_pdf_revision(rev) or not rev.content_object_key:
                skipped += 1
                continue
            try:
                size, digest, linearized = linearize_pdf_object(
                    rev.content_object_key, force=force
                )
            except PdfBookError as exc:
                failed += 1
                self.stderr.write(
                    f"  fail {rev.id}: {exc.code} {exc.message}"
                )
                continue
            except Exception as exc:  # pragma: no cover - storage/runtime
                failed += 1
                self.stderr.write(f"  fail {rev.id}: {exc}")
                continue

            update_fields: list[str] = []
            if rev.total_bytes != size:
                rev.total_bytes = size
                update_fields.append("total_bytes")
            if rev.content_sha256 != digest:
                rev.content_sha256 = digest
                update_fields.append("content_sha256")
            if update_fields:
                rev.save(update_fields=update_fields)

            if rev.manifest_object_key:
                try:
                    manifest = {
                        "format": CONTENT_FORMAT_PDF,
                        "version": 1,
                        "filename": "content.pdf",
                        "size_bytes": size,
                        "linearized": linearized,
                    }
                    # Preserve display filename when the existing manifest has one.
                    from apps.catalog.storage_s3 import get_object_bytes

                    try:
                        raw = get_object_bytes(rev.manifest_object_key)
                        data = json.loads(raw.decode("utf-8"))
                        if isinstance(data, dict) and data.get("filename"):
                            manifest["filename"] = str(data["filename"])
                    except Exception:
                        pass
                    put_bytes(
                        rev.manifest_object_key,
                        json.dumps(manifest, ensure_ascii=False).encode("utf-8"),
                        content_type="application/json",
                    )
                except Exception:
                    self.stderr.write(
                        f"  warn {rev.id}: content linearized but manifest update failed"
                    )

            ok += 1
            flag = "linearized" if linearized else "not-linearized"
            self.stdout.write(f"  ok {rev.id} ({size} bytes, {flag})")

        self.stdout.write(
            self.style.SUCCESS(
                f"linearize_pdfs: ok={ok} skipped={skipped} failed={failed}"
            )
        )
