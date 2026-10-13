"""Catalog Celery tasks (PDF linearization backfill helpers)."""

from __future__ import annotations

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task
def linearize_pdf_revision_task(revision_id: str, *, force: bool = False) -> dict:
    """Linearize one PDF revision's content object (async backfill helper)."""
    from apps.catalog.models import BookRevision
    from apps.catalog.pdf_books import (
        PdfBookError,
        is_pdf_revision,
        linearize_pdf_object,
    )

    try:
        rev = BookRevision.objects.get(pk=revision_id)
    except BookRevision.DoesNotExist:
        return {"ok": False, "error": "not_found"}

    if not is_pdf_revision(rev) or not rev.content_object_key:
        return {"ok": False, "error": "not_pdf"}

    try:
        size, digest, linearized = linearize_pdf_object(
            rev.content_object_key, force=force
        )
    except PdfBookError as exc:
        logger.warning("linearize task failed for %s: %s", revision_id, exc.code)
        return {"ok": False, "error": exc.code}

    update_fields: list[str] = []
    if rev.total_bytes != size:
        rev.total_bytes = size
        update_fields.append("total_bytes")
    if rev.content_sha256 != digest:
        rev.content_sha256 = digest
        update_fields.append("content_sha256")
    if update_fields:
        rev.save(update_fields=update_fields)
    return {
        "ok": True,
        "size_bytes": size,
        "sha256": digest,
        "linearized": linearized,
    }
