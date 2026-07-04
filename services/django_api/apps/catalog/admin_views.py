from __future__ import annotations

import logging
import uuid
from typing import Any

from botocore.exceptions import ClientError
from django.db import transaction
from django.db.models import Max, Q
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.admin_serializers import (
    AdminBookCreateSerializer,
    AdminBookImportDocxPreviewSerializer,
    AdminBookImportDocxSerializer,
    AdminBookPatchSerializer,
    AdminBookSerializer,
    AdminPublishSerializer,
    AdminRevisionCompleteSerializer,
    AdminRevisionCreateSerializer,
)
from apps.catalog.docx_import import (
    DocxImportError,
    build_chapters_draft_from_docx,
    summarize_docx_structure,
)
from apps.catalog.models import Book, BookRevision
from apps.catalog.permissions import (
    IsPublisherOrAuthor,
    can_manage_book,
    is_platform_admin,
)
from apps.catalog.publishing import (
    publish_book,
    unpublish_book,
    validate_bible_draft,
    validate_draft_warnings,
)
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.storage_s3 import head_object, presign_put, put_bytes

logger = logging.getLogger(__name__)


def _not_book_creator_response() -> Response:
    return Response(
        {
            "error": {
                "code": "NOT_BOOK_CREATOR",
                "message": "Only the user who created this book can perform this action.",
            }
        },
        status=status.HTTP_403_FORBIDDEN,
    )


def _user_is_book_creator(book: Book, user) -> bool:
    return book.created_by_id is not None and book.created_by_id == user.id


class AdminBooksRootView(APIView):
    permission_classes = [IsPublisherOrAuthor]

    def get(self, request):
        limit = min(int(request.query_params.get("limit", 50)), 100)
        offset = int(request.query_params.get("offset", 0))
        visibility = request.query_params.get("visibility")
        query = request.query_params.get("query") or request.query_params.get("q")
        qs = Book.objects.all().order_by("-updated_at")
        # Authors only manage their own catalogue; admins see everything.
        if not is_platform_admin(request.user):
            qs = qs.filter(
                Q(created_by=request.user) | Q(author=request.user)
            )
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


# Cap the upload so a stray large file can't exhaust request memory. A 400-page
# text .docx is only a few MB; 25 MB leaves generous headroom.
_MAX_DOCX_BYTES = 25 * 1024 * 1024


def _read_docx_upload(upload):
    """Validate a Word upload and return ``(bytes, error_response)``.

    ``error_response`` is a DRF ``Response`` when the upload is rejected (wrong
    extension, legacy .doc, or too large); otherwise it is ``None`` and ``bytes``
    holds the file content.
    """
    name = (getattr(upload, "name", "") or "").lower()
    if name.endswith(".doc") and not name.endswith(".docx"):
        return None, Response(
            {
                "error": {
                    "code": "LEGACY_DOC_FORMAT",
                    "message": (
                        "This is an older .doc file. Open it in Word and use "
                        "Save As → Word Document (.docx), then upload again."
                    ),
                }
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not name.endswith(".docx"):
        return None, Response(
            {
                "error": {
                    "code": "INVALID_FILE_TYPE",
                    "message": "Upload a Word document with a .docx extension.",
                }
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
    if upload.size and upload.size > _MAX_DOCX_BYTES:
        return None, Response(
            {
                "error": {
                    "code": "FILE_TOO_LARGE",
                    "message": "The document is larger than the 25 MB limit.",
                }
            },
            status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        )
    return upload.read(), None


def _parse_error_response(exc: Exception) -> Response:
    return Response(
        {"error": {"code": "DOCX_PARSE_FAILED", "message": str(exc)}},
        status=status.HTTP_400_BAD_REQUEST,
    )


class AdminBookImportDocxPreviewView(APIView):
    """Dry-run: report the structure detected for every mode, without saving.

    Lets the admin compare detection strategies (and tweak a custom pattern /
    marker) before committing to an import. No database writes.
    """

    permission_classes = [IsPublisherOrAuthor]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        ser = AdminBookImportDocxPreviewSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        raw, error = _read_docx_upload(ser.validated_data["file"])
        if error is not None:
            return error
        try:
            summary = summarize_docx_structure(
                raw,
                pattern=ser.validated_data.get("pattern") or None,
                marker=ser.validated_data.get("marker") or None,
            )
        except (DocxImportError, ValueError) as exc:
            return _parse_error_response(exc)
        return Response(summary)


class AdminBookImportDocxView(APIView):
    """Create a *draft* book from an uploaded Word (.docx) file.

    Parses the document into ``chapters_draft`` using the selected detection
    ``mode`` (see ``apps.catalog.docx_import``), then delegates creation to
    ``AdminBookCreateSerializer`` so validation and author attribution match the
    normal create flow. The book stays hidden so the admin can review
    chapters/pages in the editor before publishing. The uploaded file is parsed
    and discarded -- only the extracted content is persisted.
    """

    permission_classes = [IsPublisherOrAuthor]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        ser = AdminBookImportDocxSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        upload = ser.validated_data["file"]
        name = getattr(upload, "name", "") or ""

        raw, error = _read_docx_upload(upload)
        if error is not None:
            return error

        try:
            chapters_draft, stats = build_chapters_draft_from_docx(
                raw,
                mode=ser.validated_data.get("mode") or "auto",
                pattern=ser.validated_data.get("pattern") or None,
                marker=ser.validated_data.get("marker") or None,
            )
        except (DocxImportError, ValueError) as exc:
            return _parse_error_response(exc)

        if not chapters_draft:
            return Response(
                {
                    "error": {
                        "code": "EMPTY_DOCUMENT",
                        "message": "No readable chapters or text were found in the document.",
                    }
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        title = (ser.validated_data.get("title") or "").strip()
        if not title:
            title = str(chapters_draft[0].get("title") or "").strip()
        if not title:
            title = name.rsplit(".", 1)[0].strip() or "Imported book"

        create_data: dict[str, Any] = {
            "title": title[:500],
            "primary_language": ser.validated_data.get("primary_language") or "am",
            "is_premium": ser.validated_data.get("is_premium", False),
            "chapters_draft": chapters_draft,
        }
        genre = (ser.validated_data.get("genre") or "").strip()
        if genre:
            create_data["genre"] = genre
        author_compiler = (ser.validated_data.get("author_compiler") or "").strip()
        if author_compiler:
            create_data["author_compiler"] = author_compiler

        create = AdminBookCreateSerializer(data=create_data, context={"request": request})
        create.is_valid(raise_exception=True)
        book = create.save()
        logger.info(
            "imported docx book %s via %s: %s chapters, %s pages, %s paragraphs",
            book.id,
            stats.get("strategy_used"),
            stats.get("chapters"),
            stats.get("pages"),
            stats.get("paragraphs"),
        )
        data = AdminBookSerializer(book).data
        data["import_stats"] = stats
        return Response(data, status=status.HTTP_201_CREATED)


class AdminBookDetailView(APIView):
    permission_classes = [IsPublisherOrAuthor]

    def get(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
        return Response(AdminBookSerializer(book).data)

    def patch(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if book.catalog_visibility == Book.Visibility.PUBLISHED:
            return Response(
                {
                    "error": {
                        "code": "BOOK_PUBLISHED",
                        "message": "Unpublish this book before editing.",
                    }
                },
                status=status.HTTP_409_CONFLICT,
            )
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
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
    permission_classes = [IsPublisherOrAuthor]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if book.catalog_visibility == Book.Visibility.PUBLISHED:
            return Response(
                {
                    "error": {
                        "code": "BOOK_PUBLISHED",
                        "message": "Unpublish this book before editing.",
                    }
                },
                status=status.HTTP_409_CONFLICT,
            )
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
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
    permission_classes = [IsPublisherOrAuthor]

    def get(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
        if book.is_bible:
            return Response(validate_bible_draft(book))
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
    permission_classes = [IsPublisherOrAuthor]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
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
    permission_classes = [IsPublisherOrAuthor]

    def post(self, request, book_id, revision_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
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
    permission_classes = [IsPublisherOrAuthor]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
        ser = AdminPublishSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        outcome = publish_book(book, request.user, ser.validated_data.get("revision_id"))
        if not outcome.ok:
            return Response(outcome.error, status=outcome.status_code)
        return Response(AdminBookSerializer(outcome.book).data)


class AdminBookUnpublishView(APIView):
    permission_classes = [IsPublisherOrAuthor]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if not can_manage_book(book, request.user):
            return _not_book_creator_response()
        unpublish_book(book)
        return Response(status=status.HTTP_204_NO_CONTENT)
