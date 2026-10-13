"""Shared payment enums.

Kept in a dedicated module so models, serializers, gateways and tests import the
same source of truth without circular imports.
"""

from django.db import models


class PaymentMethod(models.TextChoices):
    STRIPE = "stripe", "Stripe"
    PAYPAL = "paypal", "PayPal"
    TELEBIRR = "telebirr", "Telebirr"
    BANK_TRANSFER = "bank_transfer", "Bank transfer"


# Payment methods that are settled through a third-party gateway (vs. the manual
# bank-transfer flow that is reviewed by an admin).
ONLINE_METHODS = frozenset(
    {PaymentMethod.STRIPE, PaymentMethod.PAYPAL, PaymentMethod.TELEBIRR}
)
MANUAL_METHODS = frozenset({PaymentMethod.BANK_TRANSFER})


class TransactionStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    ON_REVIEW = "on_review", "On review"
    APPROVED = "approved", "Approved"
    COMPLETED = "completed", "Completed"
    CANCELLED = "cancelled", "Cancelled"
    REJECTED = "rejected", "Rejected"


# Statuses past which a transaction can no longer be edited / re-submitted.
TERMINAL_STATUSES = frozenset(
    {
        TransactionStatus.COMPLETED,
        TransactionStatus.CANCELLED,
        TransactionStatus.REJECTED,
    }
)

# At most one of these may exist per (buyer, book). A new checkout must resume
# the pending row or be refused while a review / completed purchase exists.
ACTIVE_PURCHASE_STATUSES = frozenset(
    {
        TransactionStatus.PENDING,
        TransactionStatus.ON_REVIEW,
        TransactionStatus.APPROVED,
        TransactionStatus.COMPLETED,
    }
)

# The buyer may withdraw a checkout that has not been granted yet:
# pending = started, receipt not submitted; on_review = waiting for approval.
BUYER_CANCELLABLE_STATUSES = frozenset(
    {
        TransactionStatus.PENDING,
        TransactionStatus.ON_REVIEW,
    }
)


class AuthorApplicationStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


# An approved application is final (the user is already an author); a rejected
# one stays re-submittable so the applicant can fix and try again.
AUTHOR_APP_TERMINAL_STATUSES = frozenset({AuthorApplicationStatus.APPROVED})
