from __future__ import annotations

import json
import logging
import re

from apps.catalog.models import Book, BookChapter, BookContentIndex, BookPage, BookRevision
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.storage_s3 import get_object_bytes

logger = logging.getLogger(__name__)

_HTML_TAG_RE = re.compile(r"<[^>]+>")
_SPACE_RE = re.compile(r"\s+")


def _html_to_text(value: str) -> str:
    stripped = _HTML_TAG_RE.sub(" ", value)
    return _SPACE_RE.sub(" ", stripped).strip()


def _chunk_text_pages(text: str, page_size: int = 1400) -> list[str]:
    cleaned = text.strip()
    if not cleaned:
        return []
    pages: list[str] = []
    start = 0
    while start < len(cleaned):
        end = min(len(cleaned), start + page_size)
        pages.append(cleaned[start:end].strip())
        start = end
    return [p for p in pages if p]


def _parse_manifest(revision: BookRevision) -> list[dict]:
    if not revision.manifest_object_key:
        return []
    raw = get_object_bytes(revision.manifest_object_key)
    if not raw:
        return []
    payload = json.loads(raw.decode("utf-8"))
    chunks = payload.get("chunks")
    if isinstance(chunks, list):
        return [c for c in chunks if isinstance(c, dict)]
    return []


def _draft_has_indexable_pages(book: Book) -> bool:
    """True when ``chapters_draft`` lists at least one chapter with one page dict."""
    draft = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    chapter_count = 0
    page_count = 0
    for chapter in draft:
        if not isinstance(chapter, dict):
            continue
        chapter_count += 1
        pages = chapter.get("pages")
        if not isinstance(pages, list):
            continue
        for page in pages:
            if isinstance(page, dict):
                page_count += 1
    return chapter_count > 0 and page_count > 0


def ensure_revision_index_from_book_draft(book: Book, revision: BookRevision) -> None:
    """
    If ``revision`` has no indexed pages but ``book.chapters_draft`` does, rebuild the index.

    Repairs reader ``/content`` after a failed publish rebuild or historical drift.
    """
    if BookPage.objects.filter(revision=revision).exists():
        return
    if not _draft_has_indexable_pages(book):
        return
    logger.info(
        "Rebuilding revision %s index from book %s chapters_draft (lazy content repair)",
        revision.id,
        book.id,
    )
    rebuild_revision_index(revision)


def rebuild_revision_index(revision: BookRevision) -> None:
    BookChapter.objects.filter(revision=revision).delete()
    BookPage.objects.filter(revision=revision).delete()
    BookContentIndex.objects.filter(revision=revision).delete()

    # Fresh row so we never read a stale cached ``revision.book`` after sync_book_chapters_draft_from_revision.
    book = Book.objects.get(pk=revision.book_id)

    # Prefer book JSON draft so publishing works without object storage (manifest may be unset).
    draft = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    if draft:
        page_number = 1
        for ordinal, chapter_draft in enumerate(draft):
            if not isinstance(chapter_draft, dict):
                continue
            chapter_key = str(chapter_draft.get("chapter_key") or f"chapter-{ordinal+1}")
            chapter_title = str(chapter_draft.get("title") or chapter_key)
            chapter = BookChapter.objects.create(
                revision=revision,
                chapter_key=chapter_key,
                title=chapter_title,
                ordinal=ordinal + 1,
                start_chunk=chapter_key,
                end_chunk=chapter_key,
            )
            pages = chapter_draft.get("pages")
            if not isinstance(pages, list) or not pages:
                pages = [{"page_number": 1, "title": "Page 1", "body": chapter_title}]
            for page in pages:
                if not isinstance(page, dict):
                    continue
                page_title = str(page.get("title") or f"Page {page_number}")
                page_text = str(page.get("body") or "").strip() or page_title
                page_num = int(page.get("page_number") or page_number)
                BookPage.objects.create(
                    revision=revision,
                    chapter=chapter,
                    page_number=page_num,
                    page_title=page_title,
                    chunk_key=chapter_key,
                    text_plain=page_text,
                )
                BookContentIndex.objects.create(
                    book=book,
                    revision=revision,
                    chunk_key=chapter_key,
                    chapter_key=chapter_key,
                    page_number=page_num,
                    text_plain=page_text,
                    text_normalized=normalize_search_text(page_text),
                )
                page_number = max(page_number + 1, page_num + 1)
        return

    chunks = _parse_manifest(revision)
    if not chunks:
        return

    page_number = 1

    # Most revisions in this project currently store one content object.
    content_html = ""
    if revision.content_object_key:
        content_html = get_object_bytes(revision.content_object_key).decode("utf-8", errors="ignore")
    plain = _html_to_text(content_html)
    fallback_pages = _chunk_text_pages(plain)

    for ordinal, chunk in enumerate(chunks):
        chapter_key = str(chunk.get("id") or f"chapter-{ordinal+1}")
        chapter_title = str(chunk.get("title") or chapter_key)
        chapter = BookChapter.objects.create(
            revision=revision,
            chapter_key=chapter_key,
            title=chapter_title,
            ordinal=ordinal + 1,
            start_chunk=chapter_key,
            end_chunk=chapter_key,
        )
        source_text = fallback_pages[ordinal] if ordinal < len(fallback_pages) else plain
        page_chunks = _chunk_text_pages(source_text, page_size=1200) or [source_text or chapter_title]
        for local_page_index, page_text in enumerate(page_chunks, start=1):
            page_title = f"Page {local_page_index}"
            BookPage.objects.create(
                revision=revision,
                chapter=chapter,
                page_number=page_number,
                page_title=page_title,
                chunk_key=chapter_key,
                text_plain=page_text,
            )
            BookContentIndex.objects.create(
                book=book,
                revision=revision,
                chunk_key=chapter_key,
                chapter_key=chapter_key,
                page_number=page_number,
                text_plain=page_text,
                text_normalized=normalize_search_text(page_text),
            )
            page_number += 1
