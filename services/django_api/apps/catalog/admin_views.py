from __future__ import annotations

import json
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
from apps.catalog.search_index import rebuild_revision_index
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.storage_s3 import ensure_bucket, head_object, presign_put, put_bytes

logger = logging.getLogger(__name__)


def _plain_text_from_stored_summary(raw: str | None) -> str:
    if not raw:
        return ""
    text = raw.strip()
    if not text:
        return ""
    try:
        parsed = json.loads(text)
        if isinstance(parsed, list):
            chunks: list[str] = []
            for op in parsed:
                if isinstance(op, dict):
                    insert = op.get("insert")
                    if isinstance(insert, str):
                        chunks.append(insert)
            joined = "".join(chunks).replace("\uFFFC", "").strip()
            if joined:
                return joined
    except Exception:
        pass
    return text.replace("\uFFFC", "").strip()


def _slugify_chapter_key(value: str, fallback_index: int) -> str:
    raw = (value or "").strip().lower()
    slug = []
    for ch in raw:
        if ch.isalnum():
            slug.append(ch)
        elif ch in (" ", "-", "_"):
            slug.append("-")
    joined = "".join(slug).strip("-")
    while "--" in joined:
        joined = joined.replace("--", "-")
    return joined or f"chapter-{fallback_index}"


def _draft_manifest_and_html(book: Book) -> tuple[bytes, bytes]:
    raw = book.chapters_draft if isinstance(book.chapters_draft, list) else []
    chunks: list[dict[str, str]] = []
    html_parts: list[str] = [f"<html><body><h1>{book.title}</h1>"]

    for chapter_index, chapter in enumerate(raw, start=1):
        if not isinstance(chapter, dict):
            continue
        chapter_title = str(chapter.get("title") or f"Chapter {chapter_index}").strip()
        chapter_key = _slugify_chapter_key(str(chapter.get("chapter_key") or chapter_title), chapter_index)
        chunks.append({"id": chapter_key, "title": chapter_title, "path": "content.html"})
        html_parts.append(f'<section data-chapter="{chapter_key}">')
        html_parts.append(f"<h2>{chapter_title}</h2>")

        pages = chapter.get("pages")
        if isinstance(pages, list) and pages:
            for page_index, page in enumerate(pages, start=1):
                if not isinstance(page, dict):
                    continue
                page_number = int(page.get("page_number") or page_index)
                page_title = str(page.get("title") or f"Page {page_number}").strip()
                body = str(page.get("body") or "").strip()
                body_plain = _plain_text_from_stored_summary(body) if body else ""
                html_parts.append(f'<article data-page="{page_number}">')
                html_parts.append(f"<h3>{page_title}</h3>")
                if body_plain:
                    html_parts.append(f"<p>{body_plain}</p>")
                html_parts.append("</article>")
        html_parts.append("</section>")

    if not chunks:
        text = _plain_text_from_stored_summary(book.summary)
        if not text:
            text = f"{book.title}\n\nDraft content generated from book metadata."
        chunks = [{"id": "chapter-1", "title": "Draft", "path": "content.html"}]
        html_parts.append(f"<p>{text}</p>")

    html_parts.append("</body></html>")
    manifest_body = json.dumps(
        {
            "format": "html_chunks",
            "version": 1,
            "chunks": chunks,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    html_body = "".join(html_parts).encode("utf-8")
    return manifest_body, html_body


def _validate_draft_warnings(chapters_draft: list[dict]) -> dict[str, Any]:
    warnings: list[str] = []
    chapter_count = 0
    page_count = 0
    empty_page_count = 0
    seen_chapter_keys: set[str] = set()

    for chapter_index, chapter in enumerate(chapters_draft, start=1):
        if not isinstance(chapter, dict):
            warnings.append(f"Chapter #{chapter_index} is malformed.")
            continue
        chapter_count += 1
        chapter_key = str(chapter.get("chapter_key") or "").strip()
        chapter_title = str(chapter.get("title") or "").strip()
        pages = chapter.get("pages")
        if not chapter_key:
            warnings.append(f"Chapter #{chapter_index} is missing chapter_key.")
        elif chapter_key in seen_chapter_keys:
            warnings.append(f"Duplicate chapter_key: {chapter_key}.")
        else:
            seen_chapter_keys.add(chapter_key)
        if not chapter_title:
            warnings.append(f"Chapter '{chapter_key or chapter_index}' has no title.")
        if not isinstance(pages, list) or not pages:
            warnings.append(f"Chapter '{chapter_key or chapter_index}' has no pages.")
            continue
        seen_page_numbers: set[int] = set()
        for page_idx, page in enumerate(pages, start=1):
            if not isinstance(page, dict):
                warnings.append(f"Chapter '{chapter_key or chapter_index}' page #{page_idx} is malformed.")
                continue
            page_count += 1
            try:
                page_number = int(page.get("page_number"))
            except Exception:
                warnings.append(f"Chapter '{chapter_key or chapter_index}' has a page with invalid page_number.")
                continue
            if page_number in seen_page_numbers:
                warnings.append(
                    f"Chapter '{chapter_key or chapter_index}' has duplicate page_number {page_number}."
                )
            seen_page_numbers.add(page_number)
            body = str(page.get("body") or "").strip()
            if not body:
                empty_page_count += 1
            elif len(body) > 18000:
                warnings.append(
                    f"Chapter '{chapter_key or chapter_index}' page {page_number} has very long content ({len(body)} chars)."
                )

    if chapter_count == 0:
        warnings.append("No chapters found.")
    if page_count == 0:
        warnings.append("No pages found.")

    return {
        "ok": len(warnings) == 0,
        "warnings": warnings,
        "stats": {
            "chapters": chapter_count,
            "pages": page_count,
            "empty_pages": empty_page_count,
        },
    }


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
        return Response(_validate_draft_warnings(chapters_draft))


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

    def _create_draft_from_book(self, book: Book, user) -> BookRevision:
        """
        Create a minimal draft revision from current metadata so admins can publish
        without manual API upload steps in local/editor-first workflows.
        """
        with transaction.atomic():
            last = book.revisions.aggregate(m=Max("revision_number"))["m"] or 0
            rev = BookRevision.objects.create(
                book=book,
                revision_number=last + 1,
                status=BookRevision.Status.DRAFT,
                content_format="html_chunks",
                created_by=user,
            )
            prefix = f"admin/quick_draft/{book.id}/{rev.id}"
            manifest_key = f"{prefix}/manifest.json"
            content_key = f"{prefix}/content.html"

            manifest_body, html_body = _draft_manifest_and_html(book)

            ensure_bucket()
            manifest_sha = put_bytes(manifest_key, manifest_body, "application/json")
            content_sha = put_bytes(content_key, html_body, "text/html")

            rev.manifest_object_key = manifest_key
            rev.content_object_key = content_key
            rev.manifest_sha256 = manifest_sha
            rev.content_sha256 = content_sha
            rev.total_bytes = len(manifest_body) + len(html_body)
            rev.save(
                update_fields=[
                    "manifest_object_key",
                    "content_object_key",
                    "manifest_sha256",
                    "content_sha256",
                    "total_bytes",
                ]
            )
            return rev

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        draft_validation = _validate_draft_warnings(
            book.chapters_draft if isinstance(book.chapters_draft, list) else []
        )
        stats = draft_validation.get("stats") or {}
        if int(stats.get("chapters", 0)) == 0 or int(stats.get("pages", 0)) == 0:
            return Response(
                {
                    "error": {
                        "code": "INVALID_DRAFT",
                        "message": "Cannot publish a draft without chapters and pages.",
                    },
                    "validation": draft_validation,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        ser = AdminPublishSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        rid = ser.validated_data.get("revision_id")
        if rid is not None:
            rev = get_object_or_404(BookRevision, pk=rid, book=book)
        else:
            rev = (
                BookRevision.objects.filter(book=book, status=BookRevision.Status.DRAFT)
                .order_by("-revision_number")
                .first()
            )
            if rev is None:
                try:
                    rev = self._create_draft_from_book(book, request.user)
                except Exception as exc:
                    logger.exception("quick draft generation failed: %s", exc)
                    return Response(
                        {
                            "error": {
                                "code": "NO_DRAFT_REVISION",
                                "message": "No draft revision available to publish, and auto-draft generation failed.",
                            }
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )
        if not rev.manifest_object_key:
            return Response(
                {"error": {"code": "INVALID_REVISION", "message": "Revision has no manifest key."}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            BookRevision.objects.filter(book=book, status=BookRevision.Status.PUBLISHED).update(
                status=BookRevision.Status.SUPERSEDED
            )
            rev.status = BookRevision.Status.PUBLISHED
            rev.save(update_fields=["status"])
            book.published_revision = rev
            book.catalog_visibility = Book.Visibility.PUBLISHED
            book.save()

        try:
            rebuild_revision_index(rev)
        except Exception as exc:
            logger.warning("revision index rebuild failed for %s: %s", rev.id, exc)

        return Response(AdminBookSerializer(book).data)


class AdminBookUnpublishView(APIView):
    permission_classes = [IsPublisherAdmin]

    def post(self, request, book_id):
        del request
        book = get_object_or_404(Book, pk=book_id)
        book.catalog_visibility = Book.Visibility.HIDDEN
        book.published_revision = None
        book.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
