"""S3-compatible storage (MinIO in dev)."""

from __future__ import annotations

import hashlib
import ipaddress
import logging
from collections.abc import Iterable
from typing import Any
from urllib.parse import urlparse

import boto3
from botocore.client import Config
from django.conf import settings
from django.http import HttpRequest

logger = logging.getLogger(__name__)


def is_object_storage_configured() -> bool:
    """True when server-side uploads (put_object) are expected to work."""
    return bool(
        (getattr(settings, "AWS_STORAGE_BUCKET_NAME", None) or "").strip()
        and (getattr(settings, "AWS_S3_ENDPOINT_URL", None) or "").strip()
    )


def _client_config() -> Config:
    return Config(
        signature_version="s3v4",
        s3={"addressing_style": settings.AWS_S3_ADDRESSING_STYLE},
    )


def get_s3_client(
    *,
    for_presign: bool = False,
    presign_endpoint_url: str | None = None,
) -> Any:
    """Internal API calls use AWS_S3_ENDPOINT_URL; presigned URLs use PRESIGN endpoint when set."""
    endpoint = settings.AWS_S3_ENDPOINT_URL or None
    if for_presign:
        if presign_endpoint_url:
            endpoint = presign_endpoint_url
        else:
            pe = settings.AWS_S3_PRESIGN_ENDPOINT_URL or settings.AWS_S3_ENDPOINT_URL
            endpoint = pe or None
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID or None,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY or None,
        region_name=settings.AWS_S3_REGION_NAME,
        config=_client_config(),
    )


def ensure_bucket() -> None:
    if not is_object_storage_configured():
        logger.warning("Object storage not fully configured; skip ensure_bucket")
        return
    client = get_s3_client(for_presign=False)
    name = settings.AWS_STORAGE_BUCKET_NAME
    existing = client.list_buckets().get("Buckets", [])
    if any(b["Name"] == name for b in existing):
        return
    client.create_bucket(Bucket=name)
    logger.info("Created bucket %s", name)


def dev_presign_endpoint_from_request(request: HttpRequest) -> str | None:
    """
    DEBUG-only: mobile clients send X-Dev-S3-Origin so presigned MinIO URLs use a host
    the device can reach (same host as API_BASE_URL, MinIO host port, e.g. :19000).
    Ignored when DEBUG is False.
    """
    if not settings.DEBUG:
        return None
    raw = (request.META.get("HTTP_X_DEV_S3_ORIGIN") or "").strip()
    if not raw:
        return None
    parsed = urlparse(raw)
    if parsed.scheme not in ("http", "https"):
        return None
    host = (parsed.hostname or "").lower()
    if not host:
        return None
    port = parsed.port
    if port is None:
        return None
    if host == "localhost":
        host = "127.0.0.1"
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return None
    if not (ip.is_loopback or ip.is_private):
        return None
    return f"{parsed.scheme}://{host}:{port}"


def presign_get(
    object_key: str,
    expires_in: int = 900,
    *,
    presign_endpoint_url: str | None = None,
) -> str:
    client = get_s3_client(for_presign=True, presign_endpoint_url=presign_endpoint_url)
    return client.generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.AWS_STORAGE_BUCKET_NAME, "Key": object_key},
        ExpiresIn=expires_in,
    )


def put_bytes(object_key: str, body: bytes, content_type: str = "application/octet-stream") -> str:
    client = get_s3_client(for_presign=False)
    client.put_object(
        Bucket=settings.AWS_STORAGE_BUCKET_NAME,
        Key=object_key,
        Body=body,
        ContentType=content_type,
    )
    return hashlib.sha256(body).hexdigest()


def presign_put(
    object_key: str,
    expires_in: int = 900,
    content_type: str | None = None,
    *,
    presign_endpoint_url: str | None = None,
) -> str:
    client = get_s3_client(for_presign=True, presign_endpoint_url=presign_endpoint_url)
    params: dict[str, Any] = {
        "Bucket": settings.AWS_STORAGE_BUCKET_NAME,
        "Key": object_key,
    }
    if content_type:
        params["ContentType"] = content_type
    return client.generate_presigned_url(
        "put_object",
        Params=params,
        ExpiresIn=expires_in,
    )


def head_object(object_key: str) -> dict[str, Any]:
    client = get_s3_client(for_presign=False)
    return client.head_object(Bucket=settings.AWS_STORAGE_BUCKET_NAME, Key=object_key)


def delete_objects(object_keys: Iterable[str]) -> None:
    """Best-effort removal of stored blobs (covers, manifests, content packages).

    Used when a draft book is deleted so its objects don't linger in the bucket.
    Storage failures are logged and swallowed: the DB rows are already gone and a
    stray object is harmless, so a bucket hiccup must not fail the request.
    """
    keys = [k for k in object_keys if k]
    if not keys or not is_object_storage_configured():
        return
    client = get_s3_client(for_presign=False)
    for key in keys:
        try:
            client.delete_object(Bucket=settings.AWS_STORAGE_BUCKET_NAME, Key=key)
        except Exception:  # pragma: no cover - storage best effort
            logger.warning("could not delete object %s", key, exc_info=True)


def get_object_bytes(object_key: str) -> bytes:
    client = get_s3_client(for_presign=False)
    obj = client.get_object(Bucket=settings.AWS_STORAGE_BUCKET_NAME, Key=object_key)
    body = obj.get("Body")
    if body is None:
        return b""
    return body.read()
