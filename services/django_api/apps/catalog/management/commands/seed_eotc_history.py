"""
Seed a published Amharic book on Ethiopian Orthodox Tewahedo Church history.

Structure: 10 chapters × 10 pages; each page has 20 styled subtitles and
20 paragraphs (5 Amharic sentences each).

Owner: yohannesgirmaw23@gmail.com

Run (from repo root, with API container up):
  cd infra && docker compose exec api python manage.py seed_eotc_history
"""

from __future__ import annotations

import json

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.catalog.models import Book
from apps.catalog.publishing import normalize_chapters_draft, publish_book

User = get_user_model()

BOOK_TITLE = "የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪክ"
OWNER_EMAIL = "yohannesgirmaw23@gmail.com"
DEFAULT_PASSWORD = "EOTCHistory2026!"

CHAPTERS: list[dict] = [
    {
        "title": "መግቢያ እና የቤተ ክርስቲያን አንሣት",
        "pages": [
            "የቤተ ክርስቲያን ማንነት",
            "የተዋሕዶ ሃይማኖት",
            "የቅዱስ ሲኖዶስ ሚና",
            "የሥነ-ጽሁፍ ቅርስ",
            "የሐዋሪያ ምርኮ",
            "የእምነት ማህበረሰብ",
            "የቅርስ ጥበቃ",
            "የሥነ-ምግባር ዋስትና",
            "የትምህርት ትብ",
            "የመግቢያ ማጠቃለያ",
        ],
    },
    {
        "title": "የአክሱም እና የቀድሞው ቤተ ክርስቲያን",
        "pages": [
            "የአክሱም መጀመሪያ",
            "የንግስት ሐዋሪት",
            "የፍሬምናጦስ ምርኮ",
            "የቅዱስ አትናጽዮስ ስም",
            "የቤተ ክርስቲያን ሕንፃ",
            "የንግድ መስመሮች",
            "የሥነ-ጽሁፍ ማህደር",
            "የአክሱም ቅርስ",
            "የሃይማኖታዊ አንድነት",
            "የአክሱም ማጠቃለያ",
        ],
    },
    {
        "title": "የቅዱሳን አባቶች እና የሰዊስ አገልግሎት",
        "pages": [
            "የሰዊስ መጀመሪያ",
            "ቅዱስ አንብሳዎማ",
            "ቅዱስ ጋርማ ጋርማ",
            "ቅዱስ ተክላ ሃይማኖት",
            "ቅዱስ ይማታ",
            "ቅዱስ ኤጲፋንዮስ",
            "የገዳማት ስርዓት",
            "የፍትሐ ነገስት",
            "የሰዊስ ትምህርት",
            "የቅዱሳን ማጠቃለያ",
        ],
    },
    {
        "title": "የተሰለጥነ ስርዓት እና የሊቃወርት ትምህርት",
        "pages": [
            "የቅዳሴ ሥነ-ልቦና",
            "የጸሎት ዘዴ",
            "የፍትሐ ነገስት ትርጓሜ",
            "የሥነ-ጽሁፍ ቋንቋ",
            "የሊቃንውር ቤቶች",
            "የዘመር ትምህርት",
            "የበዓላት አከባበር",
            "የጸዳል ሥራ",
            "የሕዝብ ትላንትና",
            "የሥርዓት ማጠቃለያ",
        ],
    },
    {
        "title": "የላሊበላ እና የድንጋይ ቤተ ክርስቲያኖች",
        "pages": [
            "የላሊበላ ታሪክ",
            "የድንጋይ ቤተክርስቲያኖች",
            "የንጉሥ ላሊበላ",
            "የሥነ-ህንፅ ሥራ",
            "የሃይማኖታዊ ምስጢር",
            "የዓለም ቅርስ",
            "የጥናት ማዕከል",
            "የእምነት ቦታ",
            "የቱሪዝም እና ቅርስ",
            "የላሊበላ ማጠቃለያ",
        ],
    },
    {
        "title": "የጉንዳ እና የዘመናዊ መንግሥት ቤተ ክርስቲያን",
        "pages": [
            "የጉንዳ መጀመሲ",
            "የንጉሥ ፋሲል",
            "የቤተ ክርስቲያን ሕንፃ",
            "የሊቃውንት ማህበር",
            "የሥነ-ጥበብ ቅርስ",
            "የመንግሥት ግንኙነት",
            "የቅርስ መጻሕፍት",
            "የሰዊስ ሕይወት",
            "የከተማ ባህል",
            "የጉንዳ ማጠቃለያ",
        ],
    },
    {
        "title": "የእስልምና ጫና እና የቤተ ክርስቲያን ትግል",
        "pages": [
            "የውጭ ጫና",
            "የአድዋ ድል",
            "የሃይማኖታዊ አቋም",
            "የሕዝብ ትዕግስት",
            "የቅርስ መከላከል",
            "የሰዊስ ጥንካሬ",
            "የትምህርት ቀጠና",
            "የማህበረሰብ አንድነት",
            "የታሪክ ምስክር",
            "የትግል ማጠቃለያ",
        ],
    },
    {
        "title": "የሊቃንውር ቤቶች እና የትምህርት ቅርስ",
        "pages": [
            "የቅዱስ ሲኖዶስ ትምህርት",
            "የመጻሕፍት ማህደር",
            "የገዳማት ቤተ-መጻሕፍት",
            "የሊቃውንት ሥራ",
            "የቋንቋ ጥናት",
            "የትርጓሜ ስራ",
            "የሥነ-ጽሁፍ ማስቀመጥ",
            "የዘመናዊ ጥናት",
            "የትምህርት ቀጠና",
            "የቤተ-መጻሕፍት ማጠቃለያ",
        ],
    },
    {
        "title": "የቤተ ክርስቲያን ሕይወት በዘመናዊ ኢትዮጵያ",
        "pages": [
            "የፓትርያርክ ሥርዓት",
            "የሃይማኖታዊ ነፃነት",
            "የቤተ ክርስቲያን አስተዳደር",
            "የማህበረሰብ አገልግሎት",
            "የትምህርት ተቋማት",
            "የቅርስ ጥበቃ",
            "የወጣቶች ትምህርት",
            "የሥነ-ምግባር ስርጭት",
            "የአለም አቀፍ ግንኙነት",
            "የዘመናዊ ማጠቃለያ",
        ],
    },
    {
        "title": "የዛሬው ቤተ ክርስቲያን እና ቅርስ ማጠቃለያ",
        "pages": [
            "የዛሬው ሁኔታ",
            "የእምነት ተከታዮች",
            "የቅርስ ቦታዎች",
            "የበዓላት ሕይወት",
            "የሰዊስ ትውፊት",
            "የቤተ ክርስቲያን አገልግሎት",
            "የትውልድ ትምህርት",
            "የቅርስ ማስታወስ",
            "የወደፊት ተስፋ",
            "የመጽሐፍ ማጠቃለያ",
        ],
    },
]

SECTION_THEMES: list[str] = [
    "ታሪካዊ መሠረት",
    "የሥነ-ጽሁፍ ማስረጃ",
    "የቅዱሳን አባቶች ምስክር",
    "የሕዝብ እምነት",
    "የቤተ ክርስቲያን ሥራ",
    "የጸሎት ሕይወት",
    "የቅርስ ጥበቃ",
    "የትምህርት ትብ",
    "የሥነ-ምግባር ዋስትና",
    "የሃይማኖታዊ አንድነት",
    "የሰዊስ ትውፊት",
    "የበዓል አከባበር",
    "የሊቃውንት ሚና",
    "የመጻሕፍት ትርጓሜ",
    "የወጣት ትውልድ",
    "የቤተ ክርስቲያን አገልግሎት",
    "የታሪክ ትምህርት",
    "የእምነት ልምድ",
    "የቅርስ ቦታ",
    "የዛሬው ተግባር",
]

LINE_TEMPLATES: list[str] = [
    "{topic} በ{chapter} ውስጥ ዋና ርዕሰ ጉዳይ ነው።",
    "የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን {theme} በእምነት ውስጥ ትልቅ ቦታ ይሰጣል።",
    "ቅዱሳን አባቶች {page}ን በተመለከተ ትምህርት ሰጥተዋል።",
    "የቤተ ክርስቲያን ሕይወት በዚህ ጉዳይ ላይ ተመስርቶ ቀጥሏል።",
    "ይህ ለአሁኑ ትውልድም የማስታወስ እና የማጽናናት ምንጭ ነው።",
    "በኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪክ {theme} የማይቀር ገጽ ነው።",
    "የ{page} ጥናት ለሃይማኖታዊ ማንነት መሠረታዊ ነው።",
    "በቤተ ክርስቲያኒቱ ትምህርት {topic} በደንብ ይነገራል።",
    "የቅዱስ ሲኖዶስ ውሳኔዎች በዚህ ጉዳይ ላይ መመሪያ ሰጥተዋል።",
    "የሥነ-ጽሁፍ ቋሚነት {theme}ን ለወደፊት ትውልድ ያስቀምጣል።",
    "በገዳማትና በከተማ ቤተ ክርስቲያኖች {page} ተከታይ ሥራ ተሰርቷል።",
    "የሕዝብ እምነትና የቅርስ ጥበቃ በ{chapter} ውስጥ ተደራራይ ነበር።",
    "የተሰለጥነ ስርዓት {topic}ን በየዕለት ሕይወት ውስጥ ያሳያል።",
    "የሊቃውንት ትምህርት {theme}ን ለማስተማር አስፈላጊ መሠረት ነው።",
    "በታሪክ ምንጮች {page} ተደጋጋሚ ማስረጃ አለው።",
    "የቤተ ክርስቲያን አገልግሎት {topic}ን በተግባር ያሳያል።",
    "የእምነት ማህበረሰብ {theme}ን በጋራ ይጠብቃል።",
    "የቅርስ ቦታዎች {page}ን ለአለም ቅርስ ያስፈልጋሉ።",
    "የወጣት ትውልድ {topic}ን በትምህርትና በአገልግሎት መልሶ ይይዛል።",
    "የዛሬው ቤተ ክርስቲያን {theme}ን በእምነትና በትዕግስት ትጠብቃለች።",
]


def _paragraph_lines(
    *,
    chapter_title: str,
    page_title: str,
    section_title: str,
    section_index: int,
    chapter_index: int,
    page_index: int,
) -> str:
    lines: list[str] = []
    for line_i in range(5):
        template = LINE_TEMPLATES[(section_index + line_i + chapter_index + page_index) % len(LINE_TEMPLATES)]
        lines.append(
            template.format(
                topic=section_title,
                chapter=chapter_title,
                page=page_title,
                theme=SECTION_THEMES[(section_index + line_i) % len(SECTION_THEMES)],
            )
        )
    return " ".join(lines)


def _section_subtitle(
    *,
    section_index: int,
    page_title: str,
    chapter_index: int,
    page_index: int,
) -> str:
    theme = SECTION_THEMES[(section_index + chapter_index + page_index) % len(SECTION_THEMES)]
    return f"{section_index + 1}. {page_title} — {theme}"


def _quill_page_body(
    *,
    chapter_title: str,
    page_title: str,
    chapter_index: int,
    page_index: int,
) -> str:
    ops: list[dict] = []
    for section_index in range(20):
        subtitle = _section_subtitle(
            section_index=section_index,
            page_title=page_title,
            chapter_index=chapter_index,
            page_index=page_index,
        )
        paragraph = _paragraph_lines(
            chapter_title=chapter_title,
            page_title=page_title,
            section_title=subtitle,
            section_index=section_index,
            chapter_index=chapter_index,
            page_index=page_index,
        )
        ops.append(
            {
                "insert": subtitle + "\n",
                "attributes": {
                    "header": 3,
                    "bold": True,
                    "color": "#6B4E2E",
                },
            }
        )
        ops.append({"insert": paragraph + "\n\n"})
    return json.dumps(ops, ensure_ascii=False)


def _build_chapters_draft() -> list[dict]:
    raw: list[dict] = []
    for chapter_index, chapter in enumerate(CHAPTERS):
        pages: list[dict] = []
        for page_index, page_title in enumerate(chapter["pages"]):
            pages.append(
                {
                    "title": page_title,
                    "body": _quill_page_body(
                        chapter_title=chapter["title"],
                        page_title=page_title,
                        chapter_index=chapter_index,
                        page_index=page_index,
                    ),
                }
            )
        raw.append({"title": chapter["title"], "pages": pages})
    return normalize_chapters_draft(raw)


class Command(BaseCommand):
    help = (
        "Seed a published Amharic EOTC history book (10 chapters × 10 pages, "
        "20 subtitles + 20 paragraphs per page) "
        f"owned by {OWNER_EMAIL}."
    )

    def handle(self, *args, **options):
        chapters_draft = _build_chapters_draft()
        chapter_count = len(chapters_draft)
        page_count = sum(len(ch["pages"]) for ch in chapters_draft)

        owner, created = User.objects.get_or_create(
            email=OWNER_EMAIL,
            defaults={
                "display_name": "ዮሐንስ ግርማው",
                "role": "admin",
                "preferred_ui_language": "am",
                "is_staff": True,
                "is_superuser": True,
            },
        )
        owner.display_name = "ዮሐንስ ግርማው"
        owner.role = "admin"
        owner.preferred_ui_language = "am"
        owner.is_staff = True
        owner.is_superuser = True
        if created or not owner.has_usable_password():
            owner.set_password(DEFAULT_PASSWORD)
        owner.save()

        book, book_created = Book.objects.get_or_create(
            title=BOOK_TITLE,
            defaults={
                "subtitle": "ከመጀመሪያ እስከ ዛሬ — የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪካዊ ጥናት",
                "summary": (
                    "ይህ መጽሐፍ የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያንን ታሪክ በአሥራ "
                    "ምዕራፎች፣ በመቶ ገጾች እና በአማርኛ ያቀርባል። እያንዳንዱ ገጽ "
                    "ባለ ርዕስ ንዑስ ርዕሶችና የዐምስት መስመር ዓንቀጻት ይዟል።"
                ),
                "author_compiler": "ዮሐንስ ግርማው",
                "primary_language": "am",
                "script_tags": ["Ethi", "ቤተክርስቲያን", "ታሪክ"],
                "chapters_draft": chapters_draft,
                "catalog_visibility": Book.Visibility.HIDDEN,
                "created_by": owner,
            },
        )

        book.subtitle = "ከመጀመሪያ እስከ ዛሬ — የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪካዊ ጥናት"
        book.summary = (
            "ይህ መጽሐፍ የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያንን ታሪክ በአሥራ "
            "ምዕራፎች፣ በመቶ ገጾች እና በአማርኛ ያቀርባል። እያንዳንዱ ገጽ "
            "ባለ ርዕስ ንዑስ ርዕሶችና የዐምስት መስመር ዓንቀጻት ይዟል።"
        )
        book.author_compiler = "ዮሐንስ ግርማው"
        book.primary_language = "am"
        book.script_tags = ["Ethi", "ቤተክርስቲያን", "ታሪክ"]
        book.chapters_draft = chapters_draft
        book.created_by = owner
        book.save()

        outcome = publish_book(book, owner)
        if not outcome.ok:
            self.stderr.write(self.style.ERROR(f"Publish failed: {outcome.error}"))
            return

        book.refresh_from_db()
        self.stdout.write(self.style.SUCCESS("seed_eotc_history: complete"))
        self.stdout.write(f"  user={OWNER_EMAIL} (created={created})")
        if created:
            self.stdout.write(f"  password={DEFAULT_PASSWORD}")
        self.stdout.write(f"  book={BOOK_TITLE}")
        self.stdout.write(f"  book_id={book.id}")
        self.stdout.write(f"  chapters={chapter_count}, pages={page_count}")
        self.stdout.write(f"  visibility={book.catalog_visibility}")
        self.stdout.write(f"  book_created={book_created}")
