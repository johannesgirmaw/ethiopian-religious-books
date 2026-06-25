import tempfile
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.catalog.models import Book
from apps.payments.crypto import decrypt, encrypt
from apps.payments.enums import PaymentMethod, TransactionStatus
from apps.payments.models import (
    AuthorCommission,
    Bank,
    GatewayCredential,
    PaymentTransaction,
    PlatformSettings,
    RevenueLedger,
)
from apps.payments.services import (
    compute_amounts,
    create_revenue_ledger,
    final_price,
    resolve_commission_percent,
)

User = get_user_model()

PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 64
PDF_BYTES = b"%PDF-1.4\n" + b"0" * 64

_MEDIA = tempfile.mkdtemp(prefix="payments-test-media-")


def make_user(email="reader@example.com", role="reader", **extra):
    return User.objects.create_user(email=email, password="pw123456", role=role, **extra)


def make_admin(email="admin@example.com"):
    return User.objects.create_user(
        email=email, password="pw123456", role="admin", is_staff=True, is_superuser=True
    )


def make_book(price="100.00", **extra):
    return Book.objects.create(title="Paid Book", price=Decimal(price), **extra)


# --------------------------------------------------------------------------
# Pure domain logic
# --------------------------------------------------------------------------
class CommissionResolutionTests(TestCase):
    def setUp(self):
        self.author = make_user("author@example.com", role="author")
        self.ps = PlatformSettings.get_solo()
        self.ps.default_commission_percent = Decimal("10.00")
        self.ps.save()

    def test_platform_default_when_nothing_set(self):
        book = make_book(author=self.author)
        self.assertEqual(resolve_commission_percent(book), Decimal("10.00"))

    def test_author_override_beats_platform(self):
        AuthorCommission.objects.create(
            author=self.author, commission_percent=Decimal("12.00")
        )
        book = make_book(author=self.author)
        self.assertEqual(resolve_commission_percent(book), Decimal("12.00"))

    def test_book_override_beats_author_and_platform(self):
        AuthorCommission.objects.create(
            author=self.author, commission_percent=Decimal("12.00")
        )
        book = make_book(author=self.author, commission_percent=Decimal("15.00"))
        self.assertEqual(resolve_commission_percent(book), Decimal("15.00"))

    def test_book_override_ignored_when_disallowed(self):
        self.ps.allow_book_override = False
        self.ps.save()
        AuthorCommission.objects.create(
            author=self.author, commission_percent=Decimal("12.00")
        )
        book = make_book(author=self.author, commission_percent=Decimal("15.00"))
        # Falls back to the author override.
        self.assertEqual(resolve_commission_percent(book), Decimal("12.00"))

    def test_author_override_ignored_when_disallowed(self):
        self.ps.allow_author_override = False
        self.ps.save()
        AuthorCommission.objects.create(
            author=self.author, commission_percent=Decimal("12.00")
        )
        book = make_book(author=self.author)
        self.assertEqual(resolve_commission_percent(book), Decimal("10.00"))


class PricingAndAmountsTests(TestCase):
    def test_final_price_prefers_sale_price(self):
        book = make_book(price="100.00", sale_price=Decimal("80.00"))
        self.assertEqual(final_price(book), Decimal("80.00"))

    def test_compute_amounts_splits_sale_and_commission(self):
        book = make_book(price="100.00", commission_percent=Decimal("10.00"))
        amounts = compute_amounts(book)
        self.assertEqual(amounts["sale_amount"], Decimal("100.00"))
        self.assertEqual(amounts["commission_amount"], Decimal("10.00"))
        self.assertEqual(amounts["author_amount"], Decimal("90.00"))

    def test_commission_rounds_to_cents(self):
        book = make_book(price="99.99", commission_percent=Decimal("12.50"))
        amounts = compute_amounts(book)
        # 99.99 * 12.5% = 12.49875 -> 12.50
        self.assertEqual(amounts["commission_amount"], Decimal("12.50"))
        self.assertEqual(amounts["author_amount"], Decimal("87.49"))


class RevenueLedgerTests(TestCase):
    def test_create_ledger_from_transaction_is_idempotent(self):
        author = make_user("a@example.com", role="author")
        buyer = make_user("b@example.com")
        book = make_book(author=author)
        txn = PaymentTransaction.objects.create(
            user=buyer,
            book=book,
            amount=Decimal("100.00"),
            commission_amount=Decimal("10.00"),
            payment_method=PaymentMethod.BANK_TRANSFER,
            currency="USD",
        )
        ledger = create_revenue_ledger(txn)
        again = create_revenue_ledger(txn)
        self.assertEqual(ledger.pk, again.pk)
        self.assertEqual(RevenueLedger.objects.count(), 1)
        self.assertEqual(ledger.sale_amount, Decimal("100.00"))
        self.assertEqual(ledger.commission_amount, Decimal("10.00"))
        self.assertEqual(ledger.author_amount, Decimal("90.00"))
        self.assertEqual(ledger.author_id, author.id)


class CryptoTests(TestCase):
    def test_round_trip(self):
        self.assertEqual(decrypt(encrypt("sk_live_secret")), "sk_live_secret")

    def test_empty(self):
        self.assertEqual(encrypt(""), "")
        self.assertEqual(decrypt(""), "")

    def test_garbage_token_returns_empty(self):
        self.assertEqual(decrypt("not-a-valid-token"), "")


# --------------------------------------------------------------------------
# API: manual payment flow
# --------------------------------------------------------------------------
@override_settings(MEDIA_ROOT=_MEDIA)
class ManualPaymentFlowTests(TestCase):
    def setUp(self):
        self.author = make_user("author@example.com", role="author")
        self.buyer = make_user("buyer@example.com")
        self.book = make_book(
            author=self.author, price="100.00", commission_percent=Decimal("10.00")
        )
        self.bank = Bank.objects.create(
            name="Test Bank", account_name="Platform", account_number="123"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.buyer)

    def _create_txn(self):
        res = self.client.post(
            "/v1/payments/transactions",
            {"book": str(self.book.id), "payment_method": "bank_transfer",
             "bank": str(self.bank.id)},
            format="json",
        )
        return res

    def test_methods_endpoint_reflects_settings(self):
        res = self.client.get("/v1/payments/methods")
        self.assertEqual(res.status_code, 200)
        self.assertIn("bank_transfer", res.data["methods"])
        self.assertNotIn("stripe", res.data["methods"])  # disabled by default

    def test_create_transaction_computes_amount(self):
        res = self._create_txn()
        self.assertEqual(res.status_code, 201)
        txn = res.data["transaction"]
        self.assertEqual(Decimal(txn["amount"]), Decimal("100.00"))
        self.assertEqual(Decimal(txn["commission_amount"]), Decimal("10.00"))
        self.assertEqual(txn["status"], TransactionStatus.PENDING)
        self.assertTrue(res.data["banks"])

    def test_submit_receipt_moves_to_review(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        receipt = SimpleUploadedFile("r.png", PNG_BYTES, content_type="image/png")
        res = self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": "REF-1", "receipt": receipt},
            format="multipart",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], TransactionStatus.ON_REVIEW)
        self.assertTrue(res.data["receipt_url"])

    def test_duplicate_reference_rejected(self):
        # First transaction submits REF-DUP.
        t1 = self._create_txn().data["transaction"]["id"]
        self.client.post(
            f"/v1/payments/transactions/{t1}/receipt",
            {"transaction_reference": "REF-DUP",
             "receipt": SimpleUploadedFile("r.png", PNG_BYTES, content_type="image/png")},
            format="multipart",
        )
        # Second transaction tries to reuse REF-DUP.
        t2 = self._create_txn().data["transaction"]["id"]
        res = self.client.post(
            f"/v1/payments/transactions/{t2}/receipt",
            {"transaction_reference": "REF-DUP",
             "receipt": SimpleUploadedFile("r.png", PNG_BYTES, content_type="image/png")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 409)
        self.assertEqual(res.data["error"]["code"], "DUPLICATE_REFERENCE")

    def test_pdf_receipt_accepted(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        res = self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": "REF-PDF",
             "receipt": SimpleUploadedFile("r.pdf", PDF_BYTES, content_type="application/pdf")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 200)

    def test_bad_file_type_rejected(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        res = self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": "REF-X",
             "receipt": SimpleUploadedFile("r.txt", b"hello", content_type="text/plain")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 400)

    def test_mismatched_magic_bytes_rejected(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        # .png extension but not actually a PNG.
        res = self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": "REF-Y",
             "receipt": SimpleUploadedFile("r.png", b"not really a png",
                                           content_type="image/png")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 400)

    def test_oversize_receipt_rejected(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        big = b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024 + 10)
        res = self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": "REF-BIG",
             "receipt": SimpleUploadedFile("r.png", big, content_type="image/png")},
            format="multipart",
        )
        self.assertEqual(res.status_code, 400)

    def _submit_receipt(self, txn_id, ref="REF-FILE"):
        return self.client.post(
            f"/v1/payments/transactions/{txn_id}/receipt",
            {"transaction_reference": ref,
             "receipt": SimpleUploadedFile("r.png", PNG_BYTES, content_type="image/png")},
            format="multipart",
        )

    def test_receipt_url_points_to_streaming_endpoint(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        res = self._submit_receipt(txn_id)
        self.assertTrue(res.data["receipt_url"].endswith(
            f"/v1/payments/transactions/{txn_id}/receipt-file"))

    def test_owner_can_fetch_receipt_bytes(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        self._submit_receipt(txn_id)
        res = self.client.get(f"/v1/payments/transactions/{txn_id}/receipt-file")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Type"], "image/png")
        self.assertEqual(b"".join(res.streaming_content) if res.streaming
                         else res.content, PNG_BYTES)

    def test_admin_can_fetch_receipt_bytes(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        self._submit_receipt(txn_id)
        admin = make_admin()
        self.client.force_authenticate(admin)
        res = self.client.get(f"/v1/payments/transactions/{txn_id}/receipt-file")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.content, PNG_BYTES)

    def test_other_user_cannot_fetch_receipt(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        self._submit_receipt(txn_id)
        self.client.force_authenticate(make_user("intruder@example.com"))
        res = self.client.get(f"/v1/payments/transactions/{txn_id}/receipt-file")
        self.assertEqual(res.status_code, 403)

    def test_receipt_file_404_when_none_uploaded(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        res = self.client.get(f"/v1/payments/transactions/{txn_id}/receipt-file")
        self.assertEqual(res.status_code, 404)

    def test_only_owner_sees_transaction(self):
        txn_id = self._create_txn().data["transaction"]["id"]
        other = make_user("other@example.com")
        self.client.force_authenticate(other)
        res = self.client.get(f"/v1/payments/transactions/{txn_id}")
        self.assertEqual(res.status_code, 404)


class OnlineGatewayInactiveTests(TestCase):
    def setUp(self):
        self.buyer = make_user("buyer@example.com")
        self.book = make_book(price="50.00")
        self.ps = PlatformSettings.get_solo()
        self.ps.stripe_enabled = True
        self.ps.save()
        self.client = APIClient()
        self.client.force_authenticate(self.buyer)

    def test_stripe_checkout_unavailable_without_credentials(self):
        res = self.client.post(
            "/v1/payments/transactions",
            {"book": str(self.book.id), "payment_method": "stripe"},
            format="json",
        )
        self.assertEqual(res.status_code, 503)
        self.assertEqual(res.data["error"]["code"], "GATEWAY_UNAVAILABLE")

    def test_disabled_method_rejected(self):
        res = self.client.post(
            "/v1/payments/transactions",
            {"book": str(self.book.id), "payment_method": "paypal"},
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data["error"]["code"], "METHOD_DISABLED")

    def test_webhook_returns_503_when_unconfigured(self):
        res = self.client.post("/v1/payments/webhooks/stripe", {}, format="json")
        self.assertEqual(res.status_code, 503)


# --------------------------------------------------------------------------
# API: admin
# --------------------------------------------------------------------------
@override_settings(MEDIA_ROOT=_MEDIA)
class AdminPaymentApiTests(TestCase):
    def setUp(self):
        self.admin = make_admin()
        self.author = make_user("author@example.com", role="author")
        self.buyer = make_user("buyer@example.com")
        self.book = make_book(
            author=self.author, price="100.00", commission_percent=Decimal("10.00")
        )
        self.client = APIClient()
        self.client.force_authenticate(self.admin)

    def _on_review_txn(self):
        txn = PaymentTransaction.objects.create(
            user=self.buyer,
            book=self.book,
            amount=Decimal("100.00"),
            commission_amount=Decimal("10.00"),
            payment_method=PaymentMethod.BANK_TRANSFER,
            currency="USD",
            transaction_reference="REF-A",
            status=TransactionStatus.ON_REVIEW,
        )
        return txn

    def test_non_admin_forbidden(self):
        self.client.force_authenticate(self.buyer)
        res = self.client.get("/v1/admin/payments/transactions")
        self.assertEqual(res.status_code, 403)

    def test_approve_completes_and_creates_ledger(self):
        txn = self._on_review_txn()
        res = self.client.post(f"/v1/admin/payments/transactions/{txn.id}/approve")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], TransactionStatus.COMPLETED)
        self.assertEqual(RevenueLedger.objects.filter(transaction=txn).count(), 1)
        ledger = RevenueLedger.objects.get(transaction=txn)
        self.assertEqual(ledger.author_amount, Decimal("90.00"))

    def test_reject_sets_status(self):
        txn = self._on_review_txn()
        res = self.client.post(
            f"/v1/admin/payments/transactions/{txn.id}/reject",
            {"note": "blurry receipt"}, format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], TransactionStatus.REJECTED)
        self.assertFalse(RevenueLedger.objects.filter(transaction=txn).exists())

    def test_cannot_approve_twice(self):
        txn = self._on_review_txn()
        self.client.post(f"/v1/admin/payments/transactions/{txn.id}/approve")
        res = self.client.post(f"/v1/admin/payments/transactions/{txn.id}/approve")
        self.assertEqual(res.status_code, 409)
        self.assertEqual(RevenueLedger.objects.filter(transaction=txn).count(), 1)

    def test_dashboard_totals(self):
        txn = self._on_review_txn()
        self.client.post(f"/v1/admin/payments/transactions/{txn.id}/approve")
        res = self.client.get("/v1/admin/payments/dashboard")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["completed_transactions"], 1)
        self.assertEqual(Decimal(res.data["gross_revenue"]), Decimal("100.00"))
        self.assertEqual(Decimal(res.data["platform_revenue"]), Decimal("10.00"))
        self.assertEqual(Decimal(res.data["author_revenue"]), Decimal("90.00"))

    def test_bank_crud(self):
        # Create
        res = self.client.post(
            "/v1/admin/payments/banks",
            {"name": "CBE", "account_name": "Platform", "account_number": "1000"},
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        bank_id = res.data["id"]
        # Update
        res = self.client.patch(
            f"/v1/admin/payments/banks/{bank_id}", {"is_active": False}, format="json"
        )
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["is_active"])
        # Delete
        res = self.client.delete(f"/v1/admin/payments/banks/{bank_id}")
        self.assertEqual(res.status_code, 204)
        self.assertFalse(Bank.objects.filter(id=bank_id).exists())

    def test_platform_settings_update(self):
        res = self.client.patch(
            "/v1/admin/payments/settings",
            {"default_commission_percent": "20.00", "stripe_enabled": True},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(Decimal(res.data["default_commission_percent"]), Decimal("20.00"))
        self.assertTrue(res.data["stripe_enabled"])

    def test_settings_rejects_out_of_range_commission(self):
        res = self.client.patch(
            "/v1/admin/payments/settings",
            {"default_commission_percent": "150"}, format="json",
        )
        self.assertEqual(res.status_code, 400)

    def test_author_commission_assign_and_remove(self):
        res = self.client.post(
            "/v1/admin/payments/author-commissions",
            {"author": str(self.author.id), "commission_percent": "13.00"},
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        cid = res.data["id"]
        # Re-assign updates in place (no duplicate).
        res = self.client.post(
            "/v1/admin/payments/author-commissions",
            {"author": str(self.author.id), "commission_percent": "14.00"},
            format="json",
        )
        self.assertEqual(AuthorCommission.objects.filter(author=self.author).count(), 1)
        # Remove override.
        res = self.client.delete(f"/v1/admin/payments/author-commissions/{cid}")
        self.assertEqual(res.status_code, 204)

    def test_gateway_credential_secret_is_encrypted_and_hidden(self):
        res = self.client.put(
            "/v1/admin/payments/credentials/stripe",
            {"public_key": "pk_test", "secret": "sk_test_123", "is_active": True},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertNotIn("secret", res.data)
        self.assertTrue(res.data["has_secret"])
        cred = GatewayCredential.objects.get(provider="stripe")
        self.assertNotIn("sk_test_123", cred.encrypted_secret)
        self.assertEqual(cred.secret(), "sk_test_123")


class AdminBookPricingApiTests(TestCase):
    """The admin book create/edit API must accept and round-trip pricing so a
    book can actually be sold; the public catalog must expose final_price."""

    def setUp(self):
        self.admin = make_admin()
        self.author = make_user("author@example.com", role="author")
        self.client = APIClient()
        self.client.force_authenticate(self.admin)

    def test_create_book_with_pricing(self):
        res = self.client.post(
            "/v1/admin/books",
            {
                "title": "Priced Book",
                "is_premium": True,
                "author": str(self.author.id),
                "currency": "USD",
                "price": "100.00",
                "sale_price": "80.00",
                "commission_percent": "15.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201, res.data)
        book = Book.objects.get(title="Priced Book")
        self.assertEqual(book.price, Decimal("100.00"))
        self.assertEqual(book.sale_price, Decimal("80.00"))
        self.assertEqual(book.commission_percent, Decimal("15.00"))
        self.assertEqual(book.author_id, self.author.id)

    def test_create_rejects_bad_commission(self):
        res = self.client.post(
            "/v1/admin/books",
            {"title": "Bad", "price": "10", "commission_percent": "150"},
            format="json",
        )
        self.assertEqual(res.status_code, 400)

    def test_patch_updates_pricing(self):
        book = make_book(price="50.00", created_by=self.admin)
        res = self.client.patch(
            f"/v1/admin/books/{book.id}",
            {"price": "70.00", "sale_price": "60.00", "currency": "ETB"},
            format="json",
        )
        self.assertEqual(res.status_code, 200, res.data)
        book.refresh_from_db()
        self.assertEqual(book.price, Decimal("70.00"))
        self.assertEqual(book.sale_price, Decimal("60.00"))
        self.assertEqual(book.currency, "ETB")

    def test_public_catalog_exposes_final_price(self):
        book = make_book(
            price="100.00",
            sale_price=Decimal("80.00"),
            catalog_visibility=Book.Visibility.PUBLISHED,
        )
        self.client.force_authenticate(make_user("reader2@example.com"))
        res = self.client.get(f"/v1/books/{book.id}")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["final_price"], "80.00")
        self.assertEqual(res.data["price"], "100.00")


class EntitlementsApiTests(TestCase):
    def setUp(self):
        self.buyer = make_user("buyer@example.com")
        self.book = make_book(price="100.00")
        self.client = APIClient()
        self.client.force_authenticate(self.buyer)

    def _txn(self, status):
        return PaymentTransaction.objects.create(
            user=self.buyer, book=self.book, amount=Decimal("100.00"),
            commission_amount=Decimal("10.00"),
            payment_method=PaymentMethod.BANK_TRANSFER, currency="USD",
            status=status,
        )

    def test_completed_purchase_grants_entitlement(self):
        self._txn(TransactionStatus.COMPLETED)
        res = self.client.get("/v1/payments/entitlements")
        self.assertEqual(res.status_code, 200)
        self.assertIn(str(self.book.id), res.data["book_ids"])

    def test_pending_purchase_does_not_grant_entitlement(self):
        self._txn(TransactionStatus.ON_REVIEW)
        res = self.client.get("/v1/payments/entitlements")
        self.assertEqual(res.data["book_ids"], [])

    def test_entitlements_are_per_user(self):
        self._txn(TransactionStatus.COMPLETED)
        self.client.force_authenticate(make_user("other@example.com"))
        res = self.client.get("/v1/payments/entitlements")
        self.assertEqual(res.data["book_ids"], [])


class AuthorDashboardApiTests(TestCase):
    def setUp(self):
        self.author = make_user("author@example.com", role="author")
        self.buyer = make_user("buyer@example.com")
        self.book = make_book(author=self.author, price="100.00",
                              commission_percent=Decimal("10.00"))
        self.client = APIClient()

    def test_author_sees_earnings(self):
        txn = PaymentTransaction.objects.create(
            user=self.buyer, book=self.book, amount=Decimal("100.00"),
            commission_amount=Decimal("10.00"),
            payment_method=PaymentMethod.BANK_TRANSFER, currency="USD",
            status=TransactionStatus.COMPLETED,
        )
        create_revenue_ledger(txn)
        self.client.force_authenticate(self.author)
        res = self.client.get("/v1/author/dashboard")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["total_sales"], 1)
        self.assertEqual(Decimal(res.data["gross_revenue"]), Decimal("100.00"))
        self.assertEqual(Decimal(res.data["net_revenue"]), Decimal("90.00"))

    def test_reader_cannot_access_author_dashboard(self):
        self.client.force_authenticate(self.buyer)
        res = self.client.get("/v1/author/dashboard")
        self.assertEqual(res.status_code, 403)

    def test_author_profile_get_creates_and_patch(self):
        self.client.force_authenticate(self.author)
        res = self.client.get("/v1/author/profile")
        self.assertEqual(res.status_code, 200)
        res = self.client.patch(
            "/v1/author/profile",
            {"pen_name": "Pen", "is_verified": True}, format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["pen_name"], "Pen")
        # is_verified is admin-controlled, must stay false.
        self.assertFalse(res.data["is_verified"])
