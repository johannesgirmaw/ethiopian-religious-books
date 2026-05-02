import json
import logging

from django.conf import settings
from django.db.models import F, Q
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.etag import catalog_response_extras, compute_catalog_etag
from apps.catalog.models import Book, BookChapter, BookContentIndex, BookPage, BookRevision
from apps.catalog.search_index import ensure_revision_index_from_book_draft
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.serializers import BookListSerializer
from apps.catalog.storage_s3 import dev_presign_endpoint_from_request, head_object, presign_get

logger = logging.getLogger(__name__)


def _encryption_payload(rev: BookRevision) -> dict:
    raw = (rev.cek_wrapped or "").strip()
    if not raw:
        return {"algorithm": "none"}
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return {"algorithm": "AES-256-GCM", "cek": parsed}
    except json.JSONDecodeError:
        pass
    return {
        "algorithm": "AES-256-GCM",
        "cek": {
            "ciphertext": raw,
            "nonce": "",
            "wrapped_by": "server",
        },
    }


def _published_books_queryset():
    return (
        Book.objects.filter(catalog_visibility=Book.Visibility.PUBLISHED)
        .select_related("published_revision")
        .order_by("title")
    )


def _books_response(request, qs):
    etag = compute_catalog_etag(qs)
    inm = request.META.get("HTTP_IF_NONE_MATCH", "").strip()
    if inm and inm == etag:
        return Response(status=status.HTTP_304_NOT_MODIFIED)
    ser = BookListSerializer(qs, many=True, context={"request": request})
    extra = catalog_response_extras()
    data = {
        "items": ser.data,
        "next_cursor": None,
        "catalog_etag": etag,
        **extra,
    }
    resp = Response(data)
    resp["ETag"] = etag
    return resp


def _parse_positive_int(value: str | None) -> int | None:
    if not value:
        return None
    try:
        parsed = int(value)
    except ValueError:
        return None
    return parsed if parsed > 0 else None


def _apply_catalog_filters(qs, request):
    chapter = (request.query_params.get("chapter") or "").strip()
    page = _parse_positive_int(request.query_params.get("page"))
    if chapter:
        qs = qs.filter(
            content_index_rows__revision_id=F("published_revision_id"),
            content_index_rows__chapter_key=chapter,
        )
    if page is not None:
        qs = qs.filter(
            content_index_rows__revision_id=F("published_revision_id"),
            content_index_rows__page_number=page,
        )
    return qs.distinct()


class BookListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = _published_books_queryset()
        if settings.FEATURE_BOOK_CONTENT_INDEX:
            qs = _apply_catalog_filters(qs, request)
        query = request.query_params.get("query") or request.query_params.get("q")
        if query:
            if settings.FEATURE_CATALOG_TOLERANT_SEARCH:
                normalized_query = normalize_search_text(query)
                qs = qs.filter(
                    Q(search_text_normalized__contains=normalized_query)
                    | Q(title__icontains=query)
                    | Q(author_compiler__icontains=query)
                    | Q(subtitle__icontains=query)
                    | Q(summary__icontains=query)
                )
            else:
                qs = qs.filter(Q(title__icontains=query) | Q(author_compiler__icontains=query))
            ser = BookListSerializer(qs, many=True, context={"request": request})
            data = {"items": ser.data, "next_cursor": None, **catalog_response_extras()}
            return Response(data)
        return _books_response(request, qs)


class SyncCatalogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = _published_books_queryset()
        return _books_response(request, qs)


class BookDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        ser = BookListSerializer(book, context={"request": request})
        return Response(ser.data)


class BookDownloadView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        if not settings.FEATURE_BOOK_CONTENT_INDEX:
            return Response({"items": []})
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        rev = book.published_revision
        if rev is None:
            return Response(
                {"error": {"code": "NO_REVISION", "message": "No published revision"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        if not settings.AWS_STORAGE_BUCKET_NAME or not (
            settings.AWS_S3_PRESIGN_ENDPOINT_URL or settings.AWS_S3_ENDPOINT_URL
        ):
            logger.warning("S3 not configured; download unavailable")
            return Response(
                {
                    "error": {
                        "code": "STORAGE_UNAVAILABLE",
                        "message": "Object storage is not configured for presigned downloads.",
                    }
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        if not rev.manifest_object_key:
            return Response(
                {
                    "error": {
                        "code": "PACKAGE_INCOMPLETE",
                        "message": "Published revision has no manifest in storage.",
                    }
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        presign_endpoint = dev_presign_endpoint_from_request(request)
        try:
            manifest_url = presign_get(
                rev.manifest_object_key,
                presign_endpoint_url=presign_endpoint,
            )
        except Exception as exc:
            logger.exception("presign manifest failed: %s", exc)
            return Response(
                {"error": {"code": "PRESIGN_FAILED", "message": "Could not generate download URL."}},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        package_parts: list[dict] = []
        if rev.content_object_key:
            try:
                content_url = presign_get(
                    rev.content_object_key,
                    presign_endpoint_url=presign_endpoint,
                )
                size_bytes = 0
                try:
                    size_bytes = int(head_object(rev.content_object_key)["ContentLength"])
                except Exception:
                    size_bytes = int(rev.total_bytes or 0)
                package_parts.append(
                    {
                        "part_index": 0,
                        "object_key": rev.content_object_key,
                        "url": content_url,
                        "sha256": rev.content_sha256 or "",
                        "size_bytes": size_bytes,
                    }
                )
            except Exception as exc:
                logger.exception("presign content failed: %s", exc)
                return Response(
                    {"error": {"code": "PRESIGN_FAILED", "message": "Could not generate download URL."}},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

        payload = {
            "book_id": str(book.id),
            "revision": {
                "id": str(rev.id),
                "revision_number": rev.revision_number,
                "content_format": rev.content_format,
                "manifest_url": manifest_url,
                "package_parts": package_parts,
                "encryption": _encryption_payload(rev),
            },
        }
        return Response(payload)


class BookChapterListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        del request
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        rev = book.published_revision
        if rev is None:
            return Response({"items": []})
        chapters = BookChapter.objects.filter(revision=rev).order_by("ordinal")
        payload = {
            "items": [
                {
                    "chapter_key": c.chapter_key,
                    "title": c.title,
                    "ordinal": c.ordinal,
                }
                for c in chapters
            ]
        }
        return Response(payload)


class BookSearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        rev = book.published_revision
        if rev is None or not settings.FEATURE_BOOK_CONTENT_INDEX:
            return Response({"items": [], "total": 0})

        query = (request.query_params.get("q") or "").strip()
        chapter = (request.query_params.get("chapter") or "").strip()
        page = _parse_positive_int(request.query_params.get("page"))
        rows = BookContentIndex.objects.filter(revision=rev)
        if chapter:
            rows = rows.filter(chapter_key=chapter)
        if page is not None:
            rows = rows.filter(page_number=page)
        if query:
            normalized = normalize_search_text(query)
            rows = rows.filter(
                Q(text_normalized__contains=normalized) | Q(text_plain__icontains=query)
            )

        rows = rows.order_by("page_number", "chunk_key")[:50]
        items = []
        for row in rows:
            snippet = row.text_plain.strip()
            if len(snippet) > 220:
                snippet = f"{snippet[:220]}..."
            items.append(
                {
                    "chapter_key": row.chapter_key,
                    "page_number": row.page_number,
                    "chunk_key": row.chunk_key,
                    "snippet": snippet,
                }
            )
        return Response({"items": items, "total": len(items)})


class BookContentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, book_id):
        del request
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        rev = book.published_revision
        if rev is None or not settings.FEATURE_BOOK_CONTENT_INDEX:
            return Response({"chapters": [], "total_pages": 0})

        ensure_revision_index_from_book_draft(book, rev)

        chapters = BookChapter.objects.filter(revision=rev).order_by("ordinal")
        pages = (
            BookPage.objects.filter(revision=rev)
            .select_related("chapter")
            .order_by("page_number")
        )
        pages_by_chapter: dict[str, list[dict]] = {}
        for page in pages:
            chapter_key = page.chapter.chapter_key if page.chapter else ""
            pages_by_chapter.setdefault(chapter_key, []).append(
                {
                    "page_number": page.page_number,
                    "title": page.page_title or f"Page {page.page_number}",
                    "body": page.text_plain,
                }
            )

        chapter_payload = []
        for chapter in chapters:
            chapter_payload.append(
                {
                    "chapter_key": chapter.chapter_key,
                    "title": chapter.title,
                    "ordinal": chapter.ordinal,
                    "pages": pages_by_chapter.get(chapter.chapter_key, []),
                }
            )
        return Response({"chapters": chapter_payload, "total_pages": pages.count()})
