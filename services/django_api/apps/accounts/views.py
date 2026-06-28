from django.contrib.auth import get_user_model
from django.db import transaction
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
from apps.accounts.models import PasswordResetCode, UserDevice
from apps.accounts.serializers import (
    ChangePasswordSerializer,
    EmailTokenObtainPairSerializer,
    ForgotPasswordSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
    UserSerializer,
    run_password_validators,
)

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
        ser = ForgotPasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        email = ser.validated_data["email"].strip()

        user = User.objects.filter(
            email__iexact=email, deleted_at__isnull=True, is_active=True
        ).first()
        if user is not None:
            now = timezone.now()
            recently_sent = PasswordResetCode.objects.filter(
                user=user,
                consumed_at__isnull=True,
                created_at__gte=now - PasswordResetCode.RESEND_COOLDOWN,
            ).exists()
            if not recently_sent:
                with transaction.atomic():
                    # Retire any still-valid codes before issuing a fresh one.
                    PasswordResetCode.objects.filter(
                        user=user, consumed_at__isnull=True
                    ).update(consumed_at=now)
                    _, raw_code = PasswordResetCode.issue(
                        user, ip=_client_ip(request)
                    )
                dispatch_password_reset_email(
                    email=user.email,
                    code=raw_code,
                    display_name=user.display_name,
                )
        return Response({"ok": True})


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
