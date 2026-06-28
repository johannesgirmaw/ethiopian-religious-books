"""Offline-reading licenses (leases).

A license is a signed token that authorizes one device to read one book revision
offline for a bounded window. The client stores it next to the encrypted book and
must renew it (online) before it expires; a refunded/revoked purchase fails
renewal, which is how offline access is ultimately revoked.

Signed with HMAC-SHA256 using a dedicated key so it is independent of the user
JWT signing key. Falls back to a key derived from ``SECRET_KEY`` for dev, mirroring
``apps.payments.crypto``. In production set ``OFFLINE_LICENSE_SIGNING_KEY`` to a
stable secret so rotating ``SECRET_KEY`` does not invalidate live licenses.
"""

from __future__ import annotations

import base64
import datetime
import hashlib
import uuid

import jwt
from django.conf import settings

LICENSE_TYPE = "offline-license"
DEFAULT_LEASE_DAYS = 30


def _signing_key() -> str:
    configured = (getattr(settings, "OFFLINE_LICENSE_SIGNING_KEY", "") or "").strip()
    if configured:
        return configured
    digest = hashlib.sha256(
        ("offline-license:" + settings.SECRET_KEY).encode("utf-8")
    ).digest()
    return base64.urlsafe_b64encode(digest).decode("utf-8")


def lease_days() -> int:
    return int(getattr(settings, "OFFLINE_LICENSE_LEASE_DAYS", DEFAULT_LEASE_DAYS))


def issue_license(*, user_id, book_id, revision_id, device_id: str) -> dict:
    """Return ``{token, expires_at, lease_days}`` for an offline lease."""
    now = datetime.datetime.now(datetime.timezone.utc)
    exp = now + datetime.timedelta(days=lease_days())
    claims = {
        "typ": LICENSE_TYPE,
        "sub": str(user_id),
        "book": str(book_id),
        "rev": str(revision_id),
        "device": device_id or "",
        "iat": int(now.timestamp()),
        "nbf": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(claims, _signing_key(), algorithm="HS256")
    return {
        "token": token,
        "expires_at": exp.isoformat(),
        "lease_days": lease_days(),
    }


def verify_license(token: str) -> dict | None:
    """Return the claims of a valid (signed, unexpired) license, else ``None``."""
    if not token:
        return None
    try:
        claims = jwt.decode(token, _signing_key(), algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    if claims.get("typ") != LICENSE_TYPE:
        return None
    return claims
