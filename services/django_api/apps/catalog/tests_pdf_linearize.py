"""Unit tests for PDF Fast Web View linearization helpers."""

from __future__ import annotations

from io import BytesIO
from unittest.mock import patch

from django.test import SimpleTestCase

from apps.catalog.pdf_books import PDF_MAGIC, linearize_pdf_object, pdf_object_looks_linearized


def _blank_pdf_bytes(*, linearize: bool = False) -> bytes:
    import pikepdf

    pdf = pikepdf.Pdf.new()
    pdf.add_blank_page(page_size=(200, 200))
    buf = BytesIO()
    pdf.save(buf, linearize=linearize)
    return buf.getvalue()


class LinearizePdfObjectTests(SimpleTestCase):
    @patch("apps.catalog.pdf_books.put_file")
    @patch("apps.catalog.pdf_books.download_object_to_path")
    def test_rewrites_non_linearized_pdf(self, mock_download, mock_put):
        import hashlib

        import pikepdf

        raw = _blank_pdf_bytes(linearize=False)
        self.assertTrue(raw.startswith(PDF_MAGIC))
        with pikepdf.open(BytesIO(raw)) as pdf:
            self.assertFalse(pdf.is_linearized)

        def _download(_key, dest):
            with open(dest, "wb") as fh:
                fh.write(raw)
            return len(raw)

        def _put(key, path, content_type="application/pdf"):
            with open(path, "rb") as fh:
                body = fh.read()
            self.assertTrue(body.startswith(PDF_MAGIC))
            with pikepdf.open(BytesIO(body)) as pdf:
                self.assertTrue(pdf.is_linearized)
            return hashlib.sha256(body).hexdigest()

        mock_download.side_effect = _download
        mock_put.side_effect = _put

        size, digest, linearized = linearize_pdf_object("books/x/content.pdf")
        self.assertGreater(size, 0)
        self.assertEqual(len(digest), 64)
        self.assertTrue(linearized)
        mock_put.assert_called_once()

    @patch("apps.catalog.pdf_books.put_file")
    @patch("apps.catalog.pdf_books.download_object_to_path")
    def test_skips_already_linearized(self, mock_download, mock_put):
        raw = _blank_pdf_bytes(linearize=True)

        def _download(_key, dest):
            with open(dest, "wb") as fh:
                fh.write(raw)
            return len(raw)

        mock_download.side_effect = _download

        size, digest, linearized = linearize_pdf_object("books/x/content.pdf")
        self.assertEqual(size, len(raw))
        self.assertEqual(len(digest), 64)
        self.assertTrue(linearized)
        mock_put.assert_not_called()

    @patch("apps.catalog.pdf_books.get_object_range")
    def test_pdf_object_looks_linearized(self, mock_range):
        mock_range.return_value = b"%PDF-1.7\n1 0 obj<</Linearized 1>>"
        self.assertTrue(pdf_object_looks_linearized("k"))
        mock_range.return_value = b"%PDF-1.7\n1 0 obj<</Type /Catalog>>"
        self.assertFalse(pdf_object_looks_linearized("k"))
