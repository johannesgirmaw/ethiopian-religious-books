from __future__ import annotations

import logging
import uuid
from typing import Any

from botocore.exceptions import ClientError
from django.db import transaction
from django.db.models import Max, Q
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.admin_serializers import (
    AdminBookCreateSerializer,
    AdminBookPatchSerializer,
    AdminBookSerializer,
    AdminPublishSerializer,
    AdminRevisionCompleteSerializer,
    AdminRevisionCreateSerializer,
)
from apps.catalog.models import Book, BookRevision
from apps.catalog.permissions import IsPublisherAdmin
from apps.catalog.publishing import publish_book, unpublish_book, validate_draft_warnings
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.storage_s3 import head_object, presign_put, put_bytes

logger = logging.getLogger(__name__)


class AdminBooksRootView(APIView):
    permission_classes = [IsPublisherAdmin]

    def get(self, request):
        limit = min(int(request.query_params.get("limit", 50)), 100)
        offset = int(request.query_params.get("offset", 0))
        visibility = request.query_params.get("visibility")
        query = request.query_params.get("query") or request.query_params.get("q")
        qs = Book.objects.all().order_by("-updated_at")
        if visibility:
            qs = qs.filter(catalog_visibility=visibility)
        if query:
            normalized = normalize_search_text(query)
            qs = qs.filter(
                Q(search_text_normalized__contains=normalized)
                | Q(title__icontains=query)
                | Q(author_compiler__icontains=query)
                | Q(subtitle__icontains=query)
                | Q(summary__icontains=query)
            )
        total = qs.count()
        items = qs[offset : offset + limit]
        return Response(
            {
                "items": AdminBookSerializer(items, many=True).data,
                "total": total,
                "next_cursor": None,
            }
        )

    def post(self, request):
        ser = AdminBookCreateSerializer(data=request.data, context={"request": request})
        ser.is_valid(raise_exception=True)
        book = ser.save()
        return Response(AdminBookSerializer(book).data, status=status.HTTP_201_CREATED)


class AdminBookDetailView(APIView):
    permission_classes = [IsPublisherAdmin]

    def get(self, request, book_id):
        del request
        book = get_object_or_404(Book, pk=book_id)
        return Response(AdminBookSerializer(book).data)

    def patch(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        ser = AdminBookPatchSerializer(book, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(AdminBookSerializer(book).data)


_ALLOWED_COVER_TYPES = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


class AdminBookCoverPresignView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        content_type = (request.data.get("content_type") or "image/jpeg").strip().lower()
        if content_type not in _ALLOWED_COVER_TYPES:
            return Response(
                {
                    "error": {
                        "code": "INVALID_CONTENT_TYPE",
                        "message": "Use image/jpeg, image/png, or image/webp.",
                    }
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        ext = _ALLOWED_COVER_TYPES[content_type]
        object_key = f"books/{book.id}/covers/{uuid.uuid4()}.{ext}"
        try:
            put_url = presign_put(object_key, content_type=content_type)
        except Exception as exc:
            logger.exception("cover presign failed: %s", exc)
            return Response(
                {
                    "error": {
                        "code": "PRESIGN_FAILED",
                        "message": "Could not create upload URL.",
                    }
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response({"object_key": object_key, "put_url": put_url})


class AdminBookDraftValidationView(APIView):
    permission_classes = [IsPublisherAdmin]

    def get(self, request, book_id):
        del request
        book = get_object_or_404(Book, pk=book_id)
        chapters_draft = book.chapters_draft if isinstance(book.chapters_draft, list) else []
        return Response(validate_draft_warnings(chapters_draft))


def _pick_paths(files: list[dict[str, Any]]) -> tuple[str, str | None]:
    paths = [f.get("path") or "" for f in files]
    if "manifest.json" in paths:
        manifest = "manifest.json"
    else:
        manifest = paths[0] if paths else "manifest.json"
    content: str | None
    if "content.enc" in paths:
        content = "content.enc"
    elif len(paths) > 1:
        content = next((p for p in paths if p != manifest), None)
    else:
        content = None
    return manifest, content


class AdminRevisionCreateView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        ser = AdminRevisionCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data
        files = data["files"]
        manifest_rel, content_rel = _pick_paths(files)

        with transaction.atomic():
            last = book.revisions.aggregate(m=Max("revision_number"))["m"] or 0
            rev = BookRevision.objects.create(
                book=book,
                revision_number=last + 1,
                status=BookRevision.Status.DRAFT,
                content_format=data.get("content_format") or "html_chunks",
                created_by=request.user,
            )
            prefix = f"books/{book.id}/{rev.id}"
            rev.manifest_object_key = f"{prefix}/{manifest_rel}"
            rev.content_object_key = f"{prefix}/{content_rel}" if content_rel else ""
            rev.save(update_fields=["manifest_object_key", "content_object_key"])

        upload: dict[str, Any] = {
            "manifest_put_url": presign_put(
                rev.manifest_object_key,
                content_type="application/json",
            ),
            "parts": [],
        }
        if rev.content_object_key:
            upload["parts"].append(
                {
                    "path": content_rel,
                    "put_url": presign_put(
                        rev.content_object_key,
                        content_type="application/octet-stream",
                    ),
                    "headers": {"Content-Type": "application/octet-stream"},
                }
            )
        return Response(
            {"revision_id": str(rev.id), "upload": upload},
            status=status.HTTP_201_CREATED,
        )


class AdminRevisionCompleteView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id, revision_id):
        book = get_object_or_404(Book, pk=book_id)
        rev = get_object_or_404(BookRevision, pk=revision_id, book=book)
        ser = AdminRevisionCompleteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        extra = ser.validated_data

        total = 0
        try:
            if rev.manifest_object_key:
                h = head_object(rev.manifest_object_key)
                total += int(h["ContentLength"])
            if rev.content_object_key:
                h = head_object(rev.content_object_key)
                total += int(h["ContentLength"])
        except ClientError as exc:
            logger.warning("revision complete HEAD failed: %s", exc)
            return Response(
                {"error": {"code": "OBJECTS_MISSING", "message": "Upload objects not found or incomplete."}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if extra.get("manifest_sha256"):
            rev.manifest_sha256 = extra["manifest_sha256"].strip()
        if extra.get("content_sha256"):
            rev.content_sha256 = extra["content_sha256"].strip()
        rev.total_bytes = total
        rev.save(update_fields=["total_bytes", "manifest_sha256", "content_sha256"])
        return Response({"status": "draft_validated"})


class AdminBookPublishView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        ser = AdminPublishSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        outcome = publish_book(book, request.user, ser.validated_data.get("revision_id"))
        if not outcome.ok:
            return Response(outcome.error, status=outcome.status_code)
        return Response(AdminBookSerializer(outcome.book).data)


class AdminBookUnpublishView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id):
        del request
        book = get_object_or_404(Book, pk=book_id)
        unpublish_book(book)
        return Response(status=status.HTTP_204_NO_CONTENT)
