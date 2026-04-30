import json

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.catalog.models import Book, BookRevision
from apps.catalog.storage_s3 import ensure_bucket, put_bytes

User = get_user_model()


BOOK_SEEDS = [
    {
        "title": "Kebra Nagast",
        "subtitle": "The Glory of Kings",
        "summary": "A cornerstone Ethiopian text linking Solomonic lineage, sacred kingship, and Christian tradition.",
        "author": "Traditional compilation",
        "language": "gez",
        "tags": ["Ethi", "History", "Christian"],
    },
    {
        "title": "The Book of Enoch",
        "subtitle": "Ethiopic Recension",
        "summary": "An influential apocalyptic work preserved in full in Ge'ez manuscripts and Ethiopian canon study.",
        "author": "Attributed to Enoch",
        "language": "gez",
        "tags": ["Ethi", "Apocalyptic", "Canon"],
    },
    {
        "title": "Fetha Nagast",
        "subtitle": "Law of the Kings",
        "summary": "A legal and ecclesiastical code shaping civil and church practice in historical Ethiopia.",
        "author": "Translated and adapted tradition",
        "language": "gez",
        "tags": ["Law", "Ethi", "Canon"],
    },
    {
        "title": "Synaxarium",
        "subtitle": "Lives of Saints, Daily Readings",
        "summary": "Daily commemorations of saints and martyrs used in liturgical and devotional life.",
        "author": "Ethiopian Orthodox tradition",
        "language": "am",
        "tags": ["Liturgy", "Saints", "Devotion"],
    },
    {
        "title": "Metsihafe Kidane Mehret",
        "subtitle": "Book of the Covenant of Mercy",
        "summary": "A devotional text centered on mercy, intercession, and covenant themes in Ethiopian spirituality.",
        "author": "Traditional Ethiopian text",
        "language": "am",
        "tags": ["Devotion", "Prayer", "Mercy"],
    },
    {
        "title": "Weddase Maryam",
        "subtitle": "Praises of Mary",
        "summary": "A liturgical cycle of Marian praises commonly used in worship and personal prayer.",
        "author": "Liturgical compilation",
        "language": "am",
        "tags": ["Marian", "Liturgy", "Prayer"],
    },
    {
        "title": "Anaphora of the Apostles",
        "subtitle": "Ethiopian Eucharistic Liturgy",
        "summary": "A central anaphora text used in Eucharistic celebration across Ethiopian liturgical practice.",
        "author": "Apostolic liturgical tradition",
        "language": "gez",
        "tags": ["Liturgy", "Eucharist", "Geez"],
    },
    {
        "title": "Metsihafe Qeddase",
        "subtitle": "Book of the Divine Liturgy",
        "summary": "Collection of liturgical orders and Eucharistic prayers foundational to Ethiopian Orthodox worship.",
        "author": "Ethiopian Orthodox Church",
        "language": "gez",
        "tags": ["Qeddase", "Liturgy", "Church"],
    },
    {
        "title": "Prayer Book of the Hours",
        "subtitle": "Canonical Hours in Ethiopian Tradition",
        "summary": "Structured prayers for morning, noon, evening, and night in monastic and lay devotion.",
        "author": "Liturgical tradition",
        "language": "am",
        "tags": ["Prayer", "Hours", "Devotion"],
    },
    {
        "title": "Commentary on the Gospel of John",
        "subtitle": "Traditional Ethiopian Homiletic Notes",
        "summary": "A teaching-oriented commentary emphasizing Christology, faith, and sacramental life.",
        "author": "Traditional commentary school",
        "language": "am",
        "tags": ["Commentary", "Gospel", "Teaching"],
    },
    {
        "title": "Dersane Mikael",
        "subtitle": "Homily of Saint Michael",
        "summary": "Beloved Ethiopian homiletic text focused on archangelic intercession and spiritual perseverance.",
        "author": "Homiletic tradition",
        "language": "am",
        "tags": ["Homily", "Archangel", "Devotion"],
    },
    {
        "title": "Miracles of Mary",
        "subtitle": "Selections from Ethiopian Traditions",
        "summary": "Narratives of compassion and deliverance associated with the intercession of Saint Mary.",
        "author": "Traditional narratives",
        "language": "am",
        "tags": ["Marian", "Narrative", "Devotion"],
    },
    {
        "title": "Book of the Covenant",
        "subtitle": "Metsihafe Kidan, Selected Chapters",
        "summary": "Teachings on covenant ethics, communal life, and apostolic witness in Ethiopian tradition.",
        "author": "Traditional ecclesial text",
        "language": "gez",
        "tags": ["Covenant", "Ethics", "Church"],
    },
    {
        "title": "Acts of the Apostles",
        "subtitle": "Ethiopian Study Edition",
        "summary": "Narrative of apostolic mission and early church growth used for catechesis and study.",
        "author": "Biblical canon",
        "language": "am",
        "tags": ["Bible", "Apostles", "Study"],
    },
    {
        "title": "The Didaskalia",
        "subtitle": "Church Order and Instruction",
        "summary": "Church discipline, clergy conduct, and pastoral instruction in a historic Ethiopian context.",
        "author": "Early church tradition",
        "language": "am",
        "tags": ["Church Order", "Pastoral", "Instruction"],
    },
]


class Command(BaseCommand):
    help = "Seed realistic published books for admin/catalog demos."

    def add_arguments(self, parser):
        parser.add_argument("--count", type=int, default=15, help="How many books to seed (max 15).")

    def handle(self, *args, **options):
        requested = max(1, min(int(options["count"]), len(BOOK_SEEDS)))
        books = BOOK_SEEDS[:requested]

        admin, _ = User.objects.get_or_create(
            email="admin@localhost",
            defaults={
                "display_name": "Admin",
                "is_staff": True,
                "is_superuser": True,
            },
        )
        admin.is_staff = True
        admin.is_superuser = True
        admin.display_name = admin.display_name or "Admin"
        admin.set_password("adminadminadmin")
        admin.save()

        uploaded = 0
        created = 0
        for idx, data in enumerate(books, start=1):
            book, was_created = Book.objects.get_or_create(
                title=data["title"],
                defaults={
                    "subtitle": data["subtitle"],
                    "summary": data["summary"],
                    "author_compiler": data["author"],
                    "primary_language": data["language"],
                    "script_tags": data["tags"],
                    "catalog_visibility": Book.Visibility.PUBLISHED,
                    "created_by": admin,
                },
            )
            created += int(was_created)
            if not was_created:
                book.subtitle = data["subtitle"]
                book.summary = data["summary"]
                book.author_compiler = data["author"]
                book.primary_language = data["language"]
                book.script_tags = data["tags"]
                book.catalog_visibility = Book.Visibility.PUBLISHED
                book.created_by = book.created_by or admin
                book.save()

            rev, _ = BookRevision.objects.get_or_create(
                book=book,
                revision_number=1,
                defaults={
                    "status": BookRevision.Status.DRAFT,
                    "content_format": "html_chunks",
                    "total_bytes": 0,
                    "created_by": admin,
                },
            )

            if settings.AWS_S3_ENDPOINT_URL and settings.AWS_STORAGE_BUCKET_NAME:
                try:
                    ensure_bucket()
                    prefix = f"seed/realistic/{book.id}/{rev.id}"
                    manifest_body = json.dumps(
                        {
                            "format": "html_chunks",
                            "version": 1,
                            "chunks": [
                                {
                                    "id": "ch-1",
                                    "title": "Overview",
                                    "path": "content.html",
                                }
                            ],
                        },
                        separators=(",", ":"),
                    ).encode("utf-8")
                    html_body = (
                        f"<html><body><h1>{book.title}</h1><p>{book.summary}</p>"
                        "<p>This sample chapter is seeded for local development.</p></body></html>"
                    ).encode("utf-8")
                    mkey = f"{prefix}/manifest.json"
                    ckey = f"{prefix}/content.html"
                    mhash = put_bytes(mkey, manifest_body, "application/json")
                    chash = put_bytes(ckey, html_body, "text/html")
                    rev.manifest_object_key = mkey
                    rev.content_object_key = ckey
                    rev.manifest_sha256 = mhash
                    rev.content_sha256 = chash
                    rev.total_bytes = len(manifest_body) + len(html_body)
                    uploaded += 1
                except Exception as exc:
                    self.stderr.write(
                        self.style.WARNING(
                            f"seed_realistic_books: upload skipped for '{book.title}' ({exc})"
                        )
                    )

            rev.status = BookRevision.Status.PUBLISHED
            rev.created_by = rev.created_by or admin
            rev.save()
            book.published_revision = rev
            book.catalog_visibility = Book.Visibility.PUBLISHED
            book.save()

            self.stdout.write(f"[{idx}/{requested}] ready: {book.title}")

        self.stdout.write(
            self.style.SUCCESS(
                "seed_realistic_books: complete "
                f"(requested={requested}, created={created}, with_package={uploaded})"
            )
        )
