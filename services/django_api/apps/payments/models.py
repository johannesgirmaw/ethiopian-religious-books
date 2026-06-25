import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models

from apps.catalog.models import Book
from apps.payments.crypto import decrypt, encrypt
from apps.payments.enums import PaymentMethod, TransactionStatus


class PlatformSettings(models.Model):
    """Singleton holding feature toggles and the default commission.

    Use :meth:`get_solo` everywhere instead of querying directly so a row always
    exists with sensible defaults.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Payment-gateway feature toggles.
    stripe_enabled = models.BooleanField(default=False)
    paypal_enabled = models.BooleanField(default=False)
    telebirr_enabled = models.BooleanField(default=False)
    manual_payment_enabled = models.BooleanField(default=True)

    # Commission configuration.
    default_commission_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=Decimal("10.00")
    )
    allow_author_override = models.BooleanField(default=True)
    allow_book_override = models.BooleanField(default=True)

    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "platform_settings"
        verbose_name = "Platform settings"
        verbose_name_plural = "Platform settings"

    def __str__(self):
        return "Platform settings"

    @classmethod
    def get_solo(cls) -> "PlatformSettings":
        obj = cls.objects.order_by("updated_at").first()
        if obj is None:
            obj = cls.objects.create()
        return obj

    def enabled_methods(self) -> list[str]:
        methods: list[str] = []
        if self.stripe_enabled:
            methods.append(PaymentMethod.STRIPE)
        if self.paypal_enabled:
            methods.append(PaymentMethod.PAYPAL)
        if self.telebirr_enabled:
            methods.append(PaymentMethod.TELEBIRR)
        if self.manual_payment_enabled:
            methods.append(PaymentMethod.BANK_TRANSFER)
        return methods

    def is_method_enabled(self, method: str) -> bool:
        return method in set(self.enabled_methods())


class GatewayCredential(models.Model):
    """Encrypted credentials for an online payment gateway.

    The secret is stored Fernet-encrypted (:mod:`apps.payments.crypto`); the
    plaintext is only ever exposed in-process through :meth:`secret`.
    """

    class Provider(models.TextChoices):
        STRIPE = PaymentMethod.STRIPE, "Stripe"
        PAYPAL = PaymentMethod.PAYPAL, "PayPal"
        TELEBIRR = PaymentMethod.TELEBIRR, "Telebirr"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.CharField(max_length=20, choices=Provider.choices, unique=True)
    public_key = models.CharField(
        max_length=500, blank=True, help_text="Publishable/client key (not secret)."
    )
    encrypted_secret = models.TextField(blank=True)
    webhook_secret_encrypted = models.TextField(blank=True)
    extra = models.JSONField(default=dict, blank=True)
    is_active = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "gateway_credentials"

    def __str__(self):
        return f"{self.get_provider_display()} credentials"

    def set_secret(self, plaintext: str) -> None:
        self.encrypted_secret = encrypt(plaintext or "")

    def secret(self) -> str:
        return decrypt(self.encrypted_secret)

    def set_webhook_secret(self, plaintext: str) -> None:
        self.webhook_secret_encrypted = encrypt(plaintext or "")

    def webhook_secret(self) -> str:
        return decrypt(self.webhook_secret_encrypted)

    @property
    def is_configured(self) -> bool:
        return bool(self.is_active and self.encrypted_secret)


class AuthorCommission(models.Model):
    """Per-author override of the platform default commission."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    author = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="author_commission",
    )
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "author_commissions"
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.author_id}: {self.commission_percent}%"


class AuthorProfile(models.Model):
    """Publishing identity and payout details for a user with the author role."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="author_profile",
    )
    pen_name = models.CharField(max_length=255, blank=True)
    bio = models.TextField(blank=True)
    photo_url = models.URLField(blank=True)
    phone = models.CharField(max_length=40, blank=True)
    country = models.CharField(max_length=80, blank=True)
    payment_email = models.EmailField(blank=True)
    telebirr_number = models.CharField(max_length=40, blank=True)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "author_profiles"
        ordering = ["pen_name"]

    def __str__(self):
        return self.pen_name or str(self.user_id)


class Bank(models.Model):
    """Bank account used for the manual bank-transfer flow. Admin managed."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    code = models.CharField(max_length=40, blank=True)
    account_name = models.CharField(max_length=200)
    account_number = models.CharField(max_length=80)
    logo_url = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "banks"
        ordering = ["name"]

    def __str__(self):
        return self.name


class PaymentTransaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="payment_transactions",
    )
    book = models.ForeignKey(Book, on_delete=models.PROTECT, related_name="transactions")
    # Only set for the manual bank-transfer flow.
    bank = models.ForeignKey(
        Bank,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="transactions",
    )

    currency = models.CharField(max_length=3, default="USD")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    commission_amount = models.DecimalField(
        max_digits=12, decimal_places=2, default=Decimal("0.00")
    )

    payment_method = models.CharField(max_length=20, choices=PaymentMethod.choices)
    status = models.CharField(
        max_length=20,
        choices=TransactionStatus.choices,
        default=TransactionStatus.PENDING,
    )

    # User-entered reference (manual flow) — also used for duplicate detection.
    transaction_reference = models.CharField(max_length=120, blank=True)
    # Gateway-issued id (Stripe/PayPal/Telebirr) for online flows.
    gateway_reference = models.CharField(max_length=255, blank=True)
    # Object key of the uploaded receipt; a signed URL is exposed via the API.
    receipt_object_key = models.CharField(max_length=500, blank=True)

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_transactions",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_note = models.CharField(max_length=500, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "payment_transactions"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="idx_txn_user_created"),
            models.Index(fields=["status", "-created_at"], name="idx_txn_status_created"),
        ]
        constraints = [
            # Duplicate-transaction prevention: a given (method, reference) pair
            # can only be recorded once. The condition lets multiple rows share
            # an empty reference (e.g. freshly-created online checkouts).
            models.UniqueConstraint(
                fields=["payment_method", "transaction_reference"],
                condition=~models.Q(transaction_reference=""),
                name="uniq_method_reference",
            ),
        ]

    def __str__(self):
        return f"{self.payment_method} {self.amount} {self.currency} ({self.status})"

    @property
    def author_amount(self) -> Decimal:
        return (self.amount or Decimal("0")) - (self.commission_amount or Decimal("0"))


class RevenueLedger(models.Model):
    """Source of truth for reporting. One row per COMPLETED transaction."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    transaction = models.OneToOneField(
        PaymentTransaction,
        on_delete=models.CASCADE,
        related_name="ledger_entry",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="revenue_entries",
    )
    book = models.ForeignKey(Book, on_delete=models.PROTECT, related_name="revenue_entries")

    currency = models.CharField(max_length=3, default="USD")
    sale_amount = models.DecimalField(max_digits=12, decimal_places=2)
    commission_amount = models.DecimalField(max_digits=12, decimal_places=2)
    author_amount = models.DecimalField(max_digits=12, decimal_places=2)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "revenue_ledger"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["author", "-created_at"], name="idx_ledger_author"),
            models.Index(fields=["book", "-created_at"], name="idx_ledger_book"),
        ]

    def __str__(self):
        return f"Ledger {self.sale_amount} {self.currency}"


class AuditLog(models.Model):
    """Immutable trail of sensitive payment/admin actions."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="payment_audit_logs",
    )
    action = models.CharField(max_length=80)
    target_type = models.CharField(max_length=80, blank=True)
    target_id = models.CharField(max_length=80, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "payment_audit_logs"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["action", "-created_at"], name="idx_audit_action"),
        ]

    def __str__(self):
        return f"{self.action} by {self.actor_id} @ {self.created_at:%Y-%m-%d %H:%M}"
