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
    download_object_to_path,
    get_object_range,
    head_object,
    is_object_storage_configured,
    put_bytes,
    put_file,
)

logger = logging.getLogger(__name__)

CONTENT_FORMAT_PDF = "pdf"
MAX_PDF_BYTES = 100 * 1024 * 1024  # 100 MB
MAX_PREVIEW_PAGES = 10
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
    pages = _coerce_preview_page_list(rev.preview_page_numbers)
    return {
        "revision_id": str(rev.id),
        "revision_number": rev.revision_number,
        "status": rev.status,
        "filename": filename or "content.pdf",
        "size_bytes": size_bytes,
        "page_count": page_count,
        # Keys alone are not enough — create_pdf_draft_revision sets them before
        # upload. Require validated bytes so the editor does not fake a ready PDF.
        "ready": bool(
            rev.content_object_key and rev.manifest_object_key and size_bytes > 0
        ),
        "content_object_key": rev.content_object_key or "",
        "preview_page_numbers": pages,
        "has_preview": bool(rev.preview_object_key and pages),
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

    keys = [
        k
        for k in (
            rev.content_object_key,
            rev.manifest_object_key,
            rev.preview_object_key,
        )
        if k
    ]
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


def pdf_object_looks_linearized(object_key: str) -> bool:
    """Cheap Fast Web View hint: linearized PDFs declare ``/Linearized`` near the head."""
    try:
        head = get_object_range(object_key, 0, 2047)
    except Exception:
        return False
    return b"/Linearized" in head


def _sha256_file(path: str) -> str:
    import hashlib

    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def linearize_pdf_object(
    object_key: str, *, force: bool = False
) -> tuple[int, str, bool]:
    """Rewrite [object_key] as a linearized (Fast Web View) PDF.

    Returns ``(size_bytes, sha256_hex, is_linearized)``. Uses temp files so a
    100 MB PDF does not peak at ~2× in RAM. On pikepdf failure, leaves the
    original object untouched and returns its size/hash with ``is_linearized``
    reflecting the original file.
    """
    import os
    import tempfile

    import pikepdf

    with tempfile.TemporaryDirectory(prefix="fm-pdf-lin-") as tmp:
        src = os.path.join(tmp, "in.pdf")
        dst = os.path.join(tmp, "out.pdf")
        try:
            size = download_object_to_path(object_key, src)
        except Exception as exc:
            raise PdfBookError(
                "OBJECTS_MISSING",
                "PDF upload not found or incomplete.",
            ) from exc

        if size <= 0:
            raise PdfBookError("EMPTY_PDF", "PDF file is empty.")
        if size > MAX_PDF_BYTES:
            raise PdfBookError(
                "PDF_TOO_LARGE",
                f"PDF exceeds the {MAX_PDF_BYTES // (1024 * 1024)}MB limit.",
            )

        with open(src, "rb") as fh:
            magic = fh.read(8)
        if not magic.startswith(PDF_MAGIC):
            raise PdfBookError("INVALID_PDF", "File content is not a valid PDF.")

        already_linearized = False
        try:
            with pikepdf.open(src) as pdf:
                already_linearized = bool(pdf.is_linearized)
                if already_linearized and not force:
                    return size, _sha256_file(src), True
                pdf.save(dst, linearize=True)
        except PdfBookError:
            raise
        except Exception:
            logger.warning(
                "PDF linearization failed for %s; keeping original bytes",
                object_key,
                exc_info=True,
            )
            return size, _sha256_file(src), already_linearized

        out_size = os.path.getsize(dst)
        with open(dst, "rb") as fh:
            out_magic = fh.read(8)
        if not out_magic.startswith(PDF_MAGIC):
            logger.warning(
                "Linearized output for %s failed magic check; keeping original",
                object_key,
            )
            return size, _sha256_file(src), False
        if out_size > MAX_PDF_BYTES:
            logger.warning(
                "Linearized PDF for %s exceeds size limit; keeping original",
                object_key,
            )
            return size, _sha256_file(src), False

        digest = put_file(object_key, dst, content_type="application/pdf")
        return out_size, digest, True


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

    validate_uploaded_pdf(rev.content_object_key)
    size, digest, linearized = linearize_pdf_object(rev.content_object_key)
    page_count = count_pdf_pages(rev.content_object_key)
    safe_name = (filename or "content.pdf").strip() or "content.pdf"
    if not safe_name.lower().endswith(".pdf"):
        safe_name = f"{safe_name}.pdf"

    # Ignore client sha after rewrite — it would describe the pre-linearized blob.
    if content_sha256 and content_sha256.strip().lower() != digest.lower():
        logger.info(
            "Ignoring client content_sha256 for %s after linearization rewrite",
            rev.id,
        )

    manifest = {
        "format": CONTENT_FORMAT_PDF,
        "version": 1,
        "filename": safe_name,
        "size_bytes": size,
        "linearized": linearized,
        "page_count": page_count,
    }
    if not rev.manifest_object_key:
        rev.manifest_object_key = f"books/{rev.book_id}/{rev.id}/manifest.json"

    put_bytes(
        rev.manifest_object_key,
        json.dumps(manifest, ensure_ascii=False).encode("utf-8"),
        content_type="application/json",
    )

    rev.total_bytes = size
    rev.content_sha256 = digest
    rev.save(
        update_fields=[
            "manifest_object_key",
            "total_bytes",
            "content_sha256",
        ]
    )
    # Rebuild Look Inside sample when page list was already chosen.
    if _coerce_preview_page_list(rev.preview_page_numbers):
        try:
            build_pdf_preview(rev)
        except PdfBookError as exc:
            logger.warning(
                "PDF preview rebuild skipped for %s: %s %s",
                rev.id,
                exc.code,
                exc.message,
            )
        except Exception:
            logger.warning(
                "PDF preview rebuild failed for %s", rev.id, exc_info=True
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
    # Ensure Fast Web View layout before readers can open the book.
    size, digest, linearized = linearize_pdf_object(rev.content_object_key)
    update_fields: list[str] = []
    if rev.total_bytes != size:
        rev.total_bytes = size
        update_fields.append("total_bytes")
    if rev.content_sha256 != digest:
        rev.content_sha256 = digest
        update_fields.append("content_sha256")
    if update_fields:
        rev.save(update_fields=update_fields)

    # Keep manifest size / linearized flag in sync for admin + clients.
    try:
        from apps.catalog.storage_s3 import get_object_bytes

        filename = "content.pdf"
        try:
            raw = get_object_bytes(rev.manifest_object_key)
            data = json.loads(raw.decode("utf-8"))
            if isinstance(data, dict) and data.get("filename"):
                filename = str(data["filename"])
        except Exception:
            pass
        page_count = count_pdf_pages(rev.content_object_key)
        put_bytes(
            rev.manifest_object_key,
            json.dumps(
                {
                    "format": CONTENT_FORMAT_PDF,
                    "version": 1,
                    "filename": filename,
                    "size_bytes": size,
                    "linearized": linearized,
                    "page_count": page_count,
                },
                ensure_ascii=False,
            ).encode("utf-8"),
            content_type="application/json",
        )
    except Exception:
        logger.warning(
            "Could not refresh PDF manifest for %s after linearize",
            rev.id,
            exc_info=True,
        )

    with transaction.atomic():
        BookRevision.objects.filter(
            book=book, status=BookRevision.Status.PUBLISHED
        ).update(status=BookRevision.Status.SUPERSEDED)
        rev.status = BookRevision.Status.PUBLISHED
        rev.save(update_fields=["status"])
        book.published_revision = rev
        book.catalog_visibility = Book.Visibility.PUBLISHED
        book.save()

    # Sample PDF for Look Inside (no-op when page list is empty).
    try:
        build_pdf_preview(rev)
    except PdfBookError as exc:
        logger.warning(
            "PDF preview build skipped for %s: %s %s",
            rev.id,
            exc.code,
            exc.message,
        )
    except Exception:
        logger.warning("PDF preview build failed for %s", rev.id, exc_info=True)


def _coerce_preview_page_list(raw: Any) -> list[int]:
    """Best-effort list of ints from JSON storage (no validation)."""
    if not isinstance(raw, list):
        return []
    out: list[int] = []
    for item in raw:
        try:
            n = int(item)
        except (TypeError, ValueError):
            continue
        if n > 0:
            out.append(n)
    return out


def normalize_preview_page_numbers(
    raw: Any, *, page_count: int
) -> list[int]:
    """Validate and normalize an admin-supplied page list.

    Returns a sorted unique list of 1-based page numbers. Empty input → [].
    Raises PdfBookError on invalid values.
    """
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise PdfBookError(
            "INVALID_PREVIEW_PAGES",
            "preview_page_numbers must be a list of page numbers.",
        )
    if len(raw) > MAX_PREVIEW_PAGES:
        raise PdfBookError(
            "PREVIEW_TOO_MANY_PAGES",
            f"Preview may include at most {MAX_PREVIEW_PAGES} pages.",
        )
    if page_count <= 0:
        raise PdfBookError(
            "PDF_PAGE_COUNT_UNKNOWN",
            "Upload and complete the PDF before setting preview pages.",
        )

    seen: set[int] = set()
    pages: list[int] = []
    for item in raw:
        try:
            n = int(item)
        except (TypeError, ValueError) as exc:
            raise PdfBookError(
                "INVALID_PREVIEW_PAGES",
                "Each preview page must be a positive integer.",
            ) from exc
        if n <= 0:
            raise PdfBookError(
                "INVALID_PREVIEW_PAGES",
                "Page numbers must be 1-based positive integers.",
            )
        if n > page_count:
            raise PdfBookError(
                "PREVIEW_PAGE_OUT_OF_RANGE",
                f"Page {n} is outside this PDF ({page_count} pages).",
            )
        if n not in seen:
            seen.add(n)
            pages.append(n)
    pages.sort()
    if len(pages) > MAX_PREVIEW_PAGES:
        raise PdfBookError(
            "PREVIEW_TOO_MANY_PAGES",
            f"Preview may include at most {MAX_PREVIEW_PAGES} pages.",
        )
    return pages


def count_pdf_pages(object_key: str) -> int:
    """Return page count for a stored PDF object (0 on failure)."""
    import os
    import tempfile

    import pikepdf

    if not object_key or not is_object_storage_configured():
        return 0
    with tempfile.TemporaryDirectory(prefix="fm-pdf-pages-") as tmp:
        src = os.path.join(tmp, "in.pdf")
        try:
            download_object_to_path(object_key, src)
            with pikepdf.open(src) as pdf:
                return len(pdf.pages)
        except Exception:
            logger.debug("could not count pages for %s", object_key, exc_info=True)
            return 0


def revision_pdf_page_count(rev: BookRevision) -> int:
    """Page count from manifest when present, else by reading the object."""
    if rev.manifest_object_key and is_object_storage_configured():
        try:
            raw = get_object_range(rev.manifest_object_key, 0, 64 * 1024)
            data = json.loads(raw.decode("utf-8"))
            if isinstance(data, dict):
                pc = data.get("page_count")
                if isinstance(pc, int) and pc > 0:
                    return pc
        except Exception:
            pass
    if rev.content_object_key:
        return count_pdf_pages(rev.content_object_key)
    return 0


def clear_pdf_preview(rev: BookRevision) -> None:
    """Remove sample preview object and clear preview fields."""
    from apps.catalog.storage_s3 import delete_objects

    key = (rev.preview_object_key or "").strip()
    if key:
        delete_objects([key])
    rev.preview_page_numbers = []
    rev.preview_object_key = ""
    rev.preview_sha256 = ""
    rev.save(
        update_fields=["preview_page_numbers", "preview_object_key", "preview_sha256"]
    )


def build_pdf_preview(rev: BookRevision) -> BookRevision:
    """Extract listed pages into ``preview_object_key``.

    Empty page list clears any existing sample. No-op-safe when storage is down
    only after validation — raises PdfBookError for missing content.
    """
    import hashlib
    import os
    import tempfile

    import pikepdf

    pages = _coerce_preview_page_list(rev.preview_page_numbers)
    if not pages:
        if rev.preview_object_key or rev.preview_sha256:
            clear_pdf_preview(rev)
        else:
            rev.preview_page_numbers = []
            rev.save(update_fields=["preview_page_numbers"])
        return rev

    if not is_pdf_revision(rev) or not rev.content_object_key:
        raise PdfBookError(
            "PACKAGE_INCOMPLETE",
            "PDF content is required before building a preview.",
        )
    if not is_object_storage_configured():
        raise PdfBookError(
            "STORAGE_UNAVAILABLE",
            "Object storage is not configured for PDF previews.",
            status_code=503,
        )

    page_count = revision_pdf_page_count(rev)
    pages = normalize_preview_page_numbers(pages, page_count=page_count)

    preview_key = f"books/{rev.book_id}/{rev.id}/preview.pdf"
    with tempfile.TemporaryDirectory(prefix="fm-pdf-preview-") as tmp:
        src = os.path.join(tmp, "in.pdf")
        dst = os.path.join(tmp, "out.pdf")
        try:
            download_object_to_path(rev.content_object_key, src)
        except Exception as exc:
            raise PdfBookError(
                "OBJECTS_MISSING",
                "PDF upload not found or incomplete.",
            ) from exc

        try:
            with pikepdf.open(src) as pdf:
                total = len(pdf.pages)
                # Re-validate against live page count (manifest may be stale).
                pages = normalize_preview_page_numbers(pages, page_count=total)
                out = pikepdf.Pdf.new()
                for n in pages:
                    out.pages.append(pdf.pages[n - 1])
                out.save(dst, linearize=True)
        except PdfBookError:
            raise
        except Exception as exc:
            raise PdfBookError(
                "PREVIEW_BUILD_FAILED",
                "Could not build the preview PDF.",
                status_code=500,
            ) from exc

        digest = put_file(preview_key, dst, content_type="application/pdf")
        # Prefer hashing the written file when put_file returns empty.
        if not digest:
            h = hashlib.sha256()
            with open(dst, "rb") as fh:
                while True:
                    chunk = fh.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            digest = h.hexdigest()

    old_key = (rev.preview_object_key or "").strip()
    rev.preview_page_numbers = pages
    rev.preview_object_key = preview_key
    rev.preview_sha256 = digest or ""
    rev.save(
        update_fields=["preview_page_numbers", "preview_object_key", "preview_sha256"]
    )
    if old_key and old_key != preview_key:
        from apps.catalog.storage_s3 import delete_objects

        delete_objects([old_key])
    return rev


def set_preview_page_numbers(rev: BookRevision, raw: Any) -> BookRevision:
    """Validate, persist page list, and rebuild (or clear) the sample PDF."""
    if not is_pdf_revision(rev):
        raise PdfBookError("NOT_PDF_REVISION", "Revision is not a PDF package.")
    page_count = revision_pdf_page_count(rev)
    if raw is None or (isinstance(raw, list) and len(raw) == 0):
        clear_pdf_preview(rev)
        return rev
    pages = normalize_preview_page_numbers(raw, page_count=page_count)
    rev.preview_page_numbers = pages
    rev.save(update_fields=["preview_page_numbers"])
    if not pages:
        clear_pdf_preview(rev)
        return rev
    if not rev.content_object_key or not (rev.total_bytes or 0):
        # List saved; sample built once the package is complete / published.
        return rev
    return build_pdf_preview(rev)
