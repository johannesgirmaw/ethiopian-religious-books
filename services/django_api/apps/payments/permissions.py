from rest_framework.permissions import BasePermission


class IsPlatformAdmin(BasePermission):
    """Payment administration: superuser or a user with the ``admin`` role."""

    message = "Administrator access required."

    def has_permission(self, request, view):
        u = request.user
        return bool(
            u
            and u.is_authenticated
            and (u.is_superuser or getattr(u, "role", "") == "admin")
        )


class IsAuthor(BasePermission):
    """Earnings/profile endpoints: a user with the ``author`` role (or an admin)."""

    message = "Author access required."

    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated):
            return False
        role = getattr(u, "role", "")
        return bool(u.is_superuser or role in {"author", "admin"})
