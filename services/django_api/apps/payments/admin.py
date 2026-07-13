from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin

from apps.payments.enums import AuthorApplicationStatus
from apps.payments.models import (
    AuditLog,
    AuthorApplication,
    AuthorCommission,
    AuthorProfile,
    Bank,
    GatewayCredential,
    PaymentTransaction,
    PlatformSettings,
    RevenueLedger,
)
from apps.payments.services import (
    approve_author_application,
    reject_author_application,
)


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(ModelAdmin):
    list_display = (
        "__str__",
        "default_commission_percent",
        "stripe_enabled",
        "paypal_enabled",
        "telebirr_enabled",
        "manual_payment_enabled",
        "is_active",
        "updated_at",
    )

    def has_add_permission(self, request):
        # Singleton — only one settings row.
        return not PlatformSettings.objects.exists()


@admin.register(GatewayCredential)
class GatewayCredentialAdmin(ModelAdmin):
    list_display = ("provider", "is_active", "has_secret", "updated_at")
    list_filter = ("is_active", "provider")
    # Encrypted material is never shown in plaintext through the admin.
    exclude = ("encrypted_secret", "webhook_secret_encrypted")

    @admin.display(boolean=True, description="Secret stored")
    def has_secret(self, obj):
        return bool(obj.encrypted_secret)


@admin.register(Bank)
class BankAdmin(ModelAdmin):
    list_display = ("name", "code", "account_name", "account_number", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "code", "account_name", "account_number")


@admin.register(AuthorCommission)
class AuthorCommissionAdmin(ModelAdmin):
    list_display = ("author", "commission_percent", "updated_at")
    search_fields = ("author__email",)
    raw_id_fields = ("author",)


@admin.register(AuthorProfile)
class AuthorProfileAdmin(ModelAdmin):
    list_display = ("pen_name", "user", "country", "is_verified", "updated_at")
    list_filter = ("is_verified", "country")
    search_fields = ("pen_name", "user__email", "payment_email")
    raw_id_fields = ("user",)


@admin.register(AuthorApplication)
class AuthorApplicationAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "full_name",
        "user",
        "title",
        "country",
        "status",
        "reviewed_by",
        "reviewed_at",
    )
    list_filter = ("status", "country")
    search_fields = ("full_name", "pen_name", "user__email", "payment_email")
    date_hierarchy = "created_at"
    raw_id_fields = ("user", "reviewed_by")
    readonly_fields = ("id", "created_at", "updated_at", "photo_preview")

    @admin.display(description="Photo")
    def photo_preview(self, obj):
        if not obj.photo_object_key:
            return "—"
        try:
            from apps.catalog.storage_s3 import presign_get

            url = presign_get(obj.photo_object_key)
        except Exception:
            return obj.photo_object_key
        return format_html('<a href="{}" target="_blank">View photo</a>', url)

    def save_model(self, request, obj, form, change):
        # Setting status to approved/rejected in the admin runs the same service
        # the API uses: promote the role, build the profile, notify + (for
        # rejection) record the note. Guarded so it only fires on a transition.
        prev_status = None
        if change and obj.pk:
            prev_status = (
                AuthorApplication.objects.filter(pk=obj.pk)
                .values_list("status", flat=True)
                .first()
            )
        super().save_model(request, obj, form, change)
        if (
            obj.status == AuthorApplicationStatus.APPROVED
            and prev_status != AuthorApplicationStatus.APPROVED
        ):
            approve_author_application(obj, reviewer=request.user)
        elif (
            obj.status == AuthorApplicationStatus.REJECTED
            and prev_status != AuthorApplicationStatus.REJECTED
        ):
            reject_author_application(obj, reviewer=request.user, note=obj.review_note)


@admin.register(PaymentTransaction)
class PaymentTransactionAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "user",
        "book",
        "payment_method",
        "amount",
        "currency",
        "status",
        "transaction_reference",
        "reviewed_by",
    )
    list_filter = ("status", "payment_method", "currency")
    search_fields = (
        "user__email",
        "book__title",
        "transaction_reference",
        "gateway_reference",
    )
    date_hierarchy = "created_at"
    raw_id_fields = ("user", "book", "bank", "reviewed_by")
    readonly_fields = ("id", "created_at", "updated_at", "receipt_preview")

    @admin.display(description="Receipt")
    def receipt_preview(self, obj):
        if not obj.receipt_object_key:
            return "—"
        # Streamed through the authenticated endpoint (staff session is accepted).
        url = f"/v1/payments/transactions/{obj.id}/receipt-file"
        return format_html('<a href="{}" target="_blank">View receipt</a>', url)


@admin.register(RevenueLedger)
class RevenueLedgerAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "book",
        "author",
        "sale_amount",
        "commission_amount",
        "author_amount",
        "currency",
    )
    list_filter = ("currency",)
    search_fields = ("book__title", "author__email")
    date_hierarchy = "created_at"
    raw_id_fields = ("transaction", "author", "book")
    readonly_fields = ("id", "created_at")


@admin.register(AuditLog)
class AuditLogAdmin(ModelAdmin):
    list_display = ("created_at", "actor", "action", "target_type", "target_id", "ip_address")
    list_filter = ("action", "target_type")
    search_fields = ("actor__email", "action", "target_id")
    date_hierarchy = "created_at"
    readonly_fields = ("id", "actor", "action", "target_type", "target_id",
                       "metadata", "ip_address", "created_at")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
