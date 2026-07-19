"""
Populate Django admin datasets with realistic Ethiopian religious-catalog examples.

Creates (idempotently via get-or-create keyed fields):
  - 10 Tags
  - 10 published Books (+ BookRevision revision 1; optional MinIO payload)
  - 10 BookTag links (paired 1:1 with the seeded books)
  - 10 LegalDocuments (distinct doc_type/version rows)
  - 10 reader Users (@demo.localhost)
  - 10 LegalAcceptance rows (demo users accepting the new docs)

Run after migrations:  python manage.py seed_admin_demo
"""

import json
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.catalog.models import Book, BookRevision, BookTag, Tag
from apps.catalog.storage_s3 import ensure_bucket, put_bytes
from apps.legal.models import LegalAcceptance, LegalDocument

User = get_user_model()

TAG_ROWS = [
    {"slug": "ethiopian-liturgy", "label": "Ethiopian liturgy"},
    {"slug": "hymnody", "label": "Hymns & chant (Digua / Miriam)"},
    {"slug": "martyrology", "label": "Martyrology & commemorations"},
    {"slug": "fasting-calendars", "label": "Fasting & liturgical calendars"},
    {"slug": "monastic-instruction", "label": "Monastic discipline & manuals"},
    {"slug": "apocrypha", "label": "Apocryphal & pseudepigraphical texts"},
    {"slug": "patristics", "label": "Commentary & patristic tradition"},
    {"slug": "hagiography", "label": "Hagiography"},
    {"slug": "penitential-prayer", "label": "Penitential & intercessory prayers"},
    {"slug": "pilgrimage", "label": "Pilgrimage & shrines tradition"},
]


BOOK_ROWS = [
    {
        "title": "Digua: Great hymnody selections",
        "subtitle": "Introductory hymns for Ethiopian Orthodox worship study",
        "summary": "A structured introduction to melodic cycles and hymn forms used seasonally "
        "within traditional worship and seminary curricula.",
        "author": "Ethiopian liturgical hymnody tradition",
        "language": "gez",
        "tags": ["Ethi", "Liturgy", "Hymns"],
    },
    {
        "title": "Zema Mariam cycle (selected antiphons)",
        "subtitle": "Marian zema excerpts for devotional use",
        "summary": "Curated antiphonal material centered on praises of Saint Mary drawn from parish "
        "chorister practice notebooks.",
        "author": "Parish choral tradition",
        "language": "gez",
        "tags": ["Marian", "Chant", "Devotion"],
    },
    {
        "title": "Metsehafe Teawas’e Degu'a",
        "subtitle": "Book of the Fast of Niniveh & Great Lent introductions",
        "summary": "Readings that frame repentance, Jonah typology, and communal fasting sermons.",
        "author": "Metropolitan sermon compilation",
        "language": "am",
        "tags": ["Fast", "Lent", "Homily"],
    },
    {
        "title": "Haimanote Abbat (student catechism notes)",
        "subtitle": "Nicene summaries for catechumen classes",
        "summary": "Concise Creed and sacramental exposition used in Ethiopian Sunday schools "
        "and adult instruction.",
        "author": "Sunday school authors’ circle",
        "language": "am",
        "tags": ["Catechesis", "Faith", "Teaching"],
    },
    {
        "title": "Girgña (night vigil) psalms & refrains",
        "subtitle": "Selected psalmody patterns for vigil services",
        "summary": "Refrains, psalms, and intercessions typical of nighttime vigils preceding major feasts.",
        "author": "Monastery psalm codex tradition",
        "language": "gez",
        "tags": ["Vigils", "Psalms", "Monastic"],
    },
    {
        "title": "Liqawént: treasury of litanies",
        "subtitle": "Short supplications compiled for clergy readers",
        "summary": "A practical reader of litanies for healing, saints, rulers, pilgrims, "
        "and the departed.",
        "author": "Clergy reader’s treasury",
        "language": "am",
        "tags": ["Prayer", "Litany", "Clergy"],
    },
    {
        "title": "Metsehafe Berhan excerpts",
        "subtitle": "Gospel illumination & homiletical introductions",
        "summary": "Expository notes linking Gospel pericopes to Ethiopian liturgical year themes.",
        "author": "Monastic scripture school",
        "language": "am",
        "tags": ["Gospel", "Homily", "Lectionary"],
    },
    {
        "title": "Ordination handbook (deacon & priest)",
        "subtitle": "Rites abbreviated for archival study editions",
        "summary": "Choreography, vesting, procession order, and deacon cantor cues for foundational orders.",
        "author": "Chancery ceremonial commission",
        "language": "am",
        "tags": ["Ordination", "Rites", "Church"],
    },
    {
        "title": "Book of Gad the Seer (study extracts)",
        "subtitle": "Narratives on kingship warnings and repentance",
        "summary": "Classroom extracts highlighting justice, ancestral warning, "
        "and prophetic consolation themes.",
        "author": "Biblical-studies anthology",
        "language": "am",
        "tags": ["Narrative", "Monarchy", "Study"],
    },
    {
        "title": "Tigray apostles’ miracles collection",
        "subtitle": "Local hagiographical notebook transcriptions",
        "summary": "Miracle cycles associated with apostles and evangelists circulated in Tigray parishes.",
        "author": "Parish folklore commission",
        "language": "ti",
        "tags": ["Hagiography", "Parish", "Miracles"],
    },
]

LEGAL_ROWS = [
    {"doc_type": "terms_of_service", "version": 2, "suffix": "terms-of-service"},
    {"doc_type": "terms_of_service", "version": 3, "suffix": "terms-of-service"},
    {"doc_type": "privacy_notice", "version": 2, "suffix": "privacy-notice"},
    {"doc_type": "privacy_notice", "version": 3, "suffix": "privacy-notice"},
    {"doc_type": "cookie_policy", "version": 1, "suffix": "cookie-policy"},
    {"doc_type": "community_guidelines", "version": 1, "suffix": "community-guidelines"},
    {"doc_type": "data_processing_agreement", "version": 1, "suffix": "data-processing"},
    {"doc_type": "accessibility_statement", "version": 1, "suffix": "accessibility"},
    {"doc_type": "children_privacy_addendum", "version": 1, "suffix": "children-privacy"},
    {"doc_type": "open_source_licenses", "version": 1, "suffix": "open-source-licenses"},
]

USER_ROWS = [
    {"email": "henok.teferra@demo.localhost", "display_name": "Henok Teferra", "preferred": "am"},
    {"email": "kidist.mamo@demo.localhost", "display_name": "Kidist Mamo", "preferred": "am"},
    {"email": "yared.solomon@demo.localhost", "display_name": "Yared Solomon", "preferred": "en"},
    {"email": "selamawit.negash@demo.localhost", "display_name": "Selamawit Negash", "preferred": "am"},
    {"email": "dabtar.fasil@demo.localhost", "display_name": "Däbtär Fasil", "preferred": "am"},
    {"email": "meron.alemayehu@demo.localhost", "display_name": "Meron Alemayehu", "preferred": "en"},
    {"email": "kirubel.daniel@demo.localhost", "display_name": "Kirubel Daniel", "preferred": "am"},
    {"email": "bethel.bekele@demo.localhost", "display_name": "Bethel Bekele", "preferred": "en"},
    {"email": "natnael.tekle@demo.localhost", "display_name": "Natnael Tekle", "preferred": "am"},
    {"email": "mahlet.girmay@demo.localhost", "display_name": "Mahlet Girmay", "preferred": "am"},
]


def _upload_revision_assets(book: Book, rev: BookRevision, stderr_writer, ok_style) -> bool:
    uploaded = False
    if settings.AWS_S3_ENDPOINT_URL and settings.AWS_STORAGE_BUCKET_NAME:
        try:
            ensure_bucket()
            prefix = f"seed/demo/{book.id}/{rev.id}"
            manifest_body = json.dumps(
                {
                    "format": "html_chunks",
                    "version": 1,
                    "chunks": [
                        {"id": "demo-1", "title": "Opening", "path": "content.html"},
                    ],
                },
                separators=(",", ":"),
            ).encode("utf-8")
            html_body = (
                f"<html><body><h1>{book.title}</h1>"
                f"<section><p>{book.summary}</p>"
                "<p>Seeded excerpt for ፈለገ መጻሕፍት admin/catalog demos.</p></section>"
                "</body></html>"
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
            uploaded = True
        except Exception as exc:
            stderr_writer(ok_style.WARNING(f"MinIO skipped for '{book.title}': {exc}"))
    return uploaded


class Command(BaseCommand):
    help = "Seed demo rows for Django admin (~10 Tags, Books, Legal docs, Users, LegalAcceptances)."

    def handle(self, *args, **options):
        now = timezone.now()
        base_legal_url = "https://example.com/legal/"
        pwd = "DemoReaderPass10"

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
        if not admin.has_usable_password():
            admin.set_password("adminadminadmin")
        admin.save()

        tags: list[Tag] = []
        for row in TAG_ROWS:
            t, _ = Tag.objects.get_or_create(
                slug=row["slug"],
                defaults={"label": row["label"]},
            )
            if t.label != row["label"]:
                t.label = row["label"]
                t.save(update_fields=("label",))
            tags.append(t)

        demo_books: list[Book] = []
        uploads = 0
        for data in BOOK_ROWS:
            book, _ = Book.objects.get_or_create(
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

            uploads += int(
                _upload_revision_assets(book, rev, self.stderr.write, self.style)
            )

            rev.status = BookRevision.Status.PUBLISHED
            rev.created_by = rev.created_by or admin
            rev.save()
            book.published_revision = rev
            book.catalog_visibility = Book.Visibility.PUBLISHED
            book.save()
            demo_books.append(book)

        bt_count = 0
        for i, book in enumerate(demo_books):
            bt, created = BookTag.objects.get_or_create(book=book, tag=tags[i % len(tags)])
            bt_count += int(created)

        legal_objs: list[LegalDocument] = []
        for idx, row in enumerate(LEGAL_ROWS):
            effective = now - timedelta(days=30 * (idx + 1))
            url = f"{base_legal_url}{row['suffix']}-v{row['version']}.html"
            doc, _ = LegalDocument.objects.update_or_create(
                doc_type=row["doc_type"],
                version=row["version"],
                defaults={
                    "content_url": url,
                    "effective_at": effective,
                },
            )
            legal_objs.append(doc)

        demo_users: list[User] = []
        for row in USER_ROWS:
            u, created = User.objects.get_or_create(
                email=row["email"],
                defaults={
                    "display_name": row["display_name"],
                    "role": "reader",
                    "preferred_ui_language": row["preferred"],
                },
            )
            u.role = "reader"
            u.display_name = row["display_name"]
            u.preferred_ui_language = row["preferred"]
            u.save()
            if created or not u.has_usable_password():
                u.set_password(pwd)
                u.save()
            demo_users.append(u)

        acc_count = 0
        accept_time = now - timedelta(hours=2)
        for i, doc in enumerate(legal_objs):
            u = demo_users[i % len(demo_users)]
            acc, created = LegalAcceptance.objects.get_or_create(
                user=u,
                legal_document=doc,
                defaults={"accepted_at": accept_time + timedelta(minutes=i)},
            )
            acc_count += int(created)

        self.stdout.write(self.style.SUCCESS("seed_admin_demo: complete"))
        self.stdout.write(f"  tags={len(tags)}")
        self.stdout.write(f"  books+revs={len(demo_books)}, minio_manifests={uploads}")
        self.stdout.write(f"  book_tags created (new pairs)={bt_count}")
        self.stdout.write(f"  legal_documents={len(legal_objs)}")
        self.stdout.write(f"  demo_users={len(demo_users)} (password: {pwd})")
        self.stdout.write(f"  legal_acceptances created={acc_count}")
