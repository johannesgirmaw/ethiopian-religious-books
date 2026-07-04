"""Parse a Word ``.docx`` into the platform's ``chapters_draft`` shape.

The document is parsed **once** into a list of :class:`Block` objects (one per
paragraph, annotated with everything the detectors need), then a chosen
*detection strategy* segments those blocks into chapters. Every strategy feeds
the same page builder, which splits long chapters into byte-bounded pages via
:mod:`apps.catalog.pagination` (each page becomes a btree-indexed
``book_content_index`` row that Postgres caps at ~2704 bytes).

Detection strategies (``mode``):

* ``heading``   -- Word ``Heading 1``/``Title`` -> chapter, ``Heading 2`` -> page.
* ``patterns``  -- lines matching "Chapter N" / "ምዕራፍ N" / a number / custom regex.
* ``format``    -- short bold / centered / ALL-CAPS / larger-font lines are titles.
* ``pagebreak`` -- a page break starts a new chapter.
* ``marker``    -- an explicit delimiter line (``###``/``<<<CHAPTER: Title>>>``/…).
* ``size``      -- no structure; one chapter auto-paginated by size (fallback).
* ``auto``      -- try heading -> pagebreak -> patterns -> format, first with >=2
                   chapters wins, else ``size``.

v1 is text only -- embedded images are ignored; table cells contribute their text.

Returns the platform shape ``[{"title", "pages": [{"title", "body"}]}]``. The
``chapter_key`` and consecutive ``page_number`` fields are assigned downstream by
``normalize_chapters_draft`` during book creation.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from io import BytesIO
from typing import Any, Callable

from apps.catalog.pagination import PAGE_BYTE_BUDGET, chunk_lines, number_repeated_titles

# Ordered list of modes surfaced to the UI/preview (excludes "auto", which is a
# meta-mode). "size" is always last -- the guaranteed fallback.
STRATEGY_MODES = ["heading", "patterns", "format", "pagebreak", "marker", "size"]
ALL_MODES = ["auto"] + STRATEGY_MODES

# A title-ish line is short; longer lines are treated as body even if formatted.
_MAX_TITLE_WORDS = 12
# "auto" accepts a strategy only if it finds at least this many chapters.
_MIN_AUTO_CHAPTERS = 2

# Chapter-heading text patterns (matched on a whole stripped line, case-insensitive
# for the Latin ones). Ethiopic digits ፩-፼ are included for Amharic books.
_PATTERN_DEFAULTS = [
    re.compile(r"^(chapter|part|book|section)\s+(\d+|[ivxlcdm]+|[a-z]+)\b", re.IGNORECASE),
    re.compile(r"^(ምዕራፍ|ክፍል|መጽሐፍ)\s*[\d፩-፼]+"),
    re.compile(r"^\s*(\d{1,3}|[IVXLCDM]{1,7})\.?\s*$"),
]

# Default explicit-marker delimiters. ``### Title`` / ``<<<CHAPTER: Title>>>`` carry
# a title; bare ``===`` / ``***`` / ``---`` (>=3) just separate.
_MARKER_TITLED = [
    re.compile(r"^#{1,6}\s+(?P<title>.+?)\s*#*$"),
    re.compile(r"^<<<\s*chapter\s*:?\s*(?P<title>.*?)\s*>>>$", re.IGNORECASE),
]
_MARKER_BARE = re.compile(r"^([=*#\-])\1{2,}$")


class DocxImportError(ValueError):
    """Raised when the uploaded file is not a readable ``.docx`` document."""


@dataclass
class Block:
    """One paragraph, annotated with signals every detector may consult."""

    text: str
    heading_level: int | None = None
    is_bold: bool = False
    is_centered: bool = False
    is_all_caps: bool = False
    font_size_pt: float | None = None
    starts_new_page: bool = False

    def is_short(self) -> bool:
        return 0 < len(self.text.split()) <= _MAX_TITLE_WORDS


@dataclass
class _Parsed:
    blocks: list[Block] = field(default_factory=list)
    body_font_pt: float | None = None  # most common body font size


# --------------------------------------------------------------------------- public API


def build_chapters_draft_from_docx(
    file_bytes: bytes,
    mode: str = "auto",
    pattern: str | None = None,
    marker: str | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Parse ``.docx`` bytes into ``(chapters_draft, stats)`` using ``mode``.

    ``stats`` reports ``{"chapters", "pages", "paragraphs", "strategy_used"}``.
    Raises :class:`DocxImportError` if the bytes are not a valid Word document,
    or ``ValueError`` if ``pattern`` is not a valid regex.
    """
    parsed = _parse_docx(file_bytes)
    opts = _StrategyOpts.build(pattern=pattern, marker=marker, body_font_pt=parsed.body_font_pt)
    chapters, strategy_used = _run_mode(mode, parsed.blocks, opts)
    draft, stats = _draft_from_chapters(chapters)
    stats["strategy_used"] = strategy_used
    return draft, stats


def summarize_docx_structure(
    file_bytes: bytes,
    pattern: str | None = None,
    marker: str | None = None,
    max_titles: int = 40,
) -> dict[str, Any]:
    """Dry-run: parse once and report detected structure for every mode.

    Returns ``{"recommended", "modes": [{"mode", "strategy_used", "chapters",
    "pages", "titles": [...capped]}]}``. No database writes.
    """
    parsed = _parse_docx(file_bytes)
    opts = _StrategyOpts.build(pattern=pattern, marker=marker, body_font_pt=parsed.body_font_pt)

    modes: list[dict[str, Any]] = []
    for mode in ALL_MODES:
        chapters, strategy_used = _run_mode(mode, parsed.blocks, opts)
        draft, stats = _draft_from_chapters(chapters)
        modes.append(
            {
                "mode": mode,
                "strategy_used": strategy_used,
                "chapters": stats["chapters"],
                "pages": stats["pages"],
                "titles": [c["title"] for c in draft][:max_titles],
            }
        )

    _, recommended = _run_mode("auto", parsed.blocks, opts)
    return {"recommended": recommended, "modes": modes}


# --------------------------------------------------------------------------- parsing


def _parse_docx(file_bytes: bytes) -> _Parsed:
    try:
        from docx import Document  # imported lazily so the dep is optional
    except ImportError as exc:  # pragma: no cover - dependency guard
        raise DocxImportError("python-docx is not installed on the server.") from exc

    try:
        document = Document(BytesIO(file_bytes))
    except Exception as exc:
        raise DocxImportError(
            "Could not read the file as a Word (.docx) document. "
            "If it is an older .doc file, open it in Word and use Save As → .docx."
        ) from exc

    blocks: list[Block] = []
    for para in document.paragraphs:
        text = (para.text or "").strip()
        block = _block_from_paragraph(para, text)
        # Keep empty paragraphs only when they flag a page break (structure signal).
        if text or block.starts_new_page:
            blocks.append(block)

    # Table cells contribute their text as plain body paragraphs.
    for table in getattr(document, "tables", []):
        for row in table.rows:
            for cell in row.cells:
                t = (cell.text or "").strip()
                if t:
                    blocks.append(Block(text=t))

    return _Parsed(blocks=blocks, body_font_pt=_body_font_baseline(blocks))


def _block_from_paragraph(para, text: str) -> Block:
    runs = [r for r in para.runs if (r.text or "").strip()]
    is_bold = bool(runs) and all(r.bold for r in runs)
    sizes = [r.font.size.pt for r in runs if r.font is not None and r.font.size is not None]
    font_size = max(sizes) if sizes else None
    return Block(
        text=text,
        heading_level=_heading_level(_style_name(para)),
        is_bold=is_bold,
        is_centered=_is_centered(para),
        is_all_caps=_is_all_caps(text),
        font_size_pt=font_size,
        starts_new_page=_starts_new_page(para),
    )


def _is_all_caps(text: str) -> bool:
    """True only when the text has cased letters and all are uppercase.

    Scripts without letter case (e.g. Amharic/Ge'ez) have no cased characters, so
    this returns False for them -- otherwise every short Amharic line would look
    like an ALL-CAPS heading.
    """
    cased = [c for c in text if c.lower() != c.upper()]
    return bool(cased) and all(c == c.upper() for c in cased)


def _style_name(para) -> str | None:
    try:
        return para.style.name if para.style is not None else None
    except Exception:
        return None


def _heading_level(style_name: str | None) -> int | None:
    if not style_name:
        return None
    name = style_name.strip().lower()
    if name == "title":
        return 1
    compact = name.replace(" ", "")
    if compact.startswith("heading"):
        suffix = compact[len("heading"):]
        if suffix.isdigit():
            return int(suffix)
    return None


def _is_centered(para) -> bool:
    try:
        alignment = para.alignment or para.paragraph_format.alignment
        return alignment is not None and int(alignment) == 1  # WD_ALIGN_PARAGRAPH.CENTER
    except Exception:
        return False


def _starts_new_page(para) -> bool:
    try:
        if para.paragraph_format.page_break_before:
            return True
    except Exception:
        pass
    try:
        xml = para._p.xml
        return 'w:type="page"' in xml or "lastRenderedPageBreak" in xml
    except Exception:
        return False


def _body_font_baseline(blocks: list[Block]) -> float | None:
    """Most common font size among longer (body-like) paragraphs."""
    counts: dict[float, int] = {}
    for b in blocks:
        if b.font_size_pt is not None and len(b.text.split()) > _MAX_TITLE_WORDS:
            counts[b.font_size_pt] = counts.get(b.font_size_pt, 0) + 1
    if not counts:
        return None
    return max(counts.items(), key=lambda kv: kv[1])[0]


# --------------------------------------------------------------------------- strategies

# A "chapter" during detection: {"title": str|None, "sections": [{"title", "lines"}]}


@dataclass
class _StrategyOpts:
    patterns: list[re.Pattern]
    marker_titled: list[re.Pattern]
    marker_bare: re.Pattern
    body_font_pt: float | None

    @classmethod
    def build(cls, pattern: str | None, marker: str | None, body_font_pt: float | None):
        patterns = list(_PATTERN_DEFAULTS)
        if pattern and pattern.strip():
            try:
                patterns.insert(0, re.compile(pattern.strip(), re.IGNORECASE))
            except re.error as exc:
                raise ValueError(f"Invalid chapter pattern: {exc}") from exc
        marker_titled = list(_MARKER_TITLED)
        marker_bare = _MARKER_BARE
        if marker and marker.strip():
            esc = re.escape(marker.strip())
            marker_titled = [re.compile(rf"^{esc}\s*(?P<title>.*)$")] + marker_titled
        return cls(patterns, marker_titled, marker_bare, body_font_pt)


def _new_chapter(chapters: list[dict], title: str | None) -> dict:
    ch = {"title": title, "sections": []}
    chapters.append(ch)
    return ch


def _append_body(chapters: list[dict], text: str) -> None:
    """Append a body line, opening an Introduction chapter/section if needed."""
    if not chapters:
        _new_chapter(chapters, "Introduction")
    ch = chapters[-1]
    if not ch["sections"]:
        ch["sections"].append({"title": None, "lines": []})
    ch["sections"][-1]["lines"].append(text)


def _detect_heading(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    chapters: list[dict] = []
    for b in blocks:
        level = b.heading_level
        if level is not None and level <= 1:
            _new_chapter(chapters, b.text or f"Chapter {len(chapters) + 1}")
        elif level == 2:
            if not chapters:
                _new_chapter(chapters, b.text or "Introduction")
            chapters[-1]["sections"].append({"title": b.text or None, "lines": []})
        elif b.text:
            _append_body(chapters, b.text)
    return chapters


def _detect_by_title_predicate(
    blocks: list[Block],
    is_title: Callable[[Block], bool],
    title_of: Callable[[Block], str],
) -> list[dict]:
    chapters: list[dict] = []
    for b in blocks:
        if b.text and is_title(b):
            _new_chapter(chapters, title_of(b))
        elif b.text:
            _append_body(chapters, b.text)
    return chapters


def _detect_patterns(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    def is_title(b: Block) -> bool:
        return b.is_short() and any(p.match(b.text) for p in opts.patterns)

    return _detect_by_title_predicate(blocks, is_title, lambda b: b.text)


def _detect_format(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    base = opts.body_font_pt

    def is_title(b: Block) -> bool:
        if not b.is_short():
            return False
        bigger = base is not None and b.font_size_pt is not None and b.font_size_pt >= base * 1.2
        return b.is_centered or b.is_all_caps or b.is_bold or bigger

    return _detect_by_title_predicate(blocks, is_title, lambda b: b.text)


def _detect_pagebreak(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    chapters: list[dict] = []
    for b in blocks:
        if b.starts_new_page:
            title = b.text if b.is_short() else f"Chapter {len(chapters) + 1}"
            _new_chapter(chapters, title)
            if b.text and not b.is_short():
                _append_body(chapters, b.text)
        elif b.text:
            _append_body(chapters, b.text)
    return chapters


def _marker_title(b: Block, opts: _StrategyOpts) -> str | None:
    """Return the chapter title if the line is a marker, else ``None``.

    Titled markers yield their captured title (or ``""`` -> auto number); bare
    separators yield ``""``.
    """
    for p in opts.marker_titled:
        m = p.match(b.text)
        if m:
            return (m.groupdict().get("title") or "").strip()
    if opts.marker_bare.match(b.text):
        return ""
    return None


def _detect_marker(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    chapters: list[dict] = []
    for b in blocks:
        if not b.text:
            continue
        title = _marker_title(b, opts)
        if title is not None:
            _new_chapter(chapters, title or f"Chapter {len(chapters) + 1}")
        else:
            _append_body(chapters, b.text)
    return chapters


def _detect_size(blocks: list[Block], opts: _StrategyOpts) -> list[dict]:
    chapters: list[dict] = [{"title": "Imported book", "sections": [{"title": None, "lines": []}]}]
    for b in blocks:
        if b.text:
            chapters[0]["sections"][0]["lines"].append(b.text)
    return chapters


_DETECTORS: dict[str, Callable[[list[Block], _StrategyOpts], list[dict]]] = {
    "heading": _detect_heading,
    "patterns": _detect_patterns,
    "format": _detect_format,
    "pagebreak": _detect_pagebreak,
    "marker": _detect_marker,
    "size": _detect_size,
}

# Order the auto-cascade tries strategies in.
_AUTO_ORDER = ["heading", "pagebreak", "patterns", "format"]


def _run_mode(mode: str, blocks: list[Block], opts: _StrategyOpts) -> tuple[list[dict], str]:
    """Return ``(chapters, strategy_used)`` for a mode (resolves ``auto``)."""
    if mode == "auto":
        for candidate in _AUTO_ORDER:
            chapters = _DETECTORS[candidate](blocks, opts)
            if _chapter_count_with_content(chapters) >= _MIN_AUTO_CHAPTERS:
                return chapters, candidate
        return _DETECTORS["size"](blocks, opts), "size"
    detector = _DETECTORS.get(mode)
    if detector is None:
        raise ValueError(f"Unknown import mode: {mode}")
    return detector(blocks, opts), mode


def _chapter_count_with_content(chapters: list[dict]) -> int:
    count = 0
    for ch in chapters:
        if any(any(ln.strip() for ln in s["lines"]) for s in ch["sections"]):
            count += 1
    return count


# --------------------------------------------------------------------------- page builder


def _draft_from_chapters(chapters: list[dict]) -> tuple[list[dict[str, Any]], dict[str, int]]:
    draft: list[dict[str, Any]] = []
    stats = {"chapters": 0, "pages": 0, "paragraphs": 0}

    for idx, ch in enumerate(chapters, start=1):
        ch_title = (ch["title"] or "").strip() or f"Chapter {idx}"
        pages: list[dict[str, str]] = []
        for sec in ch["sections"]:
            lines = [ln for ln in sec["lines"] if ln.strip()]
            if not lines:
                continue
            sec_title = (sec["title"] or "").strip() or ch_title
            stats["paragraphs"] += len(lines)
            safe_lines = _split_oversized_lines(lines)
            for part in chunk_lines(safe_lines):
                pages.append({"title": sec_title, "body": "\n".join(part)})
                stats["pages"] += 1
        if pages:
            number_repeated_titles(pages)
            draft.append({"title": ch_title, "pages": pages})
            stats["chapters"] += 1

    return draft, stats


def _split_oversized_lines(lines: list[str], budget: int = PAGE_BYTE_BUDGET) -> list[str]:
    out: list[str] = []
    for line in lines:
        if len(line.encode("utf-8")) <= budget:
            out.append(line)
        else:
            out.extend(_split_long_text(line, budget))
    return out


def _split_long_text(text: str, budget: int) -> list[str]:
    words = text.split()
    if not words:
        return [text]
    pieces: list[str] = []
    cur = ""
    for word in words:
        candidate = f"{cur} {word}" if cur else word
        if len(candidate.encode("utf-8")) <= budget:
            cur = candidate
            continue
        if cur:
            pieces.append(cur)
            cur = ""
        if len(word.encode("utf-8")) > budget:
            pieces.extend(_hard_split(word, budget))
        else:
            cur = word
    if cur:
        pieces.append(cur)
    return pieces or [text]


def _hard_split(token: str, budget: int) -> list[str]:
    pieces: list[str] = []
    cur = ""
    for ch in token:
        if cur and len((cur + ch).encode("utf-8")) > budget:
            pieces.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        pieces.append(cur)
    return pieces
