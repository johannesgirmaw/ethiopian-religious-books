from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase, override_settings
from rest_framework.test import APIClient

from apps.catalog.models import (
    BibleVerse,
    Book,
    BookChapter,
    BookPage,
    BookRevision,
)
from apps.catalog.publishing import (
    normalize_chapters_draft,
    publish_book,
    revision_chapters_draft_from_db,
    sync_book_chapters_draft_from_revision,
    validate_bible_draft,
)
from apps.catalog.search_index import rebuild_revision_index
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.storage_s3 import dev_presign_endpoint_from_request


class DevPresignOriginTests(TestCase):
    def test_ignored_when_debug_false(self):
        rf = RequestFactory()
        req = rf.get("/", HTTP_X_DEV_S3_ORIGIN="http://192.168.1.5:19000")
        with override_settings(DEBUG=False):
            self.assertIsNone(dev_presign_endpoint_from_request(req))

    @override_settings(DEBUG=True)
    def test_accepts_private_lan(self):
        rf = RequestFactory()
        req = rf.get("/", HTTP_X_DEV_S3_ORIGIN="http://192.168.1.5:19000")
        self.assertEqual(
            dev_presign_endpoint_from_request(req),
            "http://192.168.1.5:19000",
        )

    @override_settings(DEBUG=True)
    def test_localhost_normalized(self):
        rf = RequestFactory()
        req = rf.get("/", HTTP_X_DEV_S3_ORIGIN="http://localhost:19000")
        self.assertEqual(
            dev_presign_endpoint_from_request(req),
            "http://127.0.0.1:19000",
        )

    @override_settings(DEBUG=True)
    def test_rejects_public_ip(self):
        rf = RequestFactory()
        req = rf.get("/", HTTP_X_DEV_S3_ORIGIN="http://8.8.8.8:19000")
        self.assertIsNone(dev_presign_endpoint_from_request(req))

    @override_settings(DEBUG=True)
    def test_rejects_missing_port(self):
        rf = RequestFactory()
        req = rf.get("/", HTTP_X_DEV_S3_ORIGIN="http://192.168.1.5")
        self.assertIsNone(dev_presign_endpoint_from_request(req))


class SearchNormalizationTests(TestCase):
    def test_variant_normalization(self):
        self.assertEqual(normalize_search_text("ሐሌሉያ"), normalize_search_text("ሀሌሉያ"))

    def test_book_search_field_is_populated(self):
        book = Book.objects.create(
            title="ጸሎተ ሃይማኖት",
            subtitle="",
            summary="Prayer text",
            author_compiler="Test",
        )
        self.assertTrue(book.search_text_normalized)
        self.assertIn("ፀሎተ ሀይማኖት", book.search_text_normalized)


class CatalogSearchApiTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(email="reader@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_books_query_matches_summary(self):
        Book.objects.create(
            title="Book A",
            summary="Ancient liturgy overview",
            author_compiler="Author",
            catalog_visibility=Book.Visibility.PUBLISHED,
        )
        response = self.client.get("/v1/books", {"q": "liturgy"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["items"]), 1)


class RevisionDraftSyncTests(TestCase):
    def test_builds_draft_from_chapters_and_pages(self):
        book = Book.objects.create(title="Book", chapters_draft=[])
        rev = BookRevision.objects.create(book=book, revision_number=1, status=BookRevision.Status.DRAFT)
        ch = BookChapter.objects.create(revision=rev, chapter_key="intro", title="Intro", ordinal=1)
        BookPage.objects.create(revision=rev, chapter=ch, page_number=2, page_title="Second", text_plain="<p>x</p>")
        draft = revision_chapters_draft_from_db(rev)
        self.assertEqual(len(draft), 1)
        self.assertEqual(draft[0]["chapter_key"], "intro")
        self.assertEqual(len(draft[0]["pages"]), 1)
        self.assertEqual(draft[0]["pages"][0]["page_number"], 2)
        self.assertEqual(draft[0]["pages"][0]["body"], "<p>x</p>")

    def test_orphan_pages_become_synthetic_chapter(self):
        book = Book.objects.create(title="Book", chapters_draft=[])
        rev = BookRevision.objects.create(book=book, revision_number=1, status=BookRevision.Status.DRAFT)
        BookPage.objects.create(revision=rev, chapter=None, page_number=1, page_title="Only", text_plain="a")
        draft = revision_chapters_draft_from_db(rev)
        self.assertEqual(len(draft), 1)
        self.assertTrue(str(draft[0]["chapter_key"]).startswith("misc-pages"))
        self.assertEqual(draft[0]["pages"][0]["body"], "a")


class BookContentLazyIndexTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(email="reader2@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    @override_settings(FEATURE_BOOK_CONTENT_INDEX=True)
    def test_content_endpoint_rebuilds_empty_index_from_chapters_draft(self):
        book = Book.objects.create(
            title="Indexed Book",
            chapters_draft=[
                {
                    "chapter_key": "ch1",
                    "title": "Chapter One",
                    "pages": [{"page_number": 1, "title": "Page 1", "body": "Hello reader"}],
                }
            ],
            catalog_visibility=Book.Visibility.PUBLISHED,
        )
        rev = BookRevision.objects.create(
            book=book,
            revision_number=1,
            status=BookRevision.Status.PUBLISHED,
        )
        book.published_revision = rev
        book.save(update_fields=["published_revision"])

        response = self.client.get(f"/v1/books/{book.id}/content")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["chapters"]), 1)
        self.assertEqual(response.data["total_pages"], 1)
        self.assertEqual(response.data["chapters"][0]["pages"][0]["body"], "Hello reader")

    def test_rebuild_reads_fresh_chapters_draft_from_db(self):
        """Avoid stale revision.book cache after syncing draft from revision rows."""
        book = Book.objects.create(title="Sync Book", chapters_draft=[])
        rev = BookRevision.objects.create(book=book, revision_number=1, status=BookRevision.Status.DRAFT)
        ch = BookChapter.objects.create(revision=rev, chapter_key="k", title="T", ordinal=1)
        BookPage.objects.create(
            revision=rev,
            chapter=ch,
            page_number=1,
            page_title="P",
            text_plain="synced body",
        )
        rebuild_revision_index(rev)
        book.refresh_from_db()
        self.assertEqual(len(book.chapters_draft), 0)
        # Simulate publish_book: sync copies rows onto JSON (fresh DB state).
        self.assertTrue(sync_book_chapters_draft_from_revision(book, rev))
        book.refresh_from_db()
        self.assertTrue(book.chapters_draft)
        BookChapter.objects.filter(revision=rev).delete()
        BookPage.objects.filter(revision=rev).delete()
        rebuild_revision_index(rev)
        self.assertEqual(BookPage.objects.filter(revision=rev).count(), 1)
        self.assertEqual(
            BookPage.objects.get(revision=rev).text_plain,
            "synced body",
        )


class AuthorBookManagementTests(TestCase):
    """Authors manage only their own books via the admin book API."""

    def setUp(self):
        user_model = get_user_model()
        self.author = user_model.objects.create_user(
            email="author@example.com", password="pw123456", role="author"
        )
        self.other = user_model.objects.create_user(
            email="other@example.com", password="pw123456", role="author"
        )
        self.reader = user_model.objects.create_user(
            email="reader@example.com", password="pw123456"
        )
        self.client = APIClient()

    def test_author_can_create_book_attributed_to_self(self):
        self.client.force_authenticate(self.author)
        res = self.client.post(
            "/v1/admin/books", {"title": "My Title"}, format="json"
        )
        self.assertEqual(res.status_code, 201, res.data)
        book = Book.objects.get(title="My Title")
        self.assertEqual(book.created_by_id, self.author.id)
        # Auto-attributed so revenue/commission accrue to the author.
        self.assertEqual(book.author_id, self.author.id)

    def test_author_list_is_scoped_to_own_books(self):
        Book.objects.create(title="Mine", created_by=self.author, author=self.author)
        Book.objects.create(title="Theirs", created_by=self.other, author=self.other)
        self.client.force_authenticate(self.author)
        res = self.client.get("/v1/admin/books")
        titles = {b["title"] for b in res.data["items"]}
        self.assertIn("Mine", titles)
        self.assertNotIn("Theirs", titles)

    def test_author_cannot_view_others_book(self):
        book = Book.objects.create(
            title="Theirs", created_by=self.other, author=self.other
        )
        self.client.force_authenticate(self.author)
        res = self.client.get(f"/v1/admin/books/{book.id}")
        self.assertEqual(res.status_code, 403)

    def test_author_can_edit_own_book(self):
        book = Book.objects.create(
            title="Mine", created_by=self.author, author=self.author
        )
        self.client.force_authenticate(self.author)
        res = self.client.patch(
            f"/v1/admin/books/{book.id}", {"price": "12.00"}, format="json"
        )
        self.assertEqual(res.status_code, 200, res.data)

    def test_reader_cannot_access_admin_books(self):
        self.client.force_authenticate(self.reader)
        self.assertEqual(self.client.get("/v1/admin/books").status_code, 403)
        self.assertEqual(
            self.client.post("/v1/admin/books", {"title": "X"}, format="json").status_code,
            403,
        )


class NormalizeChaptersDraftTests(TestCase):
    def test_assigns_chapter_keys_and_global_page_numbers(self):
        normalized = normalize_chapters_draft(
            [
                {
                    "title": "Introduction",
                    "pages": [
                        {"title": "Opening", "body": "A"},
                        {"title": "Context", "body": "B"},
                    ],
                },
                {
                    "title": "Chapter Two",
                    "pages": [{"title": "Start", "body": "C"}],
                },
            ]
        )
        self.assertEqual(normalized[0]["chapter_key"], "introduction")
        self.assertEqual(normalized[1]["chapter_key"], "chapter-two")
        self.assertEqual(
            [page["page_number"] for page in normalized[0]["pages"]],
            [1, 2],
        )
        self.assertEqual(normalized[1]["pages"][0]["page_number"], 3)

    def test_ignores_client_supplied_keys_and_numbers(self):
        normalized = normalize_chapters_draft(
            [
                {
                    "chapter_key": "custom-key",
                    "title": "First",
                    "pages": [
                        {"page_number": 99, "title": "One", "body": "x"},
                    ],
                },
                {
                    "chapter_key": "other",
                    "title": "Second",
                    "pages": [
                        {"page_number": 1, "title": "Two", "body": "y"},
                    ],
                },
            ]
        )
        self.assertEqual(normalized[0]["chapter_key"], "first")
        self.assertEqual(normalized[1]["chapter_key"], "second")
        self.assertEqual(normalized[0]["pages"][0]["page_number"], 1)
        self.assertEqual(normalized[1]["pages"][0]["page_number"], 2)


class PublishBibleBookTests(TestCase):
    """Bible books publish on verse content, skipping page/chapter validation."""

    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(
            email="publisher@example.com", password="pw123456", role="author"
        )

    def _bible_book(self, *, with_verse: bool) -> Book:
        # Bible books carry no chapters_draft — content lives in BibleVerse rows.
        book = Book.objects.create(title="Bible Book", is_bible=True, chapters_draft=[])
        rev = BookRevision.objects.create(
            book=book, revision_number=1, status=BookRevision.Status.DRAFT
        )
        if with_verse:
            BibleVerse.objects.create(
                revision=rev,
                book=book,
                chapter=1,
                verse=1,
                verse_seq=1,
                text_plain="In the beginning",
            )
        return book

    def test_publish_bible_book_with_verses_succeeds(self):
        book = self._bible_book(with_verse=True)
        outcome = publish_book(book, self.user)
        self.assertTrue(outcome.ok)
        book.refresh_from_db()
        self.assertEqual(book.catalog_visibility, Book.Visibility.PUBLISHED)

    def test_publish_bible_book_without_verses_is_rejected(self):
        book = self._bible_book(with_verse=False)
        outcome = publish_book(book, self.user)
        self.assertFalse(outcome.ok)
        self.assertEqual(outcome.status_code, 400)
        self.assertEqual(outcome.error["error"]["code"], "INVALID_DRAFT")
        book.refresh_from_db()
        self.assertEqual(book.catalog_visibility, Book.Visibility.HIDDEN)

    def test_validate_bible_draft_reports_verse_stats(self):
        book = self._bible_book(with_verse=True)
        result = validate_bible_draft(book)
        self.assertTrue(result["ok"])
        self.assertEqual(result["warnings"], [])
        self.assertEqual(result["stats"]["verses"], 1)
        self.assertEqual(result["stats"]["chapters"], 1)

    def test_publish_non_bible_book_without_pages_still_rejected(self):
        # Regression: page-based books keep the chapters/pages requirement.
        book = Book.objects.create(title="Empty Book", chapters_draft=[])
        outcome = publish_book(book, self.user)
        self.assertFalse(outcome.ok)
        self.assertEqual(outcome.error["error"]["code"], "INVALID_DRAFT")
