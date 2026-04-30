from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.catalog.models import Book
from apps.catalog.search_normalization import normalize_search_text


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
