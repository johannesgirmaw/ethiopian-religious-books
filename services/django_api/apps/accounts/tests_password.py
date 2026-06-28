"""Tests for the password reset (email OTP) and password change flows."""

from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import PasswordResetCode

User = get_user_model()

OLD_PASSWORD = "old-password-123"
NEW_PASSWORD = "fresh-password-456"


@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class ForgotPasswordTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="reader@example.com",
            password=OLD_PASSWORD,
            display_name="Test Reader",
        )

    def _latest_code(self):
        return PasswordResetCode.objects.filter(user=self.user).order_by("-created_at").first()

    def test_issues_code_and_sends_email(self):
        resp = self.client.post(
            "/v1/auth/forgot-password", {"email": self.user.email}, format="json"
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data, {"ok": True})
        self.assertEqual(len(mail.outbox), 1)
        entry = self._latest_code()
        self.assertIsNotNone(entry)
        # Raw code is never stored.
        self.assertNotIn(entry.code_hash, mail.outbox[0].body)
        self.assertEqual(len(entry.code_hash), 64)

    def test_unknown_email_is_silent_no_enumeration(self):
        resp = self.client.post(
            "/v1/auth/forgot-password", {"email": "nobody@example.com"}, format="json"
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data, {"ok": True})
        self.assertEqual(len(mail.outbox), 0)

    def test_resend_within_cooldown_does_not_send_again(self):
        self.client.post("/v1/auth/forgot-password", {"email": self.user.email}, format="json")
        self.client.post("/v1/auth/forgot-password", {"email": self.user.email}, format="json")
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(
            PasswordResetCode.objects.filter(user=self.user, consumed_at__isnull=True).count(),
            1,
        )

    def test_new_request_retires_previous_codes(self):
        first, raw1 = PasswordResetCode.issue(self.user)
        # Push it outside the resend cooldown window.
        PasswordResetCode.objects.filter(pk=first.pk).update(
            created_at=timezone.now() - PasswordResetCode.RESEND_COOLDOWN * 2
        )
        self.client.post("/v1/auth/forgot-password", {"email": self.user.email}, format="json")
        first.refresh_from_db()
        self.assertIsNotNone(first.consumed_at)


@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class ResetPasswordTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="reader@example.com", password=OLD_PASSWORD
        )

    def _issue(self):
        return PasswordResetCode.issue(self.user)

    def test_successful_reset_sets_password_and_consumes_code(self):
        entry, raw = self._issue()
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(NEW_PASSWORD))
        entry.refresh_from_db()
        self.assertIsNotNone(entry.consumed_at)

    def test_reset_revokes_all_sessions(self):
        # Two outstanding refresh tokens (two devices).
        RefreshToken.for_user(self.user)
        RefreshToken.for_user(self.user)
        outstanding = OutstandingToken.objects.filter(user=self.user).count()
        self.assertGreaterEqual(outstanding, 2)

        _, raw = self._issue()
        self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": NEW_PASSWORD},
            format="json",
        )
        blacklisted = BlacklistedToken.objects.filter(token__user=self.user).count()
        self.assertEqual(blacklisted, outstanding)

    def test_wrong_code_fails_and_increments_attempts(self):
        entry, _ = self._issue()
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": "000000", "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        entry.refresh_from_db()
        self.assertEqual(entry.attempts, 1)
        self.assertIsNone(entry.consumed_at)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(OLD_PASSWORD))

    def test_attempts_exhausted_locks_code(self):
        entry, raw = self._issue()
        for _ in range(PasswordResetCode.MAX_ATTEMPTS):
            self.client.post(
                "/v1/auth/reset-password",
                {"email": self.user.email, "code": "000000", "new_password": NEW_PASSWORD},
                format="json",
            )
        # Even the correct code is now rejected.
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(OLD_PASSWORD))

    def test_expired_code_rejected(self):
        entry, raw = self._issue()
        PasswordResetCode.objects.filter(pk=entry.pk).update(
            expires_at=timezone.now() - timezone.timedelta(minutes=1)
        )
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_weak_password_does_not_burn_attempt(self):
        entry, raw = self._issue()
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": "password12"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        entry.refresh_from_db()
        self.assertEqual(entry.attempts, 0)
        self.assertIsNone(entry.consumed_at)

    def test_code_is_single_use(self):
        _, raw = self._issue()
        self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": NEW_PASSWORD},
            format="json",
        )
        resp = self.client.post(
            "/v1/auth/reset-password",
            {"email": self.user.email, "code": raw, "new_password": "another-pass-789"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)


class ChangePasswordTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="reader@example.com", password=OLD_PASSWORD
        )
        self.client.force_authenticate(self.user)

    def test_requires_authentication(self):
        anon = APIClient()
        resp = anon.post(
            "/v1/auth/change-password",
            {"current_password": OLD_PASSWORD, "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 401)

    def test_successful_change_returns_fresh_tokens(self):
        resp = self.client.post(
            "/v1/auth/change-password",
            {"current_password": OLD_PASSWORD, "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn("access_token", resp.data)
        self.assertIn("refresh_token", resp.data)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(NEW_PASSWORD))

    def test_wrong_current_password_rejected(self):
        resp = self.client.post(
            "/v1/auth/change-password",
            {"current_password": "totally-wrong", "new_password": NEW_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(OLD_PASSWORD))

    def test_same_password_rejected(self):
        resp = self.client.post(
            "/v1/auth/change-password",
            {"current_password": OLD_PASSWORD, "new_password": OLD_PASSWORD},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_weak_password_rejected(self):
        resp = self.client.post(
            "/v1/auth/change-password",
            {"current_password": OLD_PASSWORD, "new_password": "short"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_change_revokes_other_sessions(self):
        RefreshToken.for_user(self.user)
        outstanding = OutstandingToken.objects.filter(user=self.user).count()
        self.client.post(
            "/v1/auth/change-password",
            {"current_password": OLD_PASSWORD, "new_password": NEW_PASSWORD},
            format="json",
        )
        blacklisted = BlacklistedToken.objects.filter(token__user=self.user).count()
        self.assertEqual(blacklisted, outstanding)


class RefreshTokenRobustnessTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="reader@example.com", password=OLD_PASSWORD
        )

    def test_revoked_token_returns_401(self):
        refresh = RefreshToken.for_user(self.user)
        # Revoke it the same way change/reset does.
        for token in OutstandingToken.objects.filter(user=self.user):
            BlacklistedToken.objects.get_or_create(token=token)
        resp = self.client.post(
            "/v1/auth/refresh", {"refresh_token": str(refresh)}, format="json"
        )
        self.assertEqual(resp.status_code, 401)

    def test_malformed_token_returns_401(self):
        resp = self.client.post(
            "/v1/auth/refresh", {"refresh_token": "not-a-token"}, format="json"
        )
        self.assertEqual(resp.status_code, 401)
