from django.contrib.auth import get_user_model
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.serializers import (
    EmailTokenObtainPairSerializer,
    RegisterSerializer,
    UserSerializer,
)

User = get_user_model()


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
        ser.is_valid(raise_exception=True)
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
    permission_classes = [AllowAny]

    def post(self, request):
        # Celery task can send email; always 200 per spec
        return Response({"ok": True})


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        return Response(status=status.HTTP_501_NOT_IMPLEMENTED)


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
