"""Shared book draft validation and publish/unpublish logic (admin UI + API)."""

from __future__ import annotations

import hashlib
import json
import logging
from typing import Any
from uuid import UUID

from django.conf import settings
from django.db import transaction
from django.db.models import Max, Prefetch
from django.shortcuts import get_object_or_404

from apps.catalog.models import Book, BookChapter, BookPage, BookRevision
from apps.catalog.search_index import rebuild_revision_index
from apps.catalog.storage_s3 import ensure_bucket, is_object_storage_configured, put_bytes

logger = logging.getLogger(__name__)


def plain_text_from_stored_summary(raw: str | None) -> str:
    if not raw:
        return ""
    text = raw.strip()
    if not text:
        return ""
    try:
        parsed = json.loads(text)
        if isinstance(parsed, list):
            chunks: list[str] = []
            for op in parsed:
                if isinstance(op, dict):
                    insert = op.get("insert")
                    if isinstance(insert, str):
                        chunks.append(insert)
            joined = "".join(chunks).replace("\uFFFC", "").strip()
            if joined:
                return joined
    except Exception:
        pass
    return text.replace("\uFFFC", "").strip()


def slugify_chapter_key(value: str, fallback_index: int) -> str:
    raw = (value or "").strip().lower()
    slug = []
    for ch in raw:
        if ch.isalnum():
            slug.append(ch)
        elif ch in (" ", "-", "_"):
            slug.append("-")
    joined = "".join(slug).strip("-")
    while "--" in joined:
        joined = joined.replace("--", "-")
    return joined or f"chapter-{fallback_index}"


def draft_manifest_and_html(book: Book) -> tuple[bytes, bytes]:
    raw = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    chunks: list[dict[str, str]] = []
    html_parts: list[str] = [f"<html><body><h1>{book.title}</h1>"]

    for chapter_index, chapter in enumerate(raw, start=1):
        if not isinstance(chapter, dict):
            continue
        chapter_title = str(chapter.get("title") or f"Chapter {chapter_index}").strip()
        chapter_key = slugify_chapter_key(str(chapter.get("chapter_key") or chapter_title), chapter_index)
        chunks.append({"id": chapter_key, "title": chapter_title, "path": "content.html"})
        html_parts.append(f'<section data-chapter="{chapter_key}">')
        html_parts.append(f"<h2>{chapter_title}</h2>")

        pages = chapter.get("pages")
        if isinstance(pages, list) and pages:
            for page_index, page in enumerate(pages, start=1):
                if not isinstance(page, dict):
                    continue
                page_number = int(page.get("page_number") or page_index)
                page_title = str(page.get("title") or f"Page {page_number}").strip()
                body = str(page.get("body") or "").strip()
                body_plain = plain_text_from_stored_summary(body) if body else ""
                html_parts.append(f'<article data-page="{page_number}">')
                html_parts.append(f"<h3>{page_title}</h3>")
                if body_plain:
                    html_parts.append(f"<p>{body_plain}</p>")
                html_parts.append("</article>")
        html_parts.append("</section>")

    if not chunks:
        text = plain_text_from_stored_summary(book.summary)
        if not text:
            text = f"{book.title}\n\nDraft content generated from book metadata."
        chunks = [{"id": "chapter-1", "title": "Draft", "path": "content.html"}]
        html_parts.append(f"<p>{text}</p>")

    html_parts.append("</body></html>")
    manifest_body = json.dumps(
        {
            "format": "html_chunks",
            "version": 1,
            "chunks": chunks,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    html_body = "".join(html_parts).encode("utf-8")
    return manifest_body, html_body


def validate_draft_warnings(chapters_draft: list[Any]) -> dict[str, Any]:
    warnings: list[str] = []
    chapter_count = 0
    page_count = 0
    empty_page_count = 0
    seen_chapter_keys: set[str] = set()

    for chapter_index, chapter in enumerate(chapters_draft, start=1):
        if not isinstance(chapter, dict):
            warnings.append(f"Chapter #{chapter_index} is malformed.")
            continue
        chapter_count += 1
        chapter_key = str(chapter.get("chapter_key") or "").strip()
        chapter_title = str(chapter.get("title") or "").strip()
        pages = chapter.get("pages")
        if not chapter_key:
            warnings.append(f"Chapter #{chapter_index} is missing chapter_key.")
        elif chapter_key in seen_chapter_keys:
            warnings.append(f"Duplicate chapter_key: {chapter_key}.")
        else:
            seen_chapter_keys.add(chapter_key)
        if not chapter_title:
            warnings.append(f"Chapter '{chapter_key or chapter_index}' has no title.")
        if not isinstance(pages, list) or not pages:
            warnings.append(f"Chapter '{chapter_key or chapter_index}' has no pages.")
            continue
        seen_page_numbers: set[int] = set()
        for page_idx, page in enumerate(pages, start=1):
            if not isinstance(page, dict):
                warnings.append(f"Chapter '{chapter_key or chapter_index}' page #{page_idx} is malformed.")
                continue
            page_count += 1
            try:
                page_number = int(page.get("page_number"))
            except Exception:
                warnings.append(f"Chapter '{chapter_key or chapter_index}' has a page with invalid page_number.")
                continue
            if page_number in seen_page_numbers:
                warnings.append(
                    f"Chapter '{chapter_key or chapter_index}' has duplicate page_number {page_number}."
                )
            seen_page_numbers.add(page_number)
            body = str(page.get("body") or "").strip()
            if not body:
                empty_page_count += 1
            elif len(body) > 18000:
                warnings.append(
                    f"Chapter '{chapter_key or chapter_index}' page {page_number} has very long content ({len(body)} chars)."
                )

    if chapter_count == 0:
        warnings.append("No chapters found.")
    if page_count == 0:
        warnings.append("No pages found.")

    return {
        "ok": len(warnings) == 0,
        "warnings": warnings,
        "stats": {
            "chapters": chapter_count,
            "pages": page_count,
            "empty_pages": empty_page_count,
        },
    }


def _unique_chapter_key(base_raw: str, index: int, used: set[str]) -> str:
    base = slugify_chapter_key(base_raw, index) or f"chapter-{index}"
    key = base
    n = 1
    while key in used:
        key = f"{base}-{n}"
        n += 1
    used.add(key)
    return key


def revision_chapters_draft_from_db(revision: BookRevision) -> list[dict[str, Any]]:
    """
    Build the ``chapters_draft`` JSON shape from ``BookChapter`` / ``BookPage`` rows.

    Pages with no ``chapter`` are grouped under a synthetic chapter at the end.
    """
    chapters = list(
        BookChapter.objects.filter(revision=revision)
        .order_by("ordinal", "chapter_key")
        .prefetch_related(Prefetch("pages", queryset=BookPage.objects.order_by("page_number")))
    )
    used_keys: set[str] = set()
    result: list[dict[str, Any]] = []

    for idx, ch in enumerate(chapters, start=1):
        raw_key = str(ch.chapter_key or "").strip()
        title = str(ch.title or raw_key or f"Chapter {idx}").strip()
        chapter_key = _unique_chapter_key(raw_key or title, idx, used_keys)
        pages_out: list[dict[str, Any]] = []
        for pg in ch.pages.all():
            pages_out.append(
                {
                    "page_number": int(pg.page_number),
                    "title": str(pg.page_title or f"Page {pg.page_number}").strip(),
                    "body": str(pg.text_plain or "").strip(),
                }
            )
        pages_out.sort(key=lambda p: p["page_number"])
        result.append({"chapter_key": chapter_key, "title": title or chapter_key, "pages": pages_out})

    orphans = list(
        BookPage.objects.filter(revision=revision, chapter__isnull=True).order_by("page_number")
    )
    if orphans:
        oidx = len(chapters) + 1
        chapter_key = _unique_chapter_key("misc-pages", oidx, used_keys)
        pages_out = [
            {
                "page_number": int(pg.page_number),
                "title": str(pg.page_title or f"Page {pg.page_number}").strip(),
                "body": str(pg.text_plain or "").strip(),
            }
            for pg in orphans
        ]
        result.append(
            {
                "chapter_key": chapter_key,
                "title": "Pages (no chapter)",
                "pages": pages_out,
            }
        )

    return result


def sync_book_chapters_draft_from_revision(book: Book, revision: BookRevision) -> bool:
    """
    If the revision has chapter or page rows, copy them onto ``book.chapters_draft`` and save.

    Returns True when JSON was updated from the database.
    """
    has_rows = BookChapter.objects.filter(revision=revision).exists() or BookPage.objects.filter(
        revision=revision
    ).exists()
    if not has_rows:
        return False
    book.chapters_draft = revision_chapters_draft_from_db(revision)
    book.save()
    return True


def should_refresh_html_blobs_after_db_sync(rev: BookRevision) -> bool:
    """Whether we can overwrite revision blobs from ``draft_manifest_and_html``."""
    if rev.content_format != "html_chunks":
        return False
    ck = (rev.content_object_key or "").lower()
    if ck.endswith(".enc"):
        return False
    if not is_object_storage_configured():
        return False
    return True


def refresh_revision_html_blobs(rev: BookRevision, book: Book) -> None:
    """Upload manifest + HTML derived from ``book.chapters_draft`` for this revision."""
    if not is_object_storage_configured():
        return
    if not settings.AWS_STORAGE_BUCKET_NAME or not settings.AWS_S3_ENDPOINT_URL:
        raise RuntimeError("Object storage is not configured (bucket / endpoint).")

    manifest_body, html_body = draft_manifest_and_html(book)
    ensure_bucket()
    prefix = f"admin/quick_draft/{book.id}/{rev.id}"
    if not rev.manifest_object_key:
        rev.manifest_object_key = f"{prefix}/manifest.json"
    if not rev.content_object_key:
        rev.content_object_key = f"{prefix}/content.html"

    manifest_sha = put_bytes(rev.manifest_object_key, manifest_body, "application/json")
    content_sha = put_bytes(rev.content_object_key, html_body, "text/html")
    rev.manifest_sha256 = manifest_sha
    rev.content_sha256 = content_sha
    rev.total_bytes = len(manifest_body) + len(html_body)
    rev.save(
        update_fields=[
            "manifest_object_key",
            "content_object_key",
            "manifest_sha256",
            "content_sha256",
            "total_bytes",
        ]
    )


def create_quick_draft_revision(book: Book, user) -> BookRevision:
    """Create a draft revision from ``book.chapters_draft``; upload to storage when configured."""
    manifest_body, html_body = draft_manifest_and_html(book)
    manifest_sha = hashlib.sha256(manifest_body).hexdigest()
    content_sha = hashlib.sha256(html_body).hexdigest()
    total_bytes = len(manifest_body) + len(html_body)

    with transaction.atomic():
        last = book.revisions.aggregate(m=Max("revision_number"))["m"] or 0
        rev = BookRevision.objects.create(
            book=book,
            revision_number=last + 1,
            status=BookRevision.Status.DRAFT,
            content_format="html_chunks",
            created_by=user,
        )
        if is_object_storage_configured():
            prefix = f"admin/quick_draft/{book.id}/{rev.id}"
            manifest_key = f"{prefix}/manifest.json"
            content_key = f"{prefix}/content.html"
            ensure_bucket()
            manifest_sha = put_bytes(manifest_key, manifest_body, "application/json")
            content_sha = put_bytes(content_key, html_body, "text/html")
            rev.manifest_object_key = manifest_key
            rev.content_object_key = content_key
        else:
            rev.manifest_object_key = ""
            rev.content_object_key = ""
        rev.manifest_sha256 = manifest_sha
        rev.content_sha256 = content_sha
        rev.total_bytes = total_bytes
        rev.save(
            update_fields=[
                "manifest_object_key",
                "content_object_key",
                "manifest_sha256",
                "content_sha256",
                "total_bytes",
            ]
        )
        return rev


class PublishBookOutcome:
    __slots__ = ("ok", "book", "error", "status_code")

    def __init__(
        self,
        *,
        ok: bool,
        book: Book | None = None,
        error: dict[str, Any] | None = None,
        status_code: int = 200,
    ):
        self.ok = ok
        self.book = book
        self.error = error
        self.status_code = status_code


def _revision_blocks_publish_without_blob_refresh(rev: BookRevision) -> bool:
    return (rev.content_object_key or "").lower().endswith(".enc")


def publish_book(book: Book, user, revision_id: UUID | None = None) -> PublishBookOutcome:
    """Validate draft, resolve revision, publish book, rebuild chapter/page index."""
    rev: BookRevision | None = None
    synced_from_db = False

    if revision_id is not None:
        rev = get_object_or_404(BookRevision, pk=revision_id, book=book)
    else:
        rev = (
            BookRevision.objects.filter(book=book, status=BookRevision.Status.DRAFT)
            .order_by("-revision_number")
            .first()
        )

    if rev is not None and sync_book_chapters_draft_from_revision(book, rev):
        synced_from_db = True

    chapters_list = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    draft_validation = validate_draft_warnings(chapters_list)
    stats = draft_validation.get("stats") or {}
    if int(stats.get("chapters", 0)) == 0 or int(stats.get("pages", 0)) == 0:
        return PublishBookOutcome(
            ok=False,
            error={
                "error": {
                    "code": "INVALID_DRAFT",
                    "message": "Cannot publish a draft without chapters and pages.",
                },
                "validation": draft_validation,
            },
            status_code=400,
        )

    if rev is None:
        try:
            rev = create_quick_draft_revision(book, user)
        except Exception as exc:
            logger.exception("quick draft generation failed: %s", exc)
            return PublishBookOutcome(
                ok=False,
                error={
                    "error": {
                        "code": "NO_DRAFT_REVISION",
                        "message": "No draft revision available to publish, and auto-draft generation failed.",
                    }
                },
                status_code=400,
            )

    if synced_from_db:
        if should_refresh_html_blobs_after_db_sync(rev):
            try:
                refresh_revision_html_blobs(rev, book)
            except Exception as exc:
                logger.exception("refresh revision blobs failed: %s", exc)
                return PublishBookOutcome(
                    ok=False,
                    error={
                        "error": {
                            "code": "STORAGE_REFRESH_FAILED",
                            "message": f"Could not update revision files in storage: {exc}",
                        }
                    },
                    status_code=500,
                )
        elif _revision_blocks_publish_without_blob_refresh(rev):
            return PublishBookOutcome(
                ok=False,
                error={
                    "error": {
                        "code": "CANNOT_REFRESH_REVISION_BLOBS",
                        "message": (
                            "This revision does not use replaceable html_chunks storage "
                            "(e.g. encrypted package). Create a new draft revision or edit JSON draft only."
                        ),
                    }
                },
                status_code=400,
            )

    # Manifest/object keys may be empty when object storage is disabled; index is built from ``chapters_draft``.
    # Rebuild before flipping published so we never expose a published revision with an empty index.
    try:
        rebuild_revision_index(rev)
    except Exception as exc:
        logger.exception("revision index rebuild failed for %s", rev.id)
        return PublishBookOutcome(
            ok=False,
            error={
                "error": {
                    "code": "INDEX_REBUILD_FAILED",
                    "message": f"Could not build reader content index: {exc}",
                }
            },
            status_code=500,
        )

    with transaction.atomic():
        BookRevision.objects.filter(book=book, status=BookRevision.Status.PUBLISHED).update(
            status=BookRevision.Status.SUPERSEDED
        )
        rev.status = BookRevision.Status.PUBLISHED
        rev.save(update_fields=["status"])
        book.published_revision = rev
        book.catalog_visibility = Book.Visibility.PUBLISHED
        book.save()

    return PublishBookOutcome(ok=True, book=book)


def unpublish_book(book: Book) -> None:
    book.catalog_visibility = Book.Visibility.HIDDEN
    book.published_revision = None
    book.save()
