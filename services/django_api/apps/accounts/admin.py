from django.contrib import admin
from django.contrib.admin.sites import NotRegistered
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.models import Group
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from apps.accounts.models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm

    ordering = ("email",)
    list_display = ("email", "display_name", "role", "is_staff", "is_active", "date_joined", "last_login")
    list_filter = ("role", "is_staff", "is_active")
    search_fields = ("email", "display_name")
    readonly_fields = ("last_login", "date_joined")
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
