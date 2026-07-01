"""Import Bible book JSON(s) (the 80-weahadu data shape) as verse-addressable
open content: one ``Book`` per canonical book (``is_bible=True``) plus
``BibleSection`` / ``BibleVerse`` rows hanging off a fresh ``BookRevision``.

Unlike ``import_bible_book`` (which builds the page/encrypted-package pipeline),
this populates the verse model the /bible API reads from. Verse numbers are
taken verbatim from the JSON (they can be sparse) and never derived from order.

JSON shape per file::

    { "book_name_am", "book_name_en", "book_short_name_am", "book_short_name_en",
      "book_number", "testament": "old|new",
      "chapters": [ {"chapter": 1,
        "sections": [ {"title": "...", "verses": [{"verse": 1, "text": "..."}]} ]} ] }

Usage::

    python manage.py import_bible --dir /data/am            # all *.json
    python manage.py import_bible --file /data/am/55-matthew.json
    python manage.py import_bible --dir /data/am --lang am
"""

from __future__ import annotations

import json
import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.catalog.models import (
    BibleSection,
    BibleVerse,
    Book,
    BookRevision,
)
from apps.catalog.search_normalization import normalize_search_text

User = get_user_model()

_TESTAMENT_AM = {"old": "ብሉይ ኪዳን", "new": "አዲስ ኪዳን"}


class Command(BaseCommand):
    help = "Import Bible book JSON(s) as verse-addressable open content."

    def add_arguments(self, parser):
        src = parser.add_mutually_exclusive_group(required=True)
        src.add_argument("--dir", help="Directory of *.json Bible book files.")
        src.add_argument("--file", help="Path to a single Bible book JSON file.")
        parser.add_argument("--lang", default="am", help="primary_language (default: am).")

    def handle(self, *args, **opts):
        lang = opts["lang"]
        paths = self._resolve_paths(opts)
        admin = self._admin()

        total_books = total_verses = 0
        for path in paths:
            try:
                with open(path, encoding="utf-8") as fh:
                    data = json.load(fh)
            except (OSError, json.JSONDecodeError) as exc:
                self.stderr.write(self.style.ERROR(f"skip {path}: {exc}"))
                continue
            try:
                title, n_verses = self._import_one(data, lang, admin)
            except CommandError as exc:
                self.stderr.write(self.style.WARNING(f"skip {os.path.basename(path)}: {exc}"))
                continue
            total_books += 1
            total_verses += n_verses
            self.stdout.write(self.style.SUCCESS(f"  ✓ {title}: {n_verses} verses"))

        self.stdout.write(self.style.SUCCESS(
            f"Done. Imported {total_books} book(s), {total_verses} verse(s)."
        ))

    # ------------------------------------------------------------------ helpers
    def _resolve_paths(self, opts) -> list[str]:
        if opts.get("file"):
            return [opts["file"]]
        directory = opts["dir"]
        if not os.path.isdir(directory):
            raise CommandError(f"Not a directory: {directory}")
        files = sorted(
            os.path.join(directory, f)
            for f in os.listdir(directory)
            if f.lower().endswith(".json")
        )
        if not files:
            raise CommandError(f"No .json files in {directory}")
        return files

    def _admin(self):
        return (
            User.objects.filter(is_superuser=True).order_by("date_joined").first()
            or User.objects.filter(is_staff=True).order_by("date_joined").first()
        )

    @transaction.atomic
    def _import_one(self, data: dict, lang: str, admin):
        name_am = (data.get("book_name_am") or "").strip()
        name_en = (data.get("book_name_en") or "").strip()
        short_am = (data.get("book_short_name_am") or "").strip()
        short_en = (data.get("book_short_name_en") or "").strip()
        testament = (data.get("testament") or "").strip().lower()
        number = data.get("book_number")
        title = name_am if lang == "am" else (name_en or name_am)
        if not title:
            raise CommandError("missing book_name_am/en")
        if testament not in ("old", "new"):
            testament = ""

        chapters = data.get("chapters") or []
        if not chapters:
            raise CommandError("no chapters")

        # One Book per (language, canonical number). Fall back to title when the
        # source omits book_number so re-imports still update in place.
        lookup = (
            {"primary_language": lang, "canonical_number": number}
            if number is not None
            else {"primary_language": lang, "title": title}
        )
        book, _ = Book.objects.get_or_create(
            is_bible=True,
            defaults={"title": title},
            **lookup,
        )
        book.title = title
        book.is_bible = True
        book.genre = "bible"  # surfaces under the "Bible" catalogue category
        book.primary_language = lang
        book.testament_type = testament
        book.canonical_number = number
        book.bible_name_en = name_en
        book.bible_short_name_am = short_am
        book.bible_short_name_en = short_en
        book.subtitle = name_en if lang == "am" else name_am
        book.author_compiler = "መጽሐፍ ቅዱስ" if lang == "am" else "Holy Bible"
        book.summary = f"{name_am} ({name_en}) — {_TESTAMENT_AM.get(testament, testament)}".strip(" —")
        book.script_tags = [t for t in ["bible", f"{testament}-testament" if testament else "", lang] if t]
        book.catalog_visibility = Book.Visibility.PUBLISHED
        book.created_by = book.created_by or admin
        book.save()

        # Rebuild from scratch: dropping revisions cascades verses + sections.
        book.published_revision = None
        book.save(update_fields=["published_revision"])
        book.revisions.all().delete()

        revision = BookRevision.objects.create(
            book=book,
            revision_number=1,
            status=BookRevision.Status.PUBLISHED,
            content_format="bible_verses",
            created_by=admin,
        )

        sections: list[BibleSection] = []
        verses: list[BibleVerse] = []
        for chapter in chapters:
            if not isinstance(chapter, dict):
                continue
            ch_num = chapter.get("chapter")
            if ch_num is None:
                continue
            ordinal = 0
            seq = 0  # running 1-based verse position within this chapter
            for section in chapter.get("sections") or []:
                if not isinstance(section, dict):
                    continue
                raw_verses = [
                    v for v in (section.get("verses") or [])
                    if isinstance(v, dict) and v.get("verse") is not None
                ]
                if not raw_verses:
                    continue
                sec = BibleSection(
                    revision=revision,
                    book=book,
                    chapter=ch_num,
                    ordinal=ordinal,
                    title=(section.get("title") or "").strip(),
                    start_verse=raw_verses[0]["verse"],
                    end_verse=raw_verses[-1]["verse"],
                )
                sections.append(sec)
                ordinal += 1
                for v in raw_verses:
                    text = (v.get("text") or "").strip()
                    seq += 1
                    verses.append(BibleVerse(
                        revision=revision,
                        book=book,
                        section=sec,
                        chapter=ch_num,
                        verse=v["verse"],
                        verse_seq=seq,
                        text_plain=text,
                        text_normalized=normalize_search_text(text),
                    ))

        if not verses:
            raise CommandError("no verses")

        BibleSection.objects.bulk_create(sections, batch_size=500)
        BibleVerse.objects.bulk_create(verses, batch_size=1000)

        book.published_revision = revision
        book.save(update_fields=["published_revision"])
        return title, len(verses)
