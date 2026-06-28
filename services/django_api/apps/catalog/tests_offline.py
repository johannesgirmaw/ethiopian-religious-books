"""Tests for encrypted-offline-reading support: device registration, the offline
license (lease) endpoint, and the entitlement gate on downloads."""

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.models import UserDevice
from apps.catalog.licensing import issue_license, verify_license
from apps.catalog.models import Book, BookRevision
from apps.payments.enums import PaymentMethod, TransactionStatus
from apps.payments.models import PaymentTransaction

User = get_user_model()


def _published_book(*, price="0.00", is_premium=False, title="Book"):
    book = Book.objects.create(
        title=title,
        chapters_draft=[],
        catalog_visibility=Book.Visibility.PUBLISHED,
        is_premium=is_premium,
        price=Decimal(price),
    )
    rev = BookRevision.objects.create(
        book=book,
        revision_number=1,
        status=BookRevision.Status.PUBLISHED,
    )
    book.published_revision = rev
    book.save(update_fields=["published_revision"])
    return book, rev


def _complete_purchase(user, book):
    return PaymentTransaction.objects.create(
        user=user,
        book=book,
        currency="USD",
        amount=Decimal("5.00"),
        payment_method=PaymentMethod.BANK_TRANSFER,
        status=TransactionStatus.COMPLETED,
    )


class OfflineLicenseTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="r@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_free_book_issues_license(self):
        book, rev = _published_book(price="0.00")
        res = self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev1"})
        self.assertEqual(res.status_code, 200)
        token = res.data["license"]["token"]
        claims = verify_license(token)
        self.assertIsNotNone(claims)
        self.assertEqual(claims["book"], str(book.id))
        self.assertEqual(claims["rev"], str(rev.id))
        self.assertEqual(claims["device"], "dev1")

    def test_paid_book_blocked_without_purchase(self):
        book, _ = _published_book(price="5.00", is_premium=True)
        res = self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev1"})
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data["error"]["code"], "NOT_ENTITLED")

    def test_paid_book_allowed_after_purchase(self):
        book, _ = _published_book(price="5.00", is_premium=True)
        _complete_purchase(self.user, book)
        res = self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev1"})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data["license"]["token"])

    def test_license_records_offline_download(self):
        from apps.catalog.models import OfflineDownload

        book, _ = _published_book(price="0.00")
        self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev9"})
        row = OfflineDownload.objects.get(user=self.user, book=book, device_id="dev9")
        self.assertEqual(row.renew_count, 0)
        self.assertIsNotNone(row.license_expires_at)
        # Re-issuing (renewal) updates the same row and bumps the counter.
        self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev9"})
        row.refresh_from_db()
        self.assertEqual(row.renew_count, 1)
        self.assertEqual(
            OfflineDownload.objects.filter(user=self.user, book=book).count(), 1
        )

    def test_renewal_denied_after_revoke(self):
        book, _ = _published_book(price="5.00", is_premium=True)
        txn = _complete_purchase(self.user, book)
        ok = self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev1"})
        self.assertEqual(ok.status_code, 200)
        # Refund / revoke the purchase -> next renewal must fail.
        txn.status = TransactionStatus.REJECTED
        txn.save(update_fields=["status"])
        denied = self.client.post(f"/v1/books/{book.id}/license", {"device_id": "dev1"})
        self.assertEqual(denied.status_code, 403)


class DownloadEntitlementGateTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="d@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    @override_settings(FEATURE_BOOK_CONTENT_INDEX=True)
    def test_download_blocked_without_entitlement(self):
        book, _ = _published_book(price="5.00", is_premium=True)
        res = self.client.get(f"/v1/books/{book.id}/download")
        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data["error"]["code"], "NOT_ENTITLED")


class DeviceRegisterTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="dev@example.com", password="pw123456")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_register_is_idempotent_and_rotates_key(self):
        first = self.client.post(
            "/v1/devices/register",
            {"device_id": "abc", "public_key": "k1", "platform": "android"},
        )
        self.assertEqual(first.status_code, 200)
        second = self.client.post(
            "/v1/devices/register",
            {"device_id": "abc", "public_key": "k2", "platform": "android"},
        )
        self.assertEqual(second.status_code, 200)
        self.assertEqual(UserDevice.objects.filter(user=self.user, device_id="abc").count(), 1)
        self.assertEqual(
            UserDevice.objects.get(user=self.user, device_id="abc").public_key, "k2"
        )

    def test_register_requires_device_id(self):
        res = self.client.post("/v1/devices/register", {"platform": "android"})
        self.assertEqual(res.status_code, 400)


class LicenseTokenUnitTests(TestCase):
    def test_issue_then_verify_roundtrip(self):
        payload = issue_license(
            user_id="u1", book_id="b1", revision_id="r1", device_id="d1"
        )
        claims = verify_license(payload["token"])
        self.assertIsNotNone(claims)
        self.assertEqual(claims["sub"], "u1")
        self.assertEqual(claims["typ"], "offline-license")

    def test_garbage_token_rejected(self):
        self.assertIsNone(verify_license("not-a-jwt"))
        self.assertIsNone(verify_license(""))
