"""Symmetric encryption for stored gateway credentials.

Credentials (Stripe/PayPal/Telebirr secret keys) must never be persisted in
plaintext. We use Fernet (AES-128-CBC + HMAC) from the ``cryptography`` package
that already ships via ``djangorestframework-simplejwt[crypto]``.

The key is taken from ``settings.PAYMENTS_FERNET_KEY`` when provided, otherwise
it is derived deterministically from ``SECRET_KEY`` so local/dev works without
extra configuration. In production set ``PAYMENTS_FERNET_KEY`` to a stable,
secret value (``Fernet.generate_key()``) so rotating ``SECRET_KEY`` does not
make existing credentials unreadable.
"""

from __future__ import annotations

import base64
import hashlib

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings


def _fernet() -> Fernet:
    configured = (getattr(settings, "PAYMENTS_FERNET_KEY", "") or "").strip()
    if configured:
        key = configured.encode("utf-8")
    else:
        digest = hashlib.sha256(settings.SECRET_KEY.encode("utf-8")).digest()
        key = base64.urlsafe_b64encode(digest)
    return Fernet(key)


def encrypt(plaintext: str) -> str:
    """Return a URL-safe ciphertext token for ``plaintext`` (empty -> empty)."""
    if not plaintext:
        return ""
    return _fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt(token: str) -> str:
    """Reverse :func:`encrypt`. Returns "" for empty or unreadable tokens."""
    if not token:
        return ""
    try:
        return _fernet().decrypt(token.encode("utf-8")).decode("utf-8")
    except (InvalidToken, ValueError):
        return ""
