from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.catalog.models import Book
from apps.payments.enums import PaymentMethod, TransactionStatus
from apps.payments.models import PaymentTransaction
from apps.study.models import ReaderEvent, ReminderPreference, UserReadingProgress


class StudyApiTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(email="reader@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.book = Book.objects.create(
            title="Book A",
            summary="Summary",
            author_compiler="Author",
            catalog_visibility=Book.Visibility.PUBLISHED,
        )

    def test_create_bookmark(self):
        response = self.client.post(
            "/v1/study/bookmarks",
            {
                "book": str(self.book.id),
                "chapter_key": "chapter-1",
                "page_number": 2,
                "label": "Saved",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        list_res = self.client.get("/v1/study/bookmarks")
        self.assertEqual(list_res.status_code, 200)
        self.assertEqual(len(list_res.data["items"]), 1)

    def test_reminder_preference_upsert(self):
        get_response = self.client.get("/v1/study/reminder-preference")
        self.assertEqual(get_response.status_code, 200)
        self.assertTrue(ReminderPreference.objects.filter(user=self.user).exists())
        put_response = self.client.put(
            "/v1/study/reminder-preference",
            {"enabled": True, "hour_utc": 7, "minute_utc": 30},
            format="json",
        )
        self.assertEqual(put_response.status_code, 200)
        pref = ReminderPreference.objects.get(user=self.user)
        self.assertTrue(pref.enabled)
        self.assertEqual(pref.hour_utc, 7)


class BookReviewGateTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(
            email="reviewer@example.com", password="pw123456"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.free = Book.objects.create(
            title="Free Book",
            catalog_visibility=Book.Visibility.PUBLISHED,
        )
        self.premium = Book.objects.create(
            title="Premium Book",
            catalog_visibility=Book.Visibility.PUBLISHED,
            is_premium=True,
            price=Decimal("50.00"),
        )

    def _post(self, book, body="Great"):
        return self.client.post(
            "/v1/study/reviews",
            {"book": str(book.id), "rating": 5, "body": body},
            format="json",
        )

    def _start(self, book):
        UserReadingProgress.objects.create(
            user=self.user, book=book, chapter_key="ch-1", progress_percent=5
        )

    def _purchase(self, book):
        PaymentTransaction.objects.create(
            user=self.user,
            book=book,
            amount=book.price,
            payment_method=PaymentMethod.BANK_TRANSFER,
            status=TransactionStatus.COMPLETED,
        )

    def test_free_book_requires_start(self):
        res = self._post(self.free)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data["error"]["code"], "REVIEW_REQUIRES_READING")

    def test_free_book_after_start(self):
        self._start(self.free)
        res = self._post(self.free)
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["rating"], 5)

    def test_free_book_after_reader_event(self):
        ReaderEvent.objects.create(
            user=self.user, book=self.free, event_name="chapter_open"
        )
        res = self._post(self.free)
        self.assertEqual(res.status_code, 201)

    def test_premium_requires_purchase(self):
        res = self._post(self.premium)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data["error"]["code"], "REVIEW_REQUIRES_PURCHASE")

    def test_premium_purchased_but_not_started(self):
        self._purchase(self.premium)
        res = self._post(self.premium)
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data["error"]["code"], "REVIEW_REQUIRES_READING")

    def test_premium_purchased_and_started(self):
        self._purchase(self.premium)
        self._start(self.premium)
        res = self._post(self.premium)
        self.assertEqual(res.status_code, 201)

    def test_existing_review_can_be_updated_without_progress(self):
        self._start(self.free)
        first = self._post(self.free, body="First")
        self.assertEqual(first.status_code, 201)
        UserReadingProgress.objects.filter(user=self.user, book=self.free).delete()
        ReaderEvent.objects.filter(user=self.user, book=self.free).delete()
        again = self._post(self.free, body="Updated")
        self.assertEqual(again.status_code, 201)
        self.assertEqual(again.data["body"], "Updated")
