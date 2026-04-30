from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.catalog.models import Book
from apps.study.models import ReminderPreference


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
