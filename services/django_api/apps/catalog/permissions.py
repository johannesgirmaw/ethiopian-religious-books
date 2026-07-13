from rest_framework.permissions import BasePermission


class IsPublisherAdmin(BasePermission):
    message = "Superuser required."

    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_superuser)


def is_platform_admin(user) -> bool:
    """A user who may manage every book (superuser or the admin role)."""
    return bool(
        user
        and user.is_authenticated
        and (user.is_superuser or getattr(user, "role", "") == "admin")
    )


class IsPublisherOrAuthor(BasePermission):
    """Book management: platform admins (all books) or authors (their own).

    Per-object ownership is enforced in the views via ``can_manage_book`` —
    this only gates entry to the admin book endpoints.
    """

    message = "Author or administrator access required."

    def has_permission(self, request, view):
        u = request.user
        return bool(
            u
            and u.is_authenticated
            and (is_platform_admin(u) or getattr(u, "role", "") == "author")
        )


class IsPlatformReviewer(BasePermission):
    """Editorial review actions (approve / request-changes): platform admins.

    Reviewers are platform admins (superuser or ``role=='admin'``) — NOT
    ``IsPublisherAdmin`` (superuser-only), which would exclude admin-role users.
    """

    message = "Reviewer access required."

    def has_permission(self, request, view):
        return is_platform_admin(request.user)


def can_manage_book(book, user) -> bool:
    """True if ``user`` may edit/manage ``book``: a platform admin, the creator,
    or the attributed author."""
    if is_platform_admin(user):
        return True
    return bool(
        (book.created_by_id is not None and book.created_by_id == user.id)
        or (book.author_id is not None and book.author_id == user.id)
    )
