"""Tests for Telegram bot OTP auth (hardened SpareTera-style flow)."""

from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import PasswordResetCode, TelegramAuthSession
from apps.accounts.phone import normalize_phone
from apps.accounts.telegram_bot import handle_webhook_update

User = get_user_model()

BOT_SETTINGS = dict(
    TELEGRAM_AUTH_BOT_TOKEN="test-token",
    TELEGRAM_AUTH_BOT_USERNAME="FelegeAuthBot",
    TELEGRAM_AUTH_WEBHOOK_URL="https://api.example.com/v1/auth/telegram/webhook",
    TELEGRAM_AUTH_WEBHOOK_SECRET="whsec-test",
    TELEGRAM_AUTH_REQUIRE_WEBHOOK_SECRET=True,
)


@override_settings(**BOT_SETTINGS)
class PhoneNormalizeTests(TestCase):
    def test_ethiopian_local(self):
        self.assertEqual(normalize_phone("0912345678"), "+251912345678")
        self.assertEqual(normalize_phone("912345678"), "+251912345678")
        self.assertEqual(normalize_phone("+251912345678"), "+251912345678")


@override_settings(**BOT_SETTINGS)
class TelegramInitiateTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_initiate_returns_bot_link(self):
        resp = self.client.post(
            "/v1/auth/telegram/initiate",
            {"phone": "0912345678", "purpose": "login"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn("session_id", resp.data)
        self.assertTrue(resp.data["bot_link"].startswith("https://t.me/FelegeAuthBot?start="))
        self.assertEqual(
            TelegramAuthSession.objects.filter(phone="+251912345678").count(), 1
        )

    def test_initiate_invalid_phone(self):
        resp = self.client.post(
            "/v1/auth/telegram/initiate",
            {"phone": "abc", "purpose": "login"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)


@override_settings(**BOT_SETTINGS)
class TelegramWebhookAndVerifyTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.phone = "+251911000001"
        self.session = TelegramAuthSession.objects.create(
            phone=self.phone,
            purpose=TelegramAuthSession.Purpose.LOGIN,
            expires_at=timezone.now() + TelegramAuthSession.SESSION_TTL,
        )

    def _headers(self):
        return {"HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN": "whsec-test"}

    @patch("apps.accounts.telegram_bot.bot_api")
    def test_webhook_rejects_bad_secret(self, _api):
        resp = self.client.post(
            "/v1/auth/telegram/webhook",
            {"message": {"text": f"/start {self.session.id}"}},
            format="json",
            HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN="wrong",
        )
        self.assertEqual(resp.status_code, 401)

    @patch("apps.accounts.telegram_bot.bot_api")
    def test_contact_spoof_rejected(self, mock_api):
        mock_api.return_value = {"ok": True, "result": {}}
        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 42},
                    "from": {"id": 42, "username": "alice"},
                    "text": f"/start {self.session.id}",
                }
            }
        )
        self.session.refresh_from_db()
        self.assertEqual(self.session.status, TelegramAuthSession.Status.AWAITING_CONTACT)

        # Contact from a different user_id than message.from
        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 42},
                    "from": {"id": 42, "username": "alice"},
                    "contact": {
                        "phone_number": "251911000001",
                        "user_id": 999,  # spoof
                    },
                }
            }
        )
        self.session.refresh_from_db()
        self.assertEqual(self.session.status, TelegramAuthSession.Status.AWAITING_CONTACT)
        self.assertFalse(self.session.code_hash)

    @patch("apps.accounts.telegram_bot.bot_api")
    def test_full_login_existing_user(self, mock_api):
        mock_api.return_value = {"ok": True, "result": {}}
        user = User.objects.create_user(
            email="tg-reader@example.com",
            password="password-12345",
            display_name="TG",
        )
        user.phone = self.phone
        user.phone_verified_at = timezone.now()
        user.telegram_user_id = 42
        user.telegram_chat_id = 42
        user.telegram_linked_at = timezone.now()
        user.save()

        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 42},
                    "from": {"id": 42, "username": "alice"},
                    "text": f"/start {self.session.id}",
                }
            }
        )
        # Capture code by issuing through contact handler
        with patch("apps.accounts.telegram_bot.TelegramAuthSession.generate_raw_code", return_value="123456"):
            handle_webhook_update(
                {
                    "message": {
                        "chat": {"id": 42},
                        "from": {"id": 42, "username": "alice"},
                        "contact": {
                            "phone_number": "251911000001",
                            "user_id": 42,
                        },
                    }
                }
            )

        self.session.refresh_from_db()
        self.assertEqual(self.session.status, TelegramAuthSession.Status.CODE_SENT)

        resp = self.client.post(
            "/v1/auth/telegram/verify",
            {"phone": self.phone, "code": "123456", "purpose": "login"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn("access_token", resp.data)
        self.assertEqual(resp.data["user"]["email"], user.email)

    @patch("apps.accounts.telegram_bot.bot_api")
    def test_new_user_needs_email_then_complete(self, mock_api):
        mock_api.return_value = {"ok": True, "result": {}}
        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 77},
                    "from": {"id": 77, "username": "bob"},
                    "text": f"/start {self.session.id}",
                }
            }
        )
        with patch(
            "apps.accounts.telegram_bot.TelegramAuthSession.generate_raw_code",
            return_value="654321",
        ):
            handle_webhook_update(
                {
                    "message": {
                        "chat": {"id": 77},
                        "from": {"id": 77, "username": "bob"},
                        "contact": {
                            "phone_number": "251911000001",
                            "user_id": 77,
                        },
                    }
                }
            )

        resp = self.client.post(
            "/v1/auth/telegram/verify",
            {"phone": self.phone, "code": "654321", "purpose": "login"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.data.get("needs_email"))

        resp2 = self.client.post(
            "/v1/auth/telegram/complete",
            {
                "phone": self.phone,
                "code": "654321",
                "email": "new-tg@example.com",
                "display_name": "New TG",
            },
            format="json",
        )
        self.assertEqual(resp2.status_code, 201)
        self.assertIn("access_token", resp2.data)
        user = User.objects.get(email="new-tg@example.com")
        self.assertEqual(user.phone, self.phone)
        self.assertEqual(user.telegram_user_id, 77)
        self.assertFalse(user.has_usable_password())


@override_settings(**BOT_SETTINGS, EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class ForgotPasswordTelegramChannelTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="linked@example.com",
            password="password-12345",
        )
        self.user.telegram_chat_id = 55
        self.user.telegram_user_id = 55
        self.user.telegram_linked_at = timezone.now()
        self.user.save()

    @patch("apps.accounts.telegram_bot.send_password_reset_code")
    def test_prefers_telegram_when_linked(self, mock_send):
        resp = self.client.post(
            "/v1/auth/forgot-password",
            {"email": self.user.email},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        mock_send.assert_called_once()
        entry = PasswordResetCode.objects.filter(user=self.user).latest("created_at")
        self.assertEqual(entry.channel, PasswordResetCode.Channel.TELEGRAM)


@override_settings(**BOT_SETTINGS)
class TelegramLinkTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="linkme@example.com",
            password="password-12345",
        )
        token = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")

    @patch("apps.accounts.telegram_bot.bot_api")
    def test_link_phone_no_otp(self, mock_api):
        """Linking only needs contact share — no OTP round-trip."""
        mock_api.return_value = {"ok": True, "result": {}}
        resp = self.client.post(
            "/v1/auth/telegram/initiate",
            {"purpose": "phone_link"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        session = TelegramAuthSession.objects.get(pk=resp.data["session_id"])
        self.assertEqual(session.user_id, self.user.id)

        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 88},
                    "from": {"id": 88},
                    "text": f"/start {session.id}",
                }
            }
        )
        handle_webhook_update(
            {
                "message": {
                    "chat": {"id": 88},
                    "from": {"id": 88},
                    "contact": {"phone_number": "251922000002", "user_id": 88},
                }
            }
        )

        session.refresh_from_db()
        self.assertEqual(session.status, TelegramAuthSession.Status.VERIFIED)
        self.user.refresh_from_db()
        self.assertEqual(self.user.telegram_user_id, 88)
        self.assertEqual(self.user.phone, "+251922000002")

        status = self.client.get(f"/v1/auth/telegram/session/{session.id}")
        self.assertEqual(status.status_code, 200)
        self.assertTrue(status.data["linked"])
        self.assertTrue(status.data["user"]["telegram_linked"])
