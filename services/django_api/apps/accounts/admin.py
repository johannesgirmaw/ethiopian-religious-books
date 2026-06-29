from django.contrib import admin
from django.contrib.admin.sites import NotRegistered
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.models import Group
from django.db.models import Count
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from apps.accounts.models import User, UserDevice


@admin.register(User)
class UserAdmin(DjangoUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm

    ordering = ("email",)
    list_display = (
        "email",
        "display_name",
        "role",
        "offline_downloads_count",
        "devices_count",
        "is_staff",
        "is_active",
        "date_joined",
        "last_login",
    )
    list_filter = ("role", "is_staff", "is_active")
    search_fields = ("email", "display_name")
    readonly_fields = ("last_login", "date_joined")

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(
            _offline_downloads=Count("offline_downloads", distinct=True),
            _devices=Count("devices", distinct=True),
        )

    @admin.display(description="Offline books", ordering="_offline_downloads")
    def offline_downloads_count(self, obj):
        return getattr(obj, "_offline_downloads", 0)

    @admin.display(description="Devices", ordering="_devices")
    def devices_count(self, obj):
        return getattr(obj, "_devices", 0)
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("display_name", "preferred_ui_language", "role")}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        ("Important dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "password1", "password2", "role"),
            },
        ),
    )


admin.site.unregister(Group)


@admin.register(Group)
class GroupAdmin(BaseGroupAdmin, ModelAdmin):
    pass


for jwt_model in (OutstandingToken, BlacklistedToken):
    try:
        admin.site.unregister(jwt_model)
    except NotRegistered:
        pass


@admin.register(OutstandingToken)
class OutstandingTokenAdmin(ModelAdmin):
    list_display = ("user", "jti", "created_at", "expires_at")
    list_filter = ("expires_at",)
    search_fields = ("jti", "user__email")
    raw_id_fields = ("user",)
    readonly_fields = ("jti", "token", "created_at", "expires_at")


@admin.register(BlacklistedToken)
class BlacklistedTokenAdmin(ModelAdmin):
    list_display = ("token", "blacklisted_at")
    search_fields = ("token__jti",)
    raw_id_fields = ("token",)
    readonly_fields = ("blacklisted_at",)


@admin.register(UserDevice)
class UserDeviceAdmin(ModelAdmin):
    """Devices registered for hardware-bound offline reading, with a live count of
    how many books each has saved offline."""

    list_display = (
        "user_email",
        "device_id_short",
        "platform",
        "offline_books",
        "created_at",
        "last_seen",
    )
    list_filter = ("platform", "created_at", "last_seen")
    search_fields = ("user__email", "device_id")
    raw_id_fields = ("user",)
    readonly_fields = ("created_at", "last_seen")

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("user")

    @admin.display(description="User", ordering="user__email")
    def user_email(self, obj):
        return obj.user.email

    @admin.display(description="Device id")
    def device_id_short(self, obj):
        return obj.device_id[:12]

    @admin.display(description="Offline books")
    def offline_books(self, obj):
        from apps.catalog.models import OfflineDownload

        return OfflineDownload.objects.filter(
            user_id=obj.user_id, device_id=obj.device_id
        ).count()
