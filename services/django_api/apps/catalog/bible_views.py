"""Read + search + reference API for verse-addressable Bible books.

Bible books are open content (no payment/encryption): these endpoints serve
``BibleVerse`` / ``BibleSection`` rows directly. Auth is required to match the
rest of the catalogue API, but no purchase/entitlement is checked.
"""

from __future__ import annotations

import re

from django.db.models import Count, Max, Q
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import BibleSection, BibleVerse, Book
from apps.catalog.search_normalization import normalize_search_text

_SEARCH_LIMIT = 50

# "Matthew 3", "ዮሐንስ 3 16". Book is non-greedy so a leading ordinal (1 ቆሮ)
# stays part of the name.
_REF_RE = re.compile(
    r"^(?P<book>.+?)[\s.]*(?P<chapter>\d+)"
    r"(?:[:\s]+(?P<v1>\d+)(?:\s*-\s*(?P<v2>\d+))?)?$"
)


def _bible_books_qs():
    return Book.objects.filter(
        is_bible=True, catalog_visibility=Book.Visibility.PUBLISHED
    )


def _book_brief(book: Book) -> dict:
    return {
        "id": str(book.id),
        "title": book.title,
        "name_en": book.bible_name_en,
        "short_name_am": book.bible_short_name_am,
        "short_name_en": book.bible_short_name_en,
        "testament": book.testament_type,
        "canonical_number": book.canonical_number,
    }


def _resolve_book(name: str) -> Book | None:
    """Match a parsed book name against title / English / short-name aliases."""
    target = normalize_search_text(name)
    if not target:
        return None
    # Canonical order so an ambiguous bare name (e.g. "ዮሐንስ") resolves to the
    # earliest book — the Gospel of John (58) before the epistle 1 John (65).
    books = list(_bible_books_qs().order_by("canonical_number"))

    def variants(b: Book):
        return (b.title, b.bible_name_en, b.bible_short_name_am, b.bible_short_name_en)

    # Exact normalized match first, then prefix, then contains.
    for b in books:
        if any(normalize_search_text(v) == target for v in variants(b)):
            return b
    for b in books:
        if any(normalize_search_text(v).startswith(target) for v in variants(b) if v):
            return b
    for b in books:
        if any(target in normalize_search_text(v) for v in variants(b) if v):
            return b
    return None


def _verse_payload(v: BibleVerse, section_ordinals: dict | None = None) -> dict:
    return {
        "verse": v.verse,
        "verse_seq": v.verse_seq,
        "text": v.text_plain,
        "section_ordinal": (
            section_ordinals.get(v.section_id) if section_ordinals else None
        ),
    }


class BibleBookListView(APIView):
    """GET /bible/books?testament=old|new — canonical book list."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = _bible_books_qs()
        testament = (request.query_params.get("testament") or "").strip().lower()
        if testament in ("old", "new"):
            qs = qs.filter(testament_type=testament)
        qs = qs.order_by("canonical_number", "title")

        chapter_counts = {
            row["book"]: row["n"]
            for row in BibleVerse.objects.filter(book__in=qs)
            .values("book")
            .annotate(n=Count("chapter", distinct=True))
        }
        items = []
        for book in qs:
            data = _book_brief(book)
            data["chapter_count"] = chapter_counts.get(book.id, 0)
            items.append(data)
        return Response({"items": items})


class BibleChapterListView(APIView):
    """GET /bible/books/<id>/chapters — chapter index with counts."""

    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        book = _bible_books_qs().filter(pk=book_id).first()
        if book is None:
            return Response(
                {"error": {"code": "not_found", "message": "Bible book not found"}},
                status=404,
            )
        verse_counts = {
            r["chapter"]: r["n"]
            for r in BibleVerse.objects.filter(book=book)
            .values("chapter")
            .annotate(n=Count("id"))
        }
        section_counts = {
            r["chapter"]: r["n"]
            for r in BibleSection.objects.filter(book=book)
            .values("chapter")
            .annotate(n=Count("id"))
        }
        chapters = [
            {
                "chapter": ch,
                "verse_count": verse_counts[ch],
                "section_count": section_counts.get(ch, 0),
            }
            for ch in sorted(verse_counts)
        ]
        return Response({"book": _book_brief(book), "chapters": chapters})


class BibleChapterView(APIView):
    """GET /bible/books/<id>/chapters/<n> — full chapter: sections + verses."""

    permission_classes = [IsAuthenticated]

    def get(self, request, book_id, chapter):
        book = _bible_books_qs().filter(pk=book_id).first()
        if book is None:
            return Response(
                {"error": {"code": "not_found", "message": "Bible book not found"}},
                status=404,
            )
        sections = list(
            BibleSection.objects.filter(book=book, chapter=chapter).order_by("ordinal")
        )
        if not sections and not BibleVerse.objects.filter(book=book, chapter=chapter).exists():
            return Response(
                {"error": {"code": "not_found", "message": "Chapter not found"}},
                status=404,
            )
        section_ordinals = {s.id: s.ordinal for s in sections}
        verses = BibleVerse.objects.filter(book=book, chapter=chapter).order_by("verse_seq")
        return Response(
            {
                "book": _book_brief(book),
                "chapter": int(chapter),
                "sections": [
                    {
                        "ordinal": s.ordinal,
                        "title": s.title,
                        "start_verse": s.start_verse,
                        "end_verse": s.end_verse,
                    }
                    for s in sections
                ],
                "verses": [_verse_payload(v, section_ordinals) for v in verses],
            }
        )


class BibleReferenceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        raw = (request.query_params.get("q") or "").strip()
        match = _REF_RE.match(raw)
        if not match:
            return Response(
                {"error": {"code": "bad_reference", "message": "Unrecognised reference"}},
                status=400,
            )
        book = _resolve_book(match.group("book"))
        if book is None:
            return Response(
                {"error": {"code": "book_not_found", "message": "Book not recognised"}},
                status=404,
            )
        chapter = int(match.group("chapter"))
        verses = BibleVerse.objects.filter(book=book, chapter=chapter).order_by("verse_seq")
        v1 = match.group("v1")
        if v1 is not None:
            v2 = int(match.group("v2") or v1)
            verses = verses.filter(verse__gte=int(v1), verse__lte=v2)
        verses = list(verses)
        if not verses:
            return Response(
                {"error": {"code": "not_found", "message": "Reference has no verses"}},
                status=404,
            )
        return Response(
            {
                "book": _book_brief(book),
                "chapter": chapter,
                "verses": [_verse_payload(v) for v in verses],
            }
        )


class BibleSearchView(APIView):
    """GET /bible/search?q=&testament=&book_id= — verse full-text search."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = (request.query_params.get("q") or "").strip()
        if len(query) < 2:
            return Response({"items": [], "total": 0})
        normalized = normalize_search_text(query)
        rows = BibleVerse.objects.filter(
            Q(text_normalized__contains=normalized) | Q(text_plain__icontains=query)
        ).select_related("book")

        testament = (request.query_params.get("testament") or "").strip().lower()
        if testament in ("old", "new"):
            rows = rows.filter(book__testament_type=testament)
        book_id = (request.query_params.get("book_id") or "").strip()
        if book_id:
            rows = rows.filter(book_id=book_id)

        total = rows.count()
        rows = rows.order_by("book__canonical_number", "chapter", "verse_seq")[:_SEARCH_LIMIT]
        items = [
            {
                "book_id": str(v.book_id),
                "book_title": v.book.title,
                "canonical_number": v.book.canonical_number,
                "chapter": v.chapter,
                "verse": v.verse,
                "text": v.text_plain,
            }
            for v in rows
        ]
        return Response({"items": items, "total": total, "limit": _SEARCH_LIMIT})
