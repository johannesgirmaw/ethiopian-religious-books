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
