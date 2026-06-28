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

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    objects = UserManager()

    class Meta:
        db_table = "users"


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
    """A short-lived, single-use code emailed to a user to reset their password.

    The raw 6-digit code is never stored: only an HMAC (keyed with ``SECRET_KEY``)
    is persisted, so a database leak does not expose live codes. Each code expires
    quickly, allows a small number of verification attempts, and is consumed on
    first successful use. Issuing a new code retires any outstanding ones for the
    same user.
    """

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
    def issue(cls, user, *, ip: str | None = None) -> tuple["PasswordResetCode", str]:
        """Create and persist a new code for ``user``; returns (row, raw_code)."""
        raw_code = cls.generate_raw_code()
        obj = cls.objects.create(
            user=user,
            code_hash=cls.hash_code(raw_code),
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
