from rest_framework import serializers

from apps.catalog.models import Book
from apps.catalog.storage_s3 import is_object_storage_configured, presign_get
from apps.payments.enums import PaymentMethod
from apps.payments.models import (
    AuthorApplication,
    AuthorCommission,
    AuthorProfile,
    Bank,
    GatewayCredential,
    PaymentTransaction,
    PlatformSettings,
    RevenueLedger,
)


class BankSerializer(serializers.ModelSerializer):
    class Meta:
        model = Bank
        fields = (
            "id",
            "name",
            "code",
            "account_name",
            "account_number",
            "logo_url",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class PublicBankSerializer(serializers.ModelSerializer):
    """Bank details exposed to buyers (no admin metadata)."""

    class Meta:
        model = Bank
        fields = ("id", "name", "code", "account_name", "account_number", "logo_url")
        read_only_fields = fields


class PlatformSettingsSerializer(serializers.ModelSerializer):
    enabled_methods = serializers.SerializerMethodField()

    class Meta:
        model = PlatformSettings
        fields = (
            "id",
            "stripe_enabled",
            "paypal_enabled",
            "telebirr_enabled",
            "manual_payment_enabled",
            "default_commission_percent",
            "allow_author_override",
            "allow_book_override",
            "is_active",
            "updated_at",
            "enabled_methods",
        )
        read_only_fields = ("id", "updated_at", "enabled_methods")

    def get_enabled_methods(self, obj: PlatformSettings) -> list[str]:
        return obj.enabled_methods()

    def validate_default_commission_percent(self, value):
        return _validate_percent(value)


class GatewayCredentialSerializer(serializers.ModelSerializer):
    """Write-only secret handling: the plaintext secret is never returned."""

    secret = serializers.CharField(write_only=True, required=False, allow_blank=True)
    webhook_secret = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )
    has_secret = serializers.SerializerMethodField()

    class Meta:
        model = GatewayCredential
        fields = (
            "id",
            "provider",
            "public_key",
            "is_active",
            "extra",
            "updated_at",
            "secret",
            "webhook_secret",
            "has_secret",
            "is_configured",
        )
        read_only_fields = ("id", "updated_at", "has_secret", "is_configured")

    def get_has_secret(self, obj: GatewayCredential) -> bool:
        return bool(obj.encrypted_secret)

    def update(self, instance, validated_data):
        secret = validated_data.pop("secret", None)
        webhook_secret = validated_data.pop("webhook_secret", None)
        for key, value in validated_data.items():
            setattr(instance, key, value)
        if secret is not None:
            instance.set_secret(secret)
        if webhook_secret is not None:
            instance.set_webhook_secret(webhook_secret)
        instance.save()
        return instance


class AuthorCommissionSerializer(serializers.ModelSerializer):
    author_email = serializers.EmailField(source="author.email", read_only=True)

    class Meta:
        model = AuthorCommission
        fields = (
            "id",
            "author",
            "author_email",
            "commission_percent",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "author_email", "created_at", "updated_at")

    def validate_commission_percent(self, value):
        return _validate_percent(value)


class AuthorProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuthorProfile
        fields = (
            "id",
            "user",
            "pen_name",
            "bio",
            "photo_url",
            "phone",
            "country",
            "payment_email",
            "telebirr_number",
            "is_verified",
            "created_at",
            "updated_at",
        )
        # ``is_verified`` is admin-controlled, not self-settable.
        read_only_fields = ("id", "user", "is_verified", "created_at", "updated_at")


class AuthorApplicationSerializer(serializers.ModelSerializer):
    """Applicant-facing read/write serializer.

    Review fields (``status``/``reviewed_*``) are admin-controlled and read-only,
    mirroring ``AuthorProfileSerializer.is_verified``. ``photo_object_key`` is
    writable (the client attaches it after a presigned upload) while ``photo_url``
    is a short-lived signed URL derived from it.
    """

    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = AuthorApplication
        fields = (
            "id",
            "full_name",
            "pen_name",
            "title",
            "bio",
            "phone",
            "country",
            "photo_object_key",
            "photo_url",
            "credentials",
            "sample_links",
            "payment_email",
            "telebirr_number",
            "status",
            "review_note",
            "reviewed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "photo_url",
            "status",
            "review_note",
            "reviewed_at",
            "created_at",
            "updated_at",
        )

    def get_photo_url(self, obj: AuthorApplication) -> str:
        if not obj.photo_object_key or not is_object_storage_configured():
            return ""
        request = self.context.get("request")
        presign_endpoint = None
        if request is not None:
            from apps.catalog.storage_s3 import dev_presign_endpoint_from_request

            presign_endpoint = dev_presign_endpoint_from_request(request)
        try:
            return presign_get(
                obj.photo_object_key, presign_endpoint_url=presign_endpoint
            )
        except Exception:
            return ""


class AdminAuthorApplicationSerializer(AuthorApplicationSerializer):
    """Adds applicant identity + reviewer for the admin review queue."""

    user = serializers.UUIDField(source="user_id", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_display_name = serializers.CharField(
        source="user.display_name", read_only=True
    )
    reviewed_by = serializers.UUIDField(source="reviewed_by_id", read_only=True)

    class Meta(AuthorApplicationSerializer.Meta):
        fields = AuthorApplicationSerializer.Meta.fields + (
            "user",
            "user_email",
            "user_display_name",
            "reviewed_by",
        )


class PaymentTransactionSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source="book.title", read_only=True)
    bank_detail = PublicBankSerializer(source="bank", read_only=True)
    author_amount = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    receipt_url = serializers.SerializerMethodField()
    user_email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = PaymentTransaction
        fields = (
            "id",
            "user",
            "user_email",
            "book",
            "book_title",
            "bank",
            "bank_detail",
            "currency",
            "amount",
            "commission_amount",
            "author_amount",
            "payment_method",
            "status",
            "transaction_reference",
            "gateway_reference",
            "receipt_url",
            "review_note",
            "reviewed_by",
            "reviewed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields

    def get_receipt_url(self, obj: PaymentTransaction) -> str:
        # Absolute URL to the authenticated streaming endpoint (owner/admin).
        # Empty when no receipt has been uploaded.
        if not obj.receipt_object_key:
            return ""
        path = f"/v1/payments/transactions/{obj.id}/receipt-file"
        request = self.context.get("request")
        return request.build_absolute_uri(path) if request is not None else path


class CreateTransactionSerializer(serializers.Serializer):
    """Initiate a purchase. Amount/commission are computed server-side."""

    book = serializers.PrimaryKeyRelatedField(queryset=Book.objects.all())
    payment_method = serializers.ChoiceField(choices=PaymentMethod.choices)
    bank = serializers.PrimaryKeyRelatedField(
        queryset=Bank.objects.filter(is_active=True), required=False, allow_null=True
    )


class SubmitReceiptSerializer(serializers.Serializer):
    receipt = serializers.FileField()
    transaction_reference = serializers.CharField(max_length=120)
    bank = serializers.PrimaryKeyRelatedField(
        queryset=Bank.objects.filter(is_active=True), required=False, allow_null=True
    )


class RevenueLedgerSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source="book.title", read_only=True)

    class Meta:
        model = RevenueLedger
        fields = (
            "id",
            "transaction",
            "author",
            "book",
            "book_title",
            "currency",
            "sale_amount",
            "commission_amount",
            "author_amount",
            "created_at",
        )
        read_only_fields = fields


def _validate_percent(value):
    if value is None:
        return value
    if value < 0 or value > 100:
        raise serializers.ValidationError("Commission percent must be between 0 and 100.")
    return value
