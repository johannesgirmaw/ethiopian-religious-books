"""S3-compatible storage (MinIO in dev)."""

from __future__ import annotations

import hashlib
import logging
from typing import Any

import boto3
from botocore.client import Config
from django.conf import settings

logger = logging.getLogger(__name__)


def _client_config() -> Config:
    return Config(
        signature_version="s3v4",
        s3={"addressing_style": settings.AWS_S3_ADDRESSING_STYLE},
    )


def get_s3_client(*, for_presign: bool = False) -> Any:
    """Internal API calls use AWS_S3_ENDPOINT_URL; presigned URLs use PRESIGN endpoint when set."""
    endpoint = settings.AWS_S3_ENDPOINT_URL or None
    if for_presign:
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
    if not settings.AWS_STORAGE_BUCKET_NAME:
        logger.warning("AWS_STORAGE_BUCKET_NAME not set; skip ensure_bucket")
        return
    if not settings.AWS_S3_ENDPOINT_URL:
        logger.warning("AWS_S3_ENDPOINT_URL not set; skip ensure_bucket")
        return
    client = get_s3_client(for_presign=False)
    name = settings.AWS_STORAGE_BUCKET_NAME
    existing = client.list_buckets().get("Buckets", [])
    if any(b["Name"] == name for b in existing):
        return
    client.create_bucket(Bucket=name)
    logger.info("Created bucket %s", name)


def presign_get(object_key: str, expires_in: int = 900) -> str:
    client = get_s3_client(for_presign=True)
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
) -> str:
    client = get_s3_client(for_presign=True)
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


def get_object_bytes(object_key: str) -> bytes:
    client = get_s3_client(for_presign=False)
    obj = client.get_object(Bucket=settings.AWS_STORAGE_BUCKET_NAME, Key=object_key)
    body = obj.get("Body")
    if body is None:
        return b""
    return body.read()
