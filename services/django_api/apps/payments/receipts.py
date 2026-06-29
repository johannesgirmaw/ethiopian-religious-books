"""Validation and storage for manually-uploaded payment receipts.

Receipts are written through Django's ``default_storage`` so the same code works
with the local filesystem (dev/tests) and any configured remote backend. We
validate by extension, declared content type, real size and magic bytes so a
mislabelled or oversized file is rejected before it is ever stored.
"""

from __future__ import annotations

import logging
import uuid

from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from rest_framework import serializers

from apps.catalog.storage_s3 import (
    get_object_bytes,
    is_object_storage_configured,
    put_bytes,
)

logger = logging.getLogger(__name__)

MAX_RECEIPT_BYTES = 10 * 1024 * 1024  # 10 MB

# extension -> (allowed content types, magic-byte prefixes)
_ALLOWED = {
    "jpg": (("image/jpeg",), (b"\xff\xd8\xff",)),
    "jpeg": (("image/jpeg",), (b"\xff\xd8\xff",)),
    "png": (("image/png",), (b"\x89PNG\r\n\x1a\n",)),
    "pdf": (("application/pdf",), (b"%PDF-",)),
}

_CONTENT_TYPES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "pdf": "application/pdf",
}


def _extension(filename: str) -> str:
    return (filename.rsplit(".", 1)[-1] if "." in filename else "").lower()


def validate_receipt(upload) -> bytes:
    """Validate an uploaded receipt and return its raw bytes.

    Raises ``serializers.ValidationError`` on any problem (missing file, bad
    type/extension, too large, content not matching its claimed type).
    """
    if upload is None:
        raise serializers.ValidationError("A receipt file is required.")

    ext = _extension(getattr(upload, "name", "") or "")
    if ext not in _ALLOWED:
        raise serializers.ValidationError(
            "Unsupported file type. Allowed: JPG, PNG, PDF."
        )

    size = getattr(upload, "size", None)
    if size is not None and size > MAX_RECEIPT_BYTES:
        raise serializers.ValidationError("Receipt exceeds the 10MB limit.")

    data = upload.read()
    if len(data) > MAX_RECEIPT_BYTES:
        raise serializers.ValidationError("Receipt exceeds the 10MB limit.")
    if not data:
        raise serializers.ValidationError("Receipt file is empty.")

    allowed_types, magic_prefixes = _ALLOWED[ext]
    content_type = (getattr(upload, "content_type", "") or "").lower()
    if content_type and content_type not in allowed_types:
        raise serializers.ValidationError("File content type does not match a receipt.")
    if not any(data.startswith(prefix) for prefix in magic_prefixes):
        raise serializers.ValidationError(
            "File content does not match its extension."
        )

    return data


def store_receipt(transaction_id, upload) -> str:
    """Validate and persist a receipt; return its stored object key.

    Uses object storage (S3/MinIO) when configured — the same durable backend as
    book covers — so receipts survive restarts/redeploys. Falls back to Django's
    ``default_storage`` (local filesystem) only when object storage is not set up
    (e.g. a bare local dev box).
    """
    data = validate_receipt(upload)
    ext = _extension(getattr(upload, "name", "") or "")
    object_key = f"receipts/{transaction_id}/{uuid.uuid4().hex}.{ext}"
    if is_object_storage_configured():
        put_bytes(object_key, data, content_type=receipt_content_type(object_key))
        return object_key
    return default_storage.save(object_key, ContentFile(data))


def receipt_content_type(object_key: str) -> str:
    return _CONTENT_TYPES.get(_extension(object_key), "application/octet-stream")


def read_receipt(object_key: str) -> bytes:
    """Read a stored receipt's bytes from whichever backend holds it."""
    if not object_key:
        return b""
    if is_object_storage_configured():
        try:
            return get_object_bytes(object_key)
        except Exception as exc:  # noqa: BLE001 - any storage error -> empty
            logger.warning("receipt fetch failed for %s: %s", object_key, exc)
            return b""
    if default_storage.exists(object_key):
        with default_storage.open(object_key, "rb") as fh:
            return fh.read()
    return b""
