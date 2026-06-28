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
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "role",
            "is_superuser",
            "display_name",
            "preferred_ui_language",
        )
        read_only_fields = ("id", "email", "role", "is_superuser")
        extra_kwargs = {"id": {"read_only": True}}


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
