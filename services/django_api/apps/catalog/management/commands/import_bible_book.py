"""
Import a single Bible book JSON (the 80-weahadu data shape) as ONE published
book, mapping: Bible chapter -> book chapter, section -> page, verses -> body.

JSON shape expected:
    {
      "book_name_am": "...", "book_name_en": "...",
      "book_short_name_am": "...", "testament": "old|new",
      "chapters": [
        {"chapter": 1, "sections": [
            {"title": "..."|null, "verses": [{"verse": 1, "text": "..."}, ...]}
        ]}
      ]
    }

Reads the JSON from --file PATH, or from STDIN when --stdin is given (useful to
pipe a file that lives outside the container's mounted volume):

    docker compose ... exec -T api python manage.py import_bible_book --stdin \
        < /path/on/host/01-genesis.json
"""

from __future__ import annotations

import json
import sys

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from apps.catalog.models import Book, BookPage, BookTag, Tag
from apps.catalog.publishing import publish_book
from apps.catalog.storage_s3 import ensure_bucket, is_object_storage_configured

User = get_user_model()


class Command(BaseCommand):
    help = "Import a Bible book JSON as one published book (chapters/sections/verses)."

    def add_arguments(self, parser):
        src = parser.add_mutually_exclusive_group(required=True)
        src.add_argument("--file", help="Path to the book JSON (inside the container).")
        src.add_argument("--stdin", action="store_true", help="Read the JSON from stdin.")
        parser.add_argument("--lang", default="am", help="primary_language (default: am).")
        parser.add_argument("--republish", action="store_true",
                            help="Rebuild content even if the book already has pages.")

    def handle(self, *args, **opts):
        raw = sys.stdin.read() if opts["stdin"] else open(opts["file"], encoding="utf-8").read()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise CommandError(f"Invalid JSON: {exc}")

        lang = opts["lang"]
        name_am = (data.get("book_name_am") or "").strip()
        name_en = (data.get("book_name_en") or "").strip()
        testament = (data.get("testament") or "").strip().lower()
        title = name_am if lang == "am" else (name_en or name_am)
        if not title:
            raise CommandError("Could not determine a title (book_name_am/en missing).")

        chapters = data.get("chapters") or []
        chapters_draft, n_pages, n_verses = self._build_draft(chapters, lang)
        if not chapters_draft:
            raise CommandError("No chapters/verses found to import.")

        admin = self._admin()
        if is_object_storage_configured():
            try:
                ensure_bucket()
            except Exception as exc:  # pragma: no cover
                self.stderr.write(self.style.WARNING(f"ensure_bucket skipped: {exc}"))

        first_verse = self._first_verse_text(chapters)
        summary = (
            f"{name_am} ({name_en}) — {'ብሉይ ኪዳን' if testament == 'old' else 'አዲስ ኪዳን' if testament == 'new' else testament}። "
            f"{first_verse}"
        ).strip()

        tag_slugs = ["bible", "amharic" if lang == "am" else "english"]
        if testament in ("old", "new"):
            tag_slugs.append(f"{testament}-testament")

        book, created = Book.objects.get_or_create(
            title=title,
            defaults={
                "subtitle": name_en if lang == "am" else name_am,
                "summary": summary,
                "author_compiler": "መጽሐፍ ቅዱስ" if lang == "am" else "Holy Bible",
                "primary_language": lang,
                "script_tags": tag_slugs,
                "created_by": admin,
            },
        )
        book.subtitle = name_en if lang == "am" else name_am
        book.summary = summary
        book.primary_language = lang
        book.script_tags = tag_slugs
        book.created_by = book.created_by or admin
        book.chapters_draft = chapters_draft
        book.save()

        self._tags(tag_slugs, book)

        has_pages = book.published_revision is not None and BookPage.objects.filter(
            revision=book.published_revision
        ).exists()
        if has_pages and not opts["republish"]:
            self.stdout.write(self.style.WARNING(
                f"'{title}' already has content; pass --republish to rebuild. Skipping."
            ))
            return

        # Build a fresh revision from the JSON draft only: drop any existing
        # revisions (and their cascaded pages/index) so publish_book cannot
        # re-sync chapters_draft from a stale/oversized prior revision.
        if not created:
            book.published_revision = None
            book.save(update_fields=["published_revision"])
            removed, _ = book.revisions.all().delete()
            if removed:
                self.stdout.write(f"cleared {removed} stale revision rows before rebuild")
            book.chapters_draft = chapters_draft
            book.save(update_fields=["chapters_draft"])

        outcome = publish_book(book, admin)
        if not outcome.ok:
            raise CommandError(f"Publish failed: {outcome.error}")
        book.refresh_from_db()
        page_count = BookPage.objects.filter(revision=book.published_revision).count()
        self.stdout.write(self.style.SUCCESS(
            f"Imported '{title}': {len(chapters_draft)} chapters, {page_count} pages "
            f"({n_verses} verses)  id={book.id}"
        ))

    # ------------------------------------------------------------------ helpers
    # Each page becomes a row in book_content_index whose normalized text is
    # btree-indexed (PostgreSQL caps an index row at ~2704 bytes). Keep each
    # page body comfortably under that in UTF-8 bytes, splitting long sections.
    PAGE_BYTE_BUDGET = 1600

    def _build_draft(self, chapters, lang):
        draft = []
        n_pages = n_verses = 0
        for c in chapters:
            if not isinstance(c, dict):
                continue
            num = c.get("chapter")
            ch_title = (f"ምዕራፍ {num}" if lang == "am" else f"Chapter {num}")
            pages = []
            for section in c.get("sections") or []:
                if not isinstance(section, dict):
                    continue
                sec_title = (section.get("title") or "").strip() or ch_title
                lines = []
                for v in section.get("verses") or []:
                    if not isinstance(v, dict):
                        continue
                    text = (v.get("text") or "").strip()
                    if not text:
                        continue
                    lines.append(f"{v.get('verse')}። {text}" if lang == "am"
                                 else f"{v.get('verse')}. {text}")
                    n_verses += 1
                if not lines:
                    continue
                # split the section's verses into byte-bounded pages
                for part in self._chunk_lines(lines):
                    pages.append({"title": sec_title, "body": "\n".join(part)})
                    n_pages += 1
            if pages:
                # if a section spilled into multiple pages, disambiguate titles
                self._number_repeated_titles(pages)
                draft.append({"title": ch_title, "pages": pages})
        return draft, n_pages, n_verses

    def _chunk_lines(self, lines):
        """Group verse lines into chunks whose joined UTF-8 size <= budget."""
        chunks, cur, size = [], [], 0
        for line in lines:
            b = len(line.encode("utf-8")) + 1  # +1 for the newline
            if cur and size + b > self.PAGE_BYTE_BUDGET:
                chunks.append(cur)
                cur, size = [], 0
            cur.append(line)
            size += b
        if cur:
            chunks.append(cur)
        return chunks

    @staticmethod
    def _number_repeated_titles(pages):
        seen = {}
        counts = {}
        for p in pages:
            counts[p["title"]] = counts.get(p["title"], 0) + 1
        for p in pages:
            if counts[p["title"]] > 1:
                seen[p["title"]] = seen.get(p["title"], 0) + 1
                p["title"] = f"{p['title']} ({seen[p['title']]})"

    def _first_verse_text(self, chapters):
        for c in chapters:
            for s in c.get("sections") or []:
                for v in s.get("verses") or []:
                    t = (v.get("text") or "").strip()
                    if t:
                        return t
        return ""

    def _admin(self):
        admin, _ = User.objects.get_or_create(
            email="admin@localhost",
            defaults={"display_name": "Admin", "is_staff": True, "is_superuser": True, "role": "admin"},
        )
        admin.is_staff = admin.is_superuser = True
        if not admin.has_usable_password():
            admin.set_password("adminadminadmin")
            admin.save()
        return admin

    def _tags(self, slugs, book):
        labels = {
            "bible": "መጽሐፍ ቅዱስ / Bible",
            "old-testament": "ብሉይ ኪዳን / Old Testament",
            "new-testament": "አዲስ ኪዳን / New Testament",
            "amharic": "አማርኛ / Amharic",
            "english": "English",
        }
        for slug in slugs:
            tag, _ = Tag.objects.get_or_create(slug=slug, defaults={"label": labels.get(slug, slug)})
            BookTag.objects.get_or_create(book=book, tag=tag)
