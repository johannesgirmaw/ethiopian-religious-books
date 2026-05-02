from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase, override_settings
from rest_framework.test import APIClient

from apps.catalog.models import Book
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
