"""Shared helpers for splitting long content into byte-bounded reader pages.

Each reader page becomes a row in ``book_content_index`` whose normalized text is
btree-indexed, and PostgreSQL caps an index row at ~2704 bytes. Keep each page body
comfortably under that (in UTF-8 bytes), splitting long sections across several pages.

Used by both the Bible importer (``import_bible_book``) and the Word importer
(``docx_import``) so the pagination rule lives in exactly one place.
"""

from __future__ import annotations

# Max UTF-8 byte size for a single page body. Well under Postgres' ~2704-byte
# btree index-row limit, leaving headroom for the normalized/search copy.
PAGE_BYTE_BUDGET = 1600


def chunk_lines(lines: list[str], budget: int = PAGE_BYTE_BUDGET) -> list[list[str]]:
    """Group text lines into chunks whose joined UTF-8 size stays <= ``budget``.

    A single line longer than the budget is kept on its own chunk (never dropped);
    callers that must respect the hard index limit should pre-split such lines.
    """
    chunks: list[list[str]] = []
    cur: list[str] = []
    size = 0
    for line in lines:
        b = len(line.encode("utf-8")) + 1  # +1 for the joining newline
        if cur and size + b > budget:
            chunks.append(cur)
            cur, size = [], 0
        cur.append(line)
        size += b
    if cur:
        chunks.append(cur)
    return chunks


def number_repeated_titles(pages: list[dict]) -> None:
    """Disambiguate pages that share a title by appending ``(1)``, ``(2)`` … in place.

    Each page dict is expected to have a ``"title"`` key.
    """
    counts: dict[str, int] = {}
    for p in pages:
        counts[p["title"]] = counts.get(p["title"], 0) + 1
    seen: dict[str, int] = {}
    for p in pages:
        if counts[p["title"]] > 1:
            seen[p["title"]] = seen.get(p["title"], 0) + 1
            p["title"] = f"{p['title']} ({seen[p['title']]})"
