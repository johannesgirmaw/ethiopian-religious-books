"""Look Inside PDF preview: page-list validation, sample build, API gates."""

from __future__ import annotations

from decimal import Decimal
from io import BytesIO
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase, override_settings
from rest_framework.test import APIClient

from apps.catalog.models import Book, BookRevision
from apps.catalog.pdf_books import (
    CONTENT_FORMAT_PDF,
    PdfBookError,
    build_pdf_preview,
    normalize_preview_page_numbers,
)

User = get_user_model()


def _multi_page_pdf_bytes(n: int = 5) -> bytes:
    import pikepdf

    pdf = pikepdf.Pdf.new()
    for _ in range(n):
        pdf.add_blank_page(page_size=(200, 200))
    buf = BytesIO()
    pdf.save(buf)
    return buf.getvalue()


class NormalizePreviewPagesTests(SimpleTestCase):
    def test_sorts_unique(self):
        self.assertEqual(
            normalize_preview_page_numbers([3, 1, 3, 2], page_count=10),
            [1, 2, 3],
        )

    def test_empty(self):
        self.assertEqual(normalize_preview_page_numbers([], page_count=10), [])

    def test_rejects_out_of_range(self):
        with self.assertRaises(PdfBookError) as ctx:
            normalize_preview_page_numbers([1, 99], page_count=5)
        self.assertEqual(ctx.exception.code, "PREVIEW_PAGE_OUT_OF_RANGE")

    def test_rejects_zero(self):
        with self.assertRaises(PdfBookError) as ctx:
            normalize_preview_page_numbers([0, 1], page_count=5)
        self.assertEqual(ctx.exception.code, "INVALID_PREVIEW_PAGES")

    def test_rejects_too_many(self):
        with self.assertRaises(PdfBookError) as ctx:
            normalize_preview_page_numbers(list(range(1, 12)), page_count=20)
        self.assertEqual(ctx.exception.code, "PREVIEW_TOO_MANY_PAGES")


class BuildPdfPreviewTests(SimpleTestCase):
    @patch("apps.catalog.pdf_books.put_file")
    @patch("apps.catalog.pdf_books.download_object_to_path")
    @patch("apps.catalog.pdf_books.is_object_storage_configured", return_value=True)
    def test_extracts_listed_pages(self, _cfg, mock_download, mock_put):
        import hashlib

        import pikepdf

        raw = _multi_page_pdf_bytes(5)

        def _download(_key, dest):
            with open(dest, "wb") as fh:
                fh.write(raw)
            return len(raw)

        captured = {}

        def _put(key, path, content_type="application/pdf"):
            with open(path, "rb") as fh:
                body = fh.read()
            captured["body"] = body
            captured["key"] = key
            with pikepdf.open(BytesIO(body)) as pdf:
                self.assertEqual(len(pdf.pages), 3)
            return hashlib.sha256(body).hexdigest()

        mock_download.side_effect = _download
        mock_put.side_effect = _put

        book = Book(title="T")
        book.id = "11111111-1111-1111-1111-111111111111"
        rev = BookRevision(
            book=book,
            revision_number=1,
            status=BookRevision.Status.DRAFT,
            content_format=CONTENT_FORMAT_PDF,
            content_object_key="books/x/content.pdf",
            preview_page_numbers=[1, 3, 5],
        )
        rev.id = "22222222-2222-2222-2222-222222222222"
        # Avoid DB save — patch save
        with patch.object(BookRevision, "save"):
            out = build_pdf_preview(rev)
        self.assertEqual(out.preview_page_numbers, [1, 3, 5])
        self.assertTrue(out.preview_object_key.endswith("/preview.pdf"))
        self.assertTrue(captured["body"].startswith(b"%PDF-"))


@override_settings(
    REST_FRAMEWORK={
        "DEFAULT_AUTHENTICATION_CLASSES": (
            "rest_framework.authentication.SessionAuthentication",
        ),
        "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.AllowAny",),
        "UNAUTHENTICATED_USER": "django.contrib.auth.models.AnonymousUser",
    }
)
class PdfPreviewApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="r@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def _pdf_book(self, *, price="5.00", with_preview=True):
        book = Book.objects.create(
            title="Paid PDF",
            chapters_draft=[],
            catalog_visibility=Book.Visibility.PUBLISHED,
            is_premium=True,
            price=Decimal(price),
        )
        rev = BookRevision.objects.create(
            book=book,
            revision_number=1,
            status=BookRevision.Status.PUBLISHED,
            content_format=CONTENT_FORMAT_PDF,
            content_object_key="books/x/content.pdf",
            total_bytes=100,
            preview_page_numbers=[1, 3, 5] if with_preview else [],
            preview_object_key="books/x/preview.pdf" if with_preview else "",
        )
        book.published_revision = rev
        book.save(update_fields=["published_revision"])
        return book, rev

    @patch("apps.catalog.views.is_object_storage_configured", return_value=True)
    @patch("apps.catalog.views.head_object", return_value={"ContentLength": 50})
    @patch("apps.catalog.views.presign_get", return_value="https://minio/preview")
    @patch("apps.catalog.views.pdf_object_looks_linearized", return_value=True)
    def test_non_entitled_can_open_preview(self, *_mocks):
        book, _ = self._pdf_book()
        # Full PDF still blocked
        full = self.client.get(f"/v1/books/{book.id}/pdf")
        self.assertEqual(full.status_code, 403)
        self.assertEqual(full.data["error"]["code"], "NOT_ENTITLED")

        preview = self.client.get(f"/v1/books/{book.id}/pdf/preview")
        self.assertEqual(preview.status_code, 200)
        self.assertEqual(preview.data["url"], "https://minio/preview")
        self.assertTrue(preview.data["preview"])
        self.assertEqual(preview.data["preview_page_count"], 3)
        self.assertNotIn("content.pdf", preview.data.get("url", ""))

    def test_no_preview_returns_404(self):
        book, _ = self._pdf_book(with_preview=False)
        with patch("apps.catalog.views.is_object_storage_configured", return_value=True):
            res = self.client.get(f"/v1/books/{book.id}/pdf/preview")
        self.assertEqual(res.status_code, 404)
        self.assertEqual(res.data["error"]["code"], "NO_PREVIEW")

    def test_serializer_has_preview(self):
        book, _ = self._pdf_book()
        res = self.client.get(f"/v1/books/{book.id}")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data["has_preview"])
        self.assertEqual(res.data["preview_page_count"], 3)
