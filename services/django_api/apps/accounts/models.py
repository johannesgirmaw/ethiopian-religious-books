import datetime
import hashlib
import hmac
import secrets
import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone
from django.utils.crypto import constant_time_compare


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = None
    email = models.EmailField(unique=True)
    role = models.CharField(
        max_length=20,
        choices=[("reader", "reader"), ("author", "author"), ("admin", "admin")],
        default="reader",
    )
    display_name = models.CharField(max_length=255, blank=True)
    preferred_ui_language = models.CharField(max_length=10, default="en")
    deleted_at = models.DateTimeField(null=True, blank=True)

    # Telegram / phone identity (optional; email+password remains primary).
    phone = models.CharField(max_length=20, unique=True, null=True, blank=True)
    phone_verified_at = models.DateTimeField(null=True, blank=True)
    telegram_user_id = models.BigIntegerField(unique=True, null=True, blank=True)
    telegram_chat_id = models.BigIntegerField(null=True, blank=True)
    telegram_username = models.CharField(max_length=64, blank=True, default="")
    telegram_linked_at = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    objects = UserManager()

    class Meta:
        db_table = "users"

    @property
    def telegram_linked(self) -> bool:
        return self.telegram_user_id is not None and self.telegram_chat_id is not None


class UserDevice(models.Model):
    """A device a user has registered for hardware-bound offline reading.

    Stores the device's public key so the server can wrap per-book content keys to
    a specific device (the matching private key never leaves the device's secure
    enclave/keystore). One row per (user, device_id); registering again rotates the
    stored key. Removing the row revokes that device's ability to receive new
    wrapped keys.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="devices",
    )
    device_id = models.CharField(max_length=128)
    public_key = models.TextField(
        blank=True,
        help_text="PEM/base64 device public key used to wrap content keys.",
    )
    platform = models.CharField(max_length=40, blank=True)
    label = models.CharField(max_length=120, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_devices"
        ordering = ["-last_seen"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "device_id"], name="uniq_user_device"
            ),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.device_id}"


class PasswordResetCode(models.Model):
    """A short-lived, single-use code to reset a password (email or Telegram).

    The raw 6-digit code is never stored: only an HMAC (keyed with ``SECRET_KEY``)
    is persisted, so a database leak does not expose live codes. Each code expires
    quickly, allows a small number of verification attempts, and is consumed on
    first successful use. Issuing a new code retires any outstanding ones for the
    same user.
    """

    class Channel(models.TextChoices):
        EMAIL = "email", "email"
        TELEGRAM = "telegram", "telegram"

    class Purpose(models.TextChoices):
        PASSWORD_RESET = "password_reset", "password_reset"

    CODE_TTL = datetime.timedelta(minutes=15)
    MAX_ATTEMPTS = 5
    RESEND_COOLDOWN = datetime.timedelta(seconds=60)

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="password_reset_codes",
    )
    code_hash = models.CharField(max_length=64)
    channel = models.CharField(
        max_length=16,
        choices=Channel.choices,
        default=Channel.EMAIL,
    )
    purpose = models.CharField(
        max_length=32,
        choices=Purpose.choices,
        default=Purpose.PASSWORD_RESET,
    )
    attempts = models.PositiveSmallIntegerField(default=0)
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)
    requested_ip = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "password_reset_codes"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "consumed_at"]),
        ]

    def __str__(self):
        return f"reset:{self.user_id}:{self.created_at:%Y-%m-%d %H:%M}"

    # --- crypto helpers -------------------------------------------------------

    @staticmethod
    def hash_code(raw_code: str) -> str:
        return hmac.new(
            settings.SECRET_KEY.encode("utf-8"),
            raw_code.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    @classmethod
    def generate_raw_code(cls) -> str:
        # Cryptographically-random, zero-padded 6-digit code.
        return f"{secrets.randbelow(1_000_000):06d}"

    @classmethod
    def issue(
        cls,
        user,
        *,
        ip: str | None = None,
        channel: str = Channel.EMAIL,
        purpose: str = Purpose.PASSWORD_RESET,
    ) -> tuple["PasswordResetCode", str]:
        """Create and persist a new code for ``user``; returns (row, raw_code)."""
        raw_code = cls.generate_raw_code()
        obj = cls.objects.create(
            user=user,
            code_hash=cls.hash_code(raw_code),
            channel=channel,
            purpose=purpose,
            expires_at=timezone.now() + cls.CODE_TTL,
            requested_ip=ip,
        )
        return obj, raw_code

    # --- state ----------------------------------------------------------------

    @property
    def is_consumed(self) -> bool:
        return self.consumed_at is not None

    def is_expired(self, *, now: datetime.datetime | None = None) -> bool:
        return (now or timezone.now()) >= self.expires_at

    @property
    def attempts_exhausted(self) -> bool:
        return self.attempts >= self.MAX_ATTEMPTS

    def is_usable(self, *, now: datetime.datetime | None = None) -> bool:
        return (
            not self.is_consumed
            and not self.is_expired(now=now)
            and not self.attempts_exhausted
        )

    def verify(self, raw_code: str) -> bool:
        return constant_time_compare(self.code_hash, self.hash_code(raw_code))


class TelegramAuthSession(models.Model):
    """Persisted deep-link session for Telegram bot OTP (login / link).

    Flow: initiate → user opens ``t.me/bot?start=<id>`` → contact share →
    hashed OTP delivered via Bot API → client verifies.
    """

    class Purpose(models.TextChoices):
        LOGIN = "login", "login"
        PHONE_LINK = "phone_link", "phone_link"
        PASSWORD_RESET = "password_reset", "password_reset"

    class Status(models.TextChoices):
        PENDING = "pending", "pending"
        AWAITING_CONTACT = "awaiting_contact", "awaiting_contact"
        CODE_SENT = "code_sent", "code_sent"
        VERIFIED = "verified", "verified"
        EXPIRED = "expired", "expired"

    SESSION_TTL = datetime.timedelta(minutes=15)
    CODE_TTL = datetime.timedelta(minutes=10)
    MAX_ATTEMPTS = 5
    RESEND_COOLDOWN = datetime.timedelta(seconds=60)
    INITIATE_COOLDOWN = datetime.timedelta(seconds=60)

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20)
    purpose = models.CharField(max_length=32, choices=Purpose.choices)
    status = models.CharField(
        max_length=32,
        choices=Status.choices,
        default=Status.PENDING,
    )
    # Set for authenticated "link Telegram" flows.
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="telegram_auth_sessions",
    )
    telegram_user_id = models.BigIntegerField(null=True, blank=True)
    telegram_chat_id = models.BigIntegerField(null=True, blank=True)
    telegram_username = models.CharField(max_length=64, blank=True, default="")
    code_hash = models.CharField(max_length=64, blank=True, default="")
    attempts = models.PositiveSmallIntegerField(default=0)
    expires_at = models.DateTimeField()
    code_expires_at = models.DateTimeField(null=True, blank=True)
    consumed_at = models.DateTimeField(null=True, blank=True)
    requested_ip = models.GenericIPAddressField(null=True, blank=True)
    # Where to send the user after Confirm my phone (local localhost or prod app URL).
    client_return_url = models.CharField(max_length=512, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "telegram_auth_sessions"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["phone", "status"], name="tg_auth_phone_status"),
            models.Index(
                fields=["telegram_chat_id", "status"], name="tg_auth_chat_status"
            ),
            models.Index(fields=["expires_at"], name="tg_auth_expires"),
        ]

    def __str__(self):
        return f"tg:{self.purpose}:{self.phone}:{self.status}"

    @classmethod
    def hash_code(cls, raw_code: str) -> str:
        return PasswordResetCode.hash_code(raw_code)

    @classmethod
    def generate_raw_code(cls) -> str:
        return PasswordResetCode.generate_raw_code()

    def is_expired(self, *, now: datetime.datetime | None = None) -> bool:
        return (now or timezone.now()) >= self.expires_at

    def code_is_usable(self, *, now: datetime.datetime | None = None) -> bool:
        now = now or timezone.now()
        return (
            self.status == self.Status.CODE_SENT
            and self.consumed_at is None
            and self.code_hash
            and self.code_expires_at is not None
            and now < self.code_expires_at
            and self.attempts < self.MAX_ATTEMPTS
            and not self.is_expired(now=now)
        )

    def verify_code(self, raw_code: str) -> bool:
        if not self.code_hash:
            return False
        return constant_time_compare(self.code_hash, self.hash_code(raw_code))
