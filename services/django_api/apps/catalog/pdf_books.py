"""PDF book package helpers: upload validation, manifest, publish gate.

PDF books are first-class revisions with ``content_format="pdf"``. They do not
use ``chapters_draft`` / HTML chunk packages. Text and Bible publish paths are
unchanged.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from django.db import transaction
from django.db.models import Max

from apps.catalog.models import Book, BookRevision
from apps.catalog.storage_s3 import (
    get_object_range,
    head_object,
    is_object_storage_configured,
    put_bytes,
)

logger = logging.getLogger(__name__)

CONTENT_FORMAT_PDF = "pdf"
MAX_PDF_BYTES = 100 * 1024 * 1024  # 100 MB
PDF_MAGIC = b"%PDF-"


class PdfBookError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def is_pdf_revision(rev: BookRevision | None) -> bool:
    return rev is not None and (rev.content_format or "") == CONTENT_FORMAT_PDF


def latest_pdf_draft(book: Book) -> BookRevision | None:
    return (
        BookRevision.objects.filter(
            book=book,
            status=BookRevision.Status.DRAFT,
            content_format=CONTENT_FORMAT_PDF,
        )
        .order_by("-revision_number")
        .first()
    )


def latest_pdf_for_admin(book: Book) -> BookRevision | None:
    """PDF revision the admin editor should show / replace / clear.

    Prefer an explicit draft, then the linked published revision, then any
    orphaned PDF revision left behind by older unpublish (published_revision
    cleared while the revision row stayed ``published``).
    """
    rev = latest_pdf_draft(book)
    if rev is not None:
        return rev
    pub = book.published_revision
    if is_pdf_revision(pub):
        return pub
    orphan = (
        BookRevision.objects.filter(
            book=book,
            content_format=CONTENT_FORMAT_PDF,
        )
        .exclude(content_object_key__isnull=True)
        .exclude(content_object_key="")
        .order_by("-revision_number")
        .first()
    )
    # Heal older unpublish that cleared published_revision but left the PDF
    # revision stuck as ``published`` — reopen it as a draft for editing.
    if (
        orphan is not None
        and orphan.status == BookRevision.Status.PUBLISHED
        and book.published_revision_id != orphan.id
    ):
        orphan.status = BookRevision.Status.DRAFT
        orphan.save(update_fields=["status"])
    return orphan


def pdf_draft_summary(book: Book) -> dict[str, Any] | None:
    """Admin UI payload describing the current PDF draft (or published PDF)."""
    rev = latest_pdf_for_admin(book)
    if rev is None:
        return None

    filename = ""
    page_count = None
    if rev.manifest_object_key and is_object_storage_configured():
        try:
            raw = get_object_range(rev.manifest_object_key, 0, 64 * 1024)
            data = json.loads(raw.decode("utf-8"))
            if isinstance(data, dict):
                filename = str(data.get("filename") or "")
                pc = data.get("page_count")
                if isinstance(pc, int):
                    page_count = pc
        except Exception:
            logger.debug("could not read pdf manifest for %s", rev.id, exc_info=True)

    size_bytes = int(rev.total_bytes or 0)
    return {
        "revision_id": str(rev.id),
        "revision_number": rev.revision_number,
        "status": rev.status,
        "filename": filename or "content.pdf",
        "size_bytes": size_bytes,
        # Keys alone are not enough — create_pdf_draft_revision sets them before
        # upload. Require validated bytes so the editor does not fake a ready PDF.
        "ready": bool(
            rev.content_object_key and rev.manifest_object_key and size_bytes > 0
        ),
        "content_object_key": rev.content_object_key or "",
    }


def clear_pdf_package(book: Book) -> bool:
    """Remove the editable PDF package for [book]. Returns True if one existed.

    Used when an author deletes the PDF from the edit screen so they can upload
    a different file. Refuses when the book is still catalog-published.
    """
    if book.catalog_visibility == Book.Visibility.PUBLISHED:
        raise PdfBookError(
            "BOOK_PUBLISHED",
            "Unpublish this book before editing.",
            status_code=409,
        )
    rev = latest_pdf_for_admin(book)
    if rev is None:
        return False
    if rev.status == BookRevision.Status.PUBLISHED and book.published_revision_id == rev.id:
        raise PdfBookError(
            "BOOK_PUBLISHED",
            "Unpublish this book before editing.",
            status_code=409,
        )

    from apps.catalog.storage_s3 import delete_objects

    keys = [k for k in (rev.content_object_key, rev.manifest_object_key) if k]
    delete_objects(keys)
    with transaction.atomic():
        if book.published_revision_id == rev.id:
            book.published_revision = None
            book.save(update_fields=["published_revision"])
        rev.delete()
    return True


def create_pdf_draft_revision(
    book: Book,
    user,
    *,
    filename: str = "content.pdf",
) -> tuple[BookRevision, str, str]:
    """Create a draft PDF revision and return (rev, object_key, put content-type)."""
    if not is_object_storage_configured():
        raise PdfBookError(
            "STORAGE_UNAVAILABLE",
            "Object storage is not configured for PDF uploads.",
            status_code=503,
        )
    safe_name = (filename or "content.pdf").strip() or "content.pdf"
    if not safe_name.lower().endswith(".pdf"):
        safe_name = f"{safe_name}.pdf"
    # Keep object key stable; display name lives in the manifest.
    with transaction.atomic():
        last = book.revisions.aggregate(m=Max("revision_number"))["m"] or 0
        rev = BookRevision.objects.create(
            book=book,
            revision_number=last + 1,
            status=BookRevision.Status.DRAFT,
            content_format=CONTENT_FORMAT_PDF,
            created_by=user,
        )
        prefix = f"books/{book.id}/{rev.id}"
        content_key = f"{prefix}/content.pdf"
        manifest_key = f"{prefix}/manifest.json"
        rev.content_object_key = content_key
        rev.manifest_object_key = manifest_key
        rev.save(update_fields=["content_object_key", "manifest_object_key"])
    return rev, content_key, "application/pdf"


def validate_uploaded_pdf(object_key: str) -> int:
    """HEAD + magic-byte check. Returns size in bytes."""
    try:
        meta = head_object(object_key)
    except Exception as exc:
        raise PdfBookError(
            "OBJECTS_MISSING",
            "PDF upload not found or incomplete.",
        ) from exc

    size = int(meta.get("ContentLength") or 0)
    if size <= 0:
        raise PdfBookError("EMPTY_PDF", "PDF file is empty.")
    if size > MAX_PDF_BYTES:
        raise PdfBookError(
            "PDF_TOO_LARGE",
            f"PDF exceeds the {MAX_PDF_BYTES // (1024 * 1024)}MB limit.",
        )

    try:
        head = get_object_range(object_key, 0, 7)
    except Exception as exc:
        raise PdfBookError(
            "OBJECTS_MISSING",
            "Could not read uploaded PDF.",
        ) from exc
    if not head.startswith(PDF_MAGIC):
        raise PdfBookError(
            "INVALID_PDF",
            "File content is not a valid PDF.",
        )
    return size


def complete_pdf_upload(
    rev: BookRevision,
    *,
    filename: str = "content.pdf",
    content_sha256: str = "",
) -> BookRevision:
    if not is_pdf_revision(rev):
        raise PdfBookError("NOT_PDF_REVISION", "Revision is not a PDF package.")
    if not rev.content_object_key:
        raise PdfBookError("PACKAGE_INCOMPLETE", "PDF revision has no content key.")

    size = validate_uploaded_pdf(rev.content_object_key)
    safe_name = (filename or "content.pdf").strip() or "content.pdf"
    if not safe_name.lower().endswith(".pdf"):
        safe_name = f"{safe_name}.pdf"

    manifest = {
        "format": CONTENT_FORMAT_PDF,
        "version": 1,
        "filename": safe_name,
        "size_bytes": size,
    }
    if not rev.manifest_object_key:
        rev.manifest_object_key = f"books/{rev.book_id}/{rev.id}/manifest.json"

    put_bytes(
        rev.manifest_object_key,
        json.dumps(manifest, ensure_ascii=False).encode("utf-8"),
        content_type="application/json",
    )

    rev.total_bytes = size
    if content_sha256:
        rev.content_sha256 = content_sha256.strip()
    rev.save(
        update_fields=[
            "manifest_object_key",
            "total_bytes",
            "content_sha256",
        ]
    )
    return rev


def publish_pdf_revision(book: Book, rev: BookRevision) -> None:
    """Mark a validated PDF revision as the published package."""
    if not is_pdf_revision(rev):
        raise PdfBookError("NOT_PDF_REVISION", "Revision is not a PDF package.")
    if not rev.content_object_key or not rev.manifest_object_key:
        raise PdfBookError(
            "PACKAGE_INCOMPLETE",
            "Upload a PDF and complete the package before publishing.",
        )
    # Re-validate blob still present.
    validate_uploaded_pdf(rev.content_object_key)

    with transaction.atomic():
        BookRevision.objects.filter(
            book=book, status=BookRevision.Status.PUBLISHED
        ).update(status=BookRevision.Status.SUPERSEDED)
        rev.status = BookRevision.Status.PUBLISHED
        rev.save(update_fields=["status"])
        book.published_revision = rev
        book.catalog_visibility = Book.Visibility.PUBLISHED
        book.save()
