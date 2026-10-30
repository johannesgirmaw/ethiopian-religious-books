from django.contrib.auth import get_user_model
from django.db import transaction
from django.http import HttpResponseRedirect
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.emails import dispatch_password_reset_email
from apps.accounts.models import PasswordResetCode, TelegramAuthSession, UserDevice
from apps.accounts.phone import normalize_phone
from apps.accounts.serializers import (
    ChangePasswordSerializer,
    EmailTokenObtainPairSerializer,
    ForgotPasswordSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
    TelegramClaimSerializer,
    TelegramCompleteSerializer,
    TelegramInitiateSerializer,
    TelegramVerifySerializer,
    UserSerializer,
    run_password_validators,
)
from apps.accounts import telegram_bot

User = get_user_model()


def _client_ip(request) -> str | None:
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def _revoke_all_sessions(user) -> None:
    """Blacklist every outstanding refresh token for ``user``.

    Forces a re-login on all devices — used after a password change/reset so a
    compromised credential cannot keep a stolen session alive.
    """
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


def _tokens_for(user) -> dict:
    refresh = RefreshToken.for_user(user)
    return {
        "access_token": str(refresh.access_token),
        "access_expires_in": 900,
        "refresh_token": str(refresh),
        "refresh_expires_in": 14 * 24 * 3600,
    }


def _error(code: str, message: str, *, http_status: int) -> Response:
    return Response(
        {"error": {"code": code, "message": message}},
        status=http_status,
    )


class RegisterView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(request=RegisterSerializer, responses={201: UserSerializer})
    def post(self, request):
        ser = RegisterSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access_token": str(refresh.access_token),
                "access_expires_in": 900,
                "refresh_token": str(refresh),
                "refresh_expires_in": 14 * 24 * 3600,
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(TokenObtainPairView):
    permission_classes = [AllowAny]
    serializer_class = EmailTokenObtainPairSerializer

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        if response.status_code != 200:
            return response
        data = response.data
        email = request.data.get("email")
        user = User.objects.get(email=email)
        return Response(
            {
                "access_token": data["access"],
                "access_expires_in": 900,
                "refresh_token": data["refresh"],
                "refresh_expires_in": 14 * 24 * 3600,
                "user": UserSerializer(user).data,
            }
        )


class RefreshView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        from rest_framework_simplejwt.serializers import TokenRefreshSerializer

        raw = request.data.get("refresh_token") or request.data.get("refresh")
        ser = TokenRefreshSerializer(data={"refresh": raw})
        try:
            ser.is_valid(raise_exception=True)
        except TokenError:
            # Expired, malformed, or blacklisted (e.g. after a password change
            # revoked all sessions) — answer 401 so clients sign out cleanly.
            return _error(
                "TOKEN_INVALID",
                "Your session has expired. Please sign in again.",
                http_status=status.HTTP_401_UNAUTHORIZED,
            )
        data = ser.validated_data
        return Response(
            {
                "access_token": data["access"],
                "access_expires_in": 900,
                "refresh_token": data.get("refresh", raw),
                "refresh_expires_in": 14 * 24 * 3600,
            }
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        raw = request.data.get("refresh_token") or request.data.get("refresh")
        if not raw:
            return Response(
                {"error": {"code": "BAD_REQUEST", "message": "refresh_token required"}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            RefreshToken(raw).blacklist()
        except TokenError:
            pass
        return Response(status=status.HTTP_204_NO_CONTENT)


class ForgotPasswordView(APIView):
    """Begin a password reset by emailing a single-use 6-digit code.

    Always responds 200 with the same body whether or not the email maps to an
    account, so the endpoint cannot be used to enumerate registered users.
    """

    permission_classes = [AllowAny]

    @extend_schema(request=ForgotPasswordSerializer, responses={200: None})
    def post(self, request):
        """Password reset via Telegram only (for now).

        - If Telegram is already linked: DM the code immediately.
        - Otherwise: return a bot deep-link so the user can confirm phone,
          link Telegram, and receive the code there.
        """
        ser = ForgotPasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        email = ser.validated_data["email"].strip()
        return_url = (request.data.get("return_url") or "").strip() or None

        user = User.objects.filter(
            email__iexact=email, deleted_at__isnull=True, is_active=True
        ).first()
        # Always 200 when the account is unknown (no email enumeration).
        if user is None:
            return Response({"ok": True, "channel": "telegram"})

        if not telegram_bot.bot_configured():
            return _error(
                "TELEGRAM_UNAVAILABLE",
                "Telegram reset is temporarily unavailable. Try again later.",
                http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        now = timezone.now()
        recently_sent = PasswordResetCode.objects.filter(
            user=user,
            consumed_at__isnull=True,
            created_at__gte=now - PasswordResetCode.RESEND_COOLDOWN,
        ).exists()

        # Already linked → send code in Telegram DM (no email).
        if user.telegram_chat_id and not recently_sent:
            with transaction.atomic():
                PasswordResetCode.objects.filter(
                    user=user, consumed_at__isnull=True
                ).update(consumed_at=now)
                _, raw_code = PasswordResetCode.issue(
                    user,
                    ip=_client_ip(request),
                    channel=PasswordResetCode.Channel.TELEGRAM,
                )
            try:
                telegram_bot.send_password_reset_code(
                    chat_id=user.telegram_chat_id,
                    code=raw_code,
                    display_name=user.display_name,
                )
            except telegram_bot.TelegramBotError as exc:
                return _error(
                    "TELEGRAM_UNAVAILABLE",
                    str(exc) or "Could not send the code on Telegram.",
                    http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            return Response(
                {"ok": True, "channel": "telegram", "sent": True}
            )

        if recently_sent and user.telegram_chat_id:
            return Response(
                {"ok": True, "channel": "telegram", "sent": True}
            )

        # Not linked yet → open bot to confirm phone, link, then receive code.
        try:
            session, bot_link = telegram_bot.initiate_session(
                purpose=TelegramAuthSession.Purpose.PASSWORD_RESET,
                user=user,
                ip=_client_ip(request),
                return_url=return_url,
            )
        except telegram_bot.TelegramBotError as exc:
            return _error(
                "TELEGRAM_UNAVAILABLE",
                str(exc),
                http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        from django.conf import settings as dj_settings

        return Response(
            {
                "ok": True,
                "channel": "telegram",
                "needs_telegram": True,
                "session_id": str(session.id),
                "bot_link": bot_link,
                "bot_username": (dj_settings.TELEGRAM_AUTH_BOT_USERNAME or "").lstrip(
                    "@"
                ),
            }
        )


class ResetPasswordView(APIView):
    """Complete a reset: verify the emailed code and set the new password."""

    permission_classes = [AllowAny]

    @extend_schema(request=ResetPasswordSerializer, responses={200: None})
    def post(self, request):
        ser = ResetPasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        email = ser.validated_data["email"].strip()
        code = ser.validated_data["code"]
        new_password = ser.validated_data["new_password"]

        invalid = _error(
            "INVALID_CODE",
            "The code is invalid or has expired. Request a new one.",
            http_status=status.HTTP_400_BAD_REQUEST,
        )

        user = User.objects.filter(
            email__iexact=email, deleted_at__isnull=True, is_active=True
        ).first()
        if user is None:
            return invalid

        # Reject weak passwords before touching the code so a poor choice does
        # not burn a verification attempt.
        run_password_validators(new_password, user=user)

        with transaction.atomic():
            entry = (
                PasswordResetCode.objects.select_for_update()
                .filter(user=user, consumed_at__isnull=True)
                .order_by("-created_at")
                .first()
            )
            if entry is None or not entry.is_usable():
                return invalid

            entry.attempts += 1
            if not entry.verify(code):
                entry.save(update_fields=["attempts"])
                return invalid

            entry.consumed_at = timezone.now()
            entry.save(update_fields=["attempts", "consumed_at"])
            # Retire any sibling codes too.
            PasswordResetCode.objects.filter(
                user=user, consumed_at__isnull=True
            ).update(consumed_at=timezone.now())

            user.set_password(new_password)
            user.save(update_fields=["password"])
            _revoke_all_sessions(user)

        return Response({"ok": True})


class ChangePasswordView(APIView):
    """Change the password for the signed-in user (requires the current one)."""

    permission_classes = [IsAuthenticated]

    @extend_schema(request=ChangePasswordSerializer, responses={200: None})
    def post(self, request):
        ser = ChangePasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = request.user
        current_password = ser.validated_data["current_password"]
        new_password = ser.validated_data["new_password"]

        if not user.check_password(current_password):
            return _error(
                "INVALID_CREDENTIALS",
                "Your current password is incorrect.",
                http_status=status.HTTP_400_BAD_REQUEST,
            )
        if user.check_password(new_password):
            return _error(
                "SAME_PASSWORD",
                "Your new password must be different from the current one.",
                http_status=status.HTTP_400_BAD_REQUEST,
            )

        run_password_validators(new_password, user=user)

        with transaction.atomic():
            user.set_password(new_password)
            user.save(update_fields=["password"])
            _revoke_all_sessions(user)
            # Re-issue tokens so the current device stays signed in.
            tokens = _tokens_for(user)

        return Response(tokens)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        ser = UserSerializer(request.user, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        allowed = {"display_name", "preferred_ui_language"}
        for k, v in ser.validated_data.items():
            if k in allowed:
                setattr(request.user, k, v)
        request.user.save()
        return Response(UserSerializer(request.user).data)


class DeviceRegisterView(APIView):
    """Register (or rotate the key of) a device for hardware-bound offline reading.

    Idempotent on (user, device_id): calling again updates the stored public key
    and ``last_seen``. The private key never leaves the device, so the server only
    ever sees the public half.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        device_id = (request.data.get("device_id") or "").strip()
        if not device_id:
            return Response(
                {"error": {"code": "DEVICE_ID_REQUIRED", "message": "device_id is required."}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        public_key = (request.data.get("public_key") or "").strip()
        platform = (request.data.get("platform") or "").strip()[:40]
        label = (request.data.get("label") or "").strip()[:120]
        device, _created = UserDevice.objects.update_or_create(
            user=request.user,
            device_id=device_id[:128],
            defaults={"public_key": public_key, "platform": platform, "label": label},
        )
        return Response(
            {
                "device_id": device.device_id,
                "registered": True,
            },
            status=status.HTTP_200_OK,
        )


def _auth_payload(user) -> dict:
    return {**_tokens_for(user), "user": UserSerializer(user).data}


def _find_user_for_telegram_session(session: TelegramAuthSession):
    """Match an existing account by Telegram id, then verified phone."""
    user = None
    if session.telegram_user_id is not None:
        user = User.objects.filter(
            telegram_user_id=session.telegram_user_id,
            deleted_at__isnull=True,
            is_active=True,
        ).first()
    if user is None and session.phone:
        user = User.objects.filter(
            phone=session.phone,
            phone_verified_at__isnull=False,
            deleted_at__isnull=True,
            is_active=True,
        ).first()
    return user


def _load_usable_telegram_session(*, phone: str, purpose: str):
    now = timezone.now()
    return (
        TelegramAuthSession.objects.select_for_update()
        .filter(
            phone=phone,
            purpose=purpose,
            status=TelegramAuthSession.Status.CODE_SENT,
            consumed_at__isnull=True,
            expires_at__gt=now,
        )
        .order_by("-created_at")
        .first()
    )


class TelegramInitiateView(APIView):
    """Start Telegram bot deep-link OTP (login or link)."""

    permission_classes = [AllowAny]

    @extend_schema(request=TelegramInitiateSerializer, responses={200: None})
    def post(self, request):
        ser = TelegramInitiateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        purpose = ser.validated_data["purpose"]
        raw_phone = (ser.validated_data.get("phone") or "").strip() or None
        return_url = (ser.validated_data.get("return_url") or "").strip() or None

        if purpose == TelegramAuthSession.Purpose.PHONE_LINK:
            if not request.user or not request.user.is_authenticated:
                return _error(
                    "AUTH_REQUIRED",
                    "Sign in to link Telegram.",
                    http_status=status.HTTP_401_UNAUTHORIZED,
                )

        if not telegram_bot.bot_configured():
            return _error(
                "TELEGRAM_UNAVAILABLE",
                "Telegram login is temporarily unavailable.",
                http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        try:
            session, bot_link = telegram_bot.initiate_session(
                raw_phone=raw_phone,
                purpose=purpose,
                user=request.user if purpose == TelegramAuthSession.Purpose.PHONE_LINK else None,
                ip=_client_ip(request),
                return_url=return_url,
            )
        except ValueError as exc:
            return _error(
                "INVALID_PHONE",
                str(exc),
                http_status=status.HTTP_400_BAD_REQUEST,
            )
        except telegram_bot.TelegramBotError as exc:
            return _error(
                "TELEGRAM_UNAVAILABLE",
                str(exc),
                http_status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        from django.conf import settings as dj_settings

        return Response(
            {
                "session_id": str(session.id),
                "bot_link": bot_link,
                "bot_username": (dj_settings.TELEGRAM_AUTH_BOT_USERNAME or "").lstrip(
                    "@"
                ),
            }
        )


class TelegramSessionStatusView(APIView):
    """Poll session status (login + link — no OTP)."""

    permission_classes = [AllowAny]

    def get(self, request, session_id):
        try:
            session = TelegramAuthSession.objects.get(pk=session_id)
        except (TelegramAuthSession.DoesNotExist, ValueError):
            return _error(
                "NOT_FOUND",
                "Session not found.",
                http_status=status.HTTP_404_NOT_FOUND,
            )

        if session.purpose == TelegramAuthSession.Purpose.PHONE_LINK:
            if not request.user or not request.user.is_authenticated:
                return _error(
                    "AUTH_REQUIRED",
                    "Sign in to check link status.",
                    http_status=status.HTTP_401_UNAUTHORIZED,
                )
            if session.user_id != request.user.id:
                return _error(
                    "FORBIDDEN",
                    "This session belongs to another account.",
                    http_status=status.HTTP_403_FORBIDDEN,
                )

        ready = (
            session.purpose == TelegramAuthSession.Purpose.LOGIN
            and session.status == TelegramAuthSession.Status.VERIFIED
            and session.consumed_at is None
            and not session.is_expired()
        )
        needs_email = False
        if ready:
            needs_email = _find_user_for_telegram_session(session) is None

        code_sent = (
            session.purpose == TelegramAuthSession.Purpose.PASSWORD_RESET
            and session.status == TelegramAuthSession.Status.CODE_SENT
            and not session.is_expired()
        )

        payload = {
            "session_id": str(session.id),
            "purpose": session.purpose,
            "status": session.status,
            "ready": ready,
            "needs_email": needs_email,
            "code_sent": code_sent,
            "phone": session.phone or "",
            "linked": (
                session.purpose == TelegramAuthSession.Purpose.PHONE_LINK
                and session.status == TelegramAuthSession.Status.VERIFIED
            ),
        }
        if payload["linked"] and session.user_id:
            user = session.user
            payload["user"] = UserSerializer(user).data
        return Response(payload)


class TelegramClaimView(APIView):
    """Exchange a contact-verified login session for JWT (or needs_email)."""

    permission_classes = [AllowAny]

    @extend_schema(request=TelegramClaimSerializer, responses={200: None})
    def post(self, request):
        ser = TelegramClaimSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        session_id = ser.validated_data["session_id"]

        with transaction.atomic():
            try:
                session = (
                    TelegramAuthSession.objects.select_for_update().get(pk=session_id)
                )
            except TelegramAuthSession.DoesNotExist:
                return _error(
                    "NOT_FOUND",
                    "Session not found.",
                    http_status=status.HTTP_404_NOT_FOUND,
                )

            if session.purpose != TelegramAuthSession.Purpose.LOGIN:
                return _error(
                    "INVALID_SESSION",
                    "This session is not a login session.",
                    http_status=status.HTTP_400_BAD_REQUEST,
                )
            if (
                session.status != TelegramAuthSession.Status.VERIFIED
                or session.consumed_at is not None
                or session.is_expired()
                or session.telegram_user_id is None
            ):
                return _error(
                    "NOT_READY",
                    "Confirm your phone in Telegram first, then try again.",
                    http_status=status.HTTP_400_BAD_REQUEST,
                )

            user = _find_user_for_telegram_session(session)
            if user is None:
                return Response(
                    {
                        "ok": True,
                        "needs_email": True,
                        "phone": session.phone,
                        "session_id": str(session.id),
                    }
                )

            try:
                telegram_bot.attach_telegram_to_user(user, session)
            except telegram_bot.TelegramBotError:
                if user.telegram_user_id != session.telegram_user_id:
                    return _error(
                        "LINK_CONFLICT",
                        "This Telegram account is linked to another user.",
                        http_status=status.HTTP_409_CONFLICT,
                    )

            session.consumed_at = timezone.now()
            session.save(update_fields=["consumed_at"])
            return Response(_auth_payload(user))


class TelegramReturnRedirectView(APIView):
    """Public HTTPS bounce used by the bot's Open Felege Metsahft button.

    Telegram rejects ``localhost`` button URLs, so the bot links here and we
    302 to the client's local or production app URL stored on the session.
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        session_id = (request.query_params.get("session") or "").strip()
        if not session_id:
            return _error(
                "NOT_FOUND",
                "Missing session.",
                http_status=status.HTTP_404_NOT_FOUND,
            )
        try:
            session = TelegramAuthSession.objects.get(pk=session_id)
        except (TelegramAuthSession.DoesNotExist, ValueError):
            return _error(
                "NOT_FOUND",
                "Session not found.",
                http_status=status.HTTP_404_NOT_FOUND,
            )
        target = telegram_bot.final_app_url_for_session(session)
        if not target:
            from django.conf import settings as dj_settings

            fallback = (
                getattr(dj_settings, "TELEGRAM_AUTH_APP_RETURN_BASE", "") or ""
            ).strip() or "https://app.felegemetsahft.com/#/auth/telegram"
            target = telegram_bot.append_session_query(fallback, session.id)
        return HttpResponseRedirect(target)


class TelegramWebhookView(APIView):
    """Telegram Bot API webhook — always validates secret token in prod."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        from django.conf import settings as dj_settings

        secret = request.headers.get("X-Telegram-Bot-Api-Secret-Token", "")
        expected = telegram_bot.webhook_secret()
        require = getattr(dj_settings, "TELEGRAM_AUTH_REQUIRE_WEBHOOK_SECRET", True)
        if require:
            if not expected or secret != expected:
                return _error(
                    "UNAUTHORIZED",
                    "Invalid webhook secret.",
                    http_status=status.HTTP_401_UNAUTHORIZED,
                )
        elif expected and secret != expected:
            return _error(
                "UNAUTHORIZED",
                "Invalid webhook secret.",
                http_status=status.HTTP_401_UNAUTHORIZED,
            )

        try:
            telegram_bot.handle_webhook_update(request.data if isinstance(request.data, dict) else {})
        except Exception:
            # Always 200 to Telegram after auth so Telegram does not retry forever
            # on our application bugs — log instead.
            import logging

            logging.getLogger(__name__).exception("Telegram webhook handler failed")
        return Response({"ok": True})


class TelegramVerifyView(APIView):
    """Verify Telegram OTP for login (existing user) or phone_link."""

    permission_classes = [AllowAny]

    @extend_schema(request=TelegramVerifySerializer, responses={200: None})
    def post(self, request):
        ser = TelegramVerifySerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        purpose = ser.validated_data["purpose"]
        code = ser.validated_data["code"]

        try:
            phone = normalize_phone(ser.validated_data["phone"])
        except ValueError as exc:
            return _error(
                "INVALID_PHONE",
                str(exc),
                http_status=status.HTTP_400_BAD_REQUEST,
            )

        invalid = _error(
            "INVALID_CODE",
            "The code is invalid or has expired. Request a new one.",
            http_status=status.HTTP_400_BAD_REQUEST,
        )

        if purpose == TelegramAuthSession.Purpose.PHONE_LINK:
            if not request.user or not request.user.is_authenticated:
                return _error(
                    "AUTH_REQUIRED",
                    "Sign in to link Telegram.",
                    http_status=status.HTTP_401_UNAUTHORIZED,
                )

        with transaction.atomic():
            session = _load_usable_telegram_session(phone=phone, purpose=purpose)
            if session is None or not session.code_is_usable():
                return invalid

            session.attempts += 1
            if not session.verify_code(code):
                session.save(update_fields=["attempts"])
                return invalid

            session.consumed_at = timezone.now()
            session.status = TelegramAuthSession.Status.VERIFIED
            session.save(update_fields=["attempts", "consumed_at", "status"])

            if purpose == TelegramAuthSession.Purpose.PHONE_LINK:
                try:
                    telegram_bot.attach_telegram_to_user(request.user, session)
                except telegram_bot.TelegramBotError as exc:
                    return _error(
                        "LINK_CONFLICT",
                        str(exc),
                        http_status=status.HTTP_409_CONFLICT,
                    )
                return Response(
                    {
                        "ok": True,
                        "user": UserSerializer(request.user).data,
                    }
                )

            # login purpose
            user = None
            if session.telegram_user_id is not None:
                user = User.objects.filter(
                    telegram_user_id=session.telegram_user_id,
                    deleted_at__isnull=True,
                    is_active=True,
                ).first()
            if user is None:
                user = User.objects.filter(
                    phone=phone,
                    phone_verified_at__isnull=False,
                    deleted_at__isnull=True,
                    is_active=True,
                ).first()

            if user is None:
                # New user — client must call complete with email.
                return Response(
                    {
                        "ok": True,
                        "needs_email": True,
                        "phone": phone,
                        "session_id": str(session.id),
                    }
                )

            # Refresh telegram binding on existing user.
            try:
                telegram_bot.attach_telegram_to_user(user, session)
            except telegram_bot.TelegramBotError:
                # Already linked to this user or race — still allow login if ids match.
                if user.telegram_user_id != session.telegram_user_id:
                    return _error(
                        "LINK_CONFLICT",
                        "This Telegram account is linked to another user.",
                        http_status=status.HTTP_409_CONFLICT,
                    )

            return Response(_auth_payload(user))


class TelegramCompleteView(APIView):
    """Finish Telegram signup: attach email after contact verify (or legacy OTP)."""

    permission_classes = [AllowAny]

    @extend_schema(request=TelegramCompleteSerializer, responses={201: None})
    def post(self, request):
        ser = TelegramCompleteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        session_id = ser.validated_data.get("session_id")
        code = (ser.validated_data.get("code") or "").strip()
        email = ser.validated_data["email"].strip().lower()
        password = (ser.validated_data.get("password") or "").strip()
        display_name = (ser.validated_data.get("display_name") or "").strip()
        preferred = (ser.validated_data.get("preferred_ui_language") or "en").strip() or "en"
        raw_phone = (ser.validated_data.get("phone") or "").strip()

        invalid = _error(
            "INVALID_CODE",
            "The code is invalid or has expired. Request a new one.",
            http_status=status.HTTP_400_BAD_REQUEST,
        )

        if User.objects.filter(email__iexact=email, deleted_at__isnull=True).exists():
            return _error(
                "EMAIL_TAKEN",
                "An account with this email already exists. Sign in and link Telegram instead.",
                http_status=status.HTTP_409_CONFLICT,
            )

        with transaction.atomic():
            now = timezone.now()
            session = None
            if session_id:
                try:
                    session = (
                        TelegramAuthSession.objects.select_for_update().get(pk=session_id)
                    )
                except TelegramAuthSession.DoesNotExist:
                    return invalid
                if (
                    session.purpose != TelegramAuthSession.Purpose.LOGIN
                    or session.status != TelegramAuthSession.Status.VERIFIED
                    or session.telegram_user_id is None
                    or session.is_expired(now=now)
                ):
                    return invalid
                phone = session.phone
            else:
                try:
                    phone = normalize_phone(raw_phone)
                except ValueError as exc:
                    return _error(
                        "INVALID_PHONE",
                        str(exc),
                        http_status=status.HTTP_400_BAD_REQUEST,
                    )
                session = (
                    TelegramAuthSession.objects.select_for_update()
                    .filter(
                        phone=phone,
                        purpose=TelegramAuthSession.Purpose.LOGIN,
                    )
                    .order_by("-created_at")
                    .first()
                )
                if session is None:
                    return invalid

                if session.status == TelegramAuthSession.Status.VERIFIED:
                    if session.is_expired(now=now) or session.telegram_user_id is None:
                        return invalid
                elif session.code_is_usable(now=now):
                    session.attempts += 1
                    if not session.verify_code(code):
                        session.save(update_fields=["attempts"])
                        return invalid
                    session.status = TelegramAuthSession.Status.VERIFIED
                    session.save(update_fields=["attempts", "status"])
                else:
                    if (
                        session.status != TelegramAuthSession.Status.VERIFIED
                        or session.telegram_user_id is None
                        or session.is_expired(now=now)
                    ):
                        return invalid
                    if session.code_hash and code and not session.verify_code(code):
                        return invalid

            if not phone:
                return invalid

            if session.telegram_user_id and User.objects.filter(
                telegram_user_id=session.telegram_user_id
            ).exists():
                return _error(
                    "LINK_CONFLICT",
                    "This Telegram account is already linked to another user.",
                    http_status=status.HTTP_409_CONFLICT,
                )
            if User.objects.filter(phone=phone).exists():
                return _error(
                    "LINK_CONFLICT",
                    "This phone number is already linked to another user.",
                    http_status=status.HTTP_409_CONFLICT,
                )

            user = User(
                email=email,
                role="reader",
                display_name=display_name,
                preferred_ui_language=preferred[:10],
            )
            if password:
                run_password_validators(password, user=user)
                user.set_password(password)
            else:
                user.set_unusable_password()
            user.save()
            telegram_bot.attach_telegram_to_user(user, session)
            session.consumed_at = now
            session.status = TelegramAuthSession.Status.VERIFIED
            session.save(update_fields=["consumed_at", "status"])

        return Response(_auth_payload(user), status=status.HTTP_201_CREATED)
