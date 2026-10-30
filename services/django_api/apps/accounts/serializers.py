from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


def run_password_validators(password: str, user=None) -> None:
    """Apply Django's configured password validators, raising a DRF error.

    Centralised so reset and change flows enforce the same policy as registration.
    """
    try:
        validate_password(password, user=user)
    except DjangoValidationError as exc:
        raise serializers.ValidationError({"new_password": list(exc.messages)})


class UserSerializer(serializers.ModelSerializer):
    telegram_linked = serializers.SerializerMethodField()
    phone_verified = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "role",
            "is_superuser",
            "display_name",
            "preferred_ui_language",
            "phone",
            "phone_verified",
            "telegram_linked",
            "telegram_username",
        )
        read_only_fields = (
            "id",
            "email",
            "role",
            "is_superuser",
            "phone",
            "phone_verified",
            "telegram_linked",
            "telegram_username",
        )
        extra_kwargs = {"id": {"read_only": True}}

    def get_telegram_linked(self, obj) -> bool:
        return bool(obj.telegram_linked)

    def get_phone_verified(self, obj) -> bool:
        return obj.phone_verified_at is not None


class TelegramInitiateSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    purpose = serializers.ChoiceField(
        choices=("login", "phone_link"),
        default="login",
    )


class TelegramVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{6}$", min_length=6, max_length=6)
    purpose = serializers.ChoiceField(
        choices=("login", "phone_link"),
        default="login",
    )


class TelegramCompleteSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{6}$", min_length=6, max_length=6)
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        min_length=10,
    )
    display_name = serializers.CharField(required=False, allow_blank=True, max_length=255)
    preferred_ui_language = serializers.CharField(
        required=False, allow_blank=True, max_length=10
    )


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=10)

    class Meta:
        model = User
        fields = ("email", "password", "display_name", "preferred_ui_language")

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data, role="reader")
        user.set_password(password)
        user.save()
        return user


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields[self.username_field] = serializers.EmailField()


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.RegexField(r"^\d{6}$", min_length=6, max_length=6)
    new_password = serializers.CharField(write_only=True, min_length=10)


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=10)
