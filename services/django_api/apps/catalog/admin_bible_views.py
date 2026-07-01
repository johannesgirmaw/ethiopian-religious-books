"""Admin CRUD for verse-addressable Bible content.

Chapter-level bulk replace: the editor edits one chapter (its sections + verses)
and PUTs the whole chapter back, which is atomic and keeps verse_seq consistent.
Mirrors the ``import_bible`` shape so the same data flows through either path.
"""

from __future__ import annotations

from django.db import transaction
from django.db.models import Count, Max
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.bible_views import _book_brief, _verse_payload
from apps.catalog.models import BibleSection, BibleVerse, Book, BookRevision
from apps.catalog.permissions import IsPublisherOrAuthor
from apps.catalog.search_normalization import normalize_search_text


def _err(code: str, message: str, http: int):
    return Response({"error": {"code": code, "message": message}}, status=http)


class AdminBibleChaptersView(APIView):
    """GET /admin/bible/books/<id>/chapters — chapter index for editing.

    Unlike the public endpoint this works for any visibility (drafts) and
    returns an empty list for a Bible book that has no content yet.
    """

    permission_classes = [IsPublisherOrAuthor]

    def get(self, request, book_id):
        book = Book.objects.filter(pk=book_id).first()
        if book is None:
            return _err("not_found", "Book not found", status.HTTP_404_NOT_FOUND)
        if not book.is_bible:
            return _err(
                "not_bible",
                "Book is not marked as a Bible book",
                status.HTTP_400_BAD_REQUEST,
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


class AdminBibleChapterView(APIView):
    """PUT/DELETE /admin/bible/books/<id>/chapters/<n>."""

    permission_classes = [IsPublisherOrAuthor]

    def _book_or_error(self, book_id):
        book = Book.objects.filter(pk=book_id).first()
        if book is None:
            return None, _err("not_found", "Book not found", status.HTTP_404_NOT_FOUND)
        if not book.is_bible:
            return None, _err(
                "not_bible",
                "Book is not marked as a Bible book",
                status.HTTP_400_BAD_REQUEST,
            )
        return book, None

    def get(self, request, book_id, chapter):
        book, err = self._book_or_error(book_id)
        if err:
            return err
        sections = list(
            BibleSection.objects.filter(book=book, chapter=chapter).order_by("ordinal")
        )
        section_ordinals = {s.id: s.ordinal for s in sections}
        verses = BibleVerse.objects.filter(
            book=book, chapter=chapter
        ).order_by("verse_seq")
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

    def _bible_revision(self, book) -> BookRevision:
        """The book's verse revision, created on demand for a fresh Bible book."""
        rev = book.published_revision
        if rev is not None and rev.content_format == "bible_verses":
            return rev
        num = (book.revisions.aggregate(m=Max("revision_number"))["m"] or 0) + 1
        rev = BookRevision.objects.create(
            book=book,
            revision_number=num,
            status=BookRevision.Status.PUBLISHED,
            content_format="bible_verses",
        )
        book.published_revision = rev
        book.save(update_fields=["published_revision"])
        return rev

    @transaction.atomic
    def put(self, request, book_id, chapter):
        book, err = self._book_or_error(book_id)
        if err:
            return err
        rev = self._bible_revision(book)

        sections_in = request.data.get("sections")
        if not isinstance(sections_in, list):
            return _err("bad_request", "'sections' must be a list", status.HTTP_400_BAD_REQUEST)

        # Replace the whole chapter so verse_seq / ordinals stay consistent.
        BibleVerse.objects.filter(revision=rev, chapter=chapter).delete()
        BibleSection.objects.filter(revision=rev, chapter=chapter).delete()

        seq = 0
        ordinal = 0
        total_verses = 0
        for sec in sections_in:
            if not isinstance(sec, dict):
                continue
            raw = [
                v for v in (sec.get("verses") or [])
                if isinstance(v, dict) and v.get("verse") is not None
            ]
            if not raw:
                continue
            try:
                numbers = [int(v["verse"]) for v in raw]
            except (TypeError, ValueError):
                return _err("bad_request", "verse numbers must be integers", status.HTTP_400_BAD_REQUEST)

            section = BibleSection.objects.create(
                revision=rev,
                book=book,
                chapter=chapter,
                ordinal=ordinal,
                title=(sec.get("title") or "").strip(),
                start_verse=numbers[0],
                end_verse=numbers[-1],
            )
            ordinal += 1
            batch = []
            for v, number in zip(raw, numbers):
                seq += 1
                text = (v.get("text") or "").strip()
                batch.append(BibleVerse(
                    revision=rev,
                    book=book,
                    section=section,
                    chapter=chapter,
                    verse=number,
                    verse_seq=seq,
                    text_plain=text,
                    text_normalized=normalize_search_text(text),
                ))
            BibleVerse.objects.bulk_create(batch)
            total_verses += len(batch)

        return Response(
            {"chapter": int(chapter), "sections": ordinal, "verses": total_verses}
        )

    @transaction.atomic
    def delete(self, request, book_id, chapter):
        book, err = self._book_or_error(book_id)
        if err:
            return err
        rev = book.published_revision
        if rev is not None:
            BibleVerse.objects.filter(revision=rev, chapter=chapter).delete()
            BibleSection.objects.filter(revision=rev, chapter=chapter).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
