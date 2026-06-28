import json
from datetime import datetime, timezone

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.catalog.cover_art import assign_cover_for_book
from apps.catalog.models import Book, BookRevision
from apps.catalog.storage_s3 import ensure_bucket, put_bytes
from apps.legal.models import LegalDocument

User = get_user_model()


class Command(BaseCommand):
    help = "Idempotent dev seed: admin user, legal docs, sample published book."

    def handle(self, *args, **options):
        self._legal_docs()
        admin, _ = User.objects.get_or_create(
            email="admin@localhost",
            defaults={
                "display_name": "Admin",
                "is_staff": True,
                "is_superuser": True,
            },
        )
        admin.is_staff = True
        admin.is_superuser = True
        admin.display_name = admin.display_name or "Admin"
        admin.set_password("adminadminadmin")
        admin.save()

        reader, _ = User.objects.get_or_create(
            email="reader@localhost",
            defaults={"role": "reader", "display_name": "Reader"},
        )
        reader.role = "reader"
        reader.display_name = reader.display_name or "Reader"
        reader.set_password("readerreader")
        reader.save()

        book, _ = Book.objects.get_or_create(
            title="Sample Ethiopian religious text (dev)",
            defaults={
                "subtitle": "",
                "summary": "Placeholder for local development.",
                "author_compiler": "Publisher",
                "primary_language": "am",
                "script_tags": ["Ethi"],
                "catalog_visibility": Book.Visibility.HIDDEN,
                "created_by": admin,
            },
        )

        rev, _ = BookRevision.objects.get_or_create(
            book=book,
            revision_number=1,
            defaults={
                "status": BookRevision.Status.DRAFT,
                "content_format": "html_chunks",
                "total_bytes": 0,
                "created_by": admin,
            },
        )

        if settings.AWS_S3_ENDPOINT_URL and settings.AWS_STORAGE_BUCKET_NAME:
            try:
                ensure_bucket()
                prefix = f"seed/{book.id}/{rev.id}"
                manifest_body = json.dumps(
                    {"format": "html_chunks", "version": 1, "chunks": []},
                    separators=(",", ":"),
                ).encode("utf-8")
                html = b"<html><body><p>Dev sample chapter.</p></body></html>"
                mkey = f"{prefix}/manifest.json"
                ckey = f"{prefix}/content.html"
                mhash = put_bytes(mkey, manifest_body, "application/json")
                chash = put_bytes(ckey, html, "text/html")
                rev.manifest_object_key = mkey
                rev.content_object_key = ckey
                rev.manifest_sha256 = mhash
                rev.content_sha256 = chash
                rev.total_bytes = len(manifest_body) + len(html)
            except Exception as exc:
                self.stderr.write(self.style.WARNING(f"seed_dev: MinIO upload skipped ({exc})"))
        else:
            self.stderr.write(self.style.WARNING("seed_dev: AWS_S3_ENDPOINT_URL unset; book has no package in S3"))

        rev.status = BookRevision.Status.PUBLISHED
        rev.save()
        book.published_revision = rev
        book.catalog_visibility = Book.Visibility.PUBLISHED
        book.save()
        if assign_cover_for_book(book, index=0):
            self.stdout.write("seed_dev: cover uploaded for sample book")

        self.stdout.write(self.style.SUCCESS("seed_dev: ok (admin@localhost / adminadminadmin)"))

    def _legal_docs(self):
        now = datetime.now(timezone.utc)
        base = "https://example.com/legal/"
        for doc_type, ver in (("terms", 1), ("privacy", 1)):
            LegalDocument.objects.get_or_create(
                doc_type=doc_type,
                version=ver,
                defaults={
                    "content_url": f"{base}{doc_type}-v{ver}.html",
                    "effective_at": now,
                },
            )
