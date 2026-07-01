import json
import logging

from django.conf import settings
from django.db.models import F, Q
from django.http import Http404, HttpResponse
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import UserDevice
from apps.catalog.etag import catalog_response_extras, compute_catalog_etag
from apps.catalog.licensing import issue_license
from apps.catalog.models import (
    Book,
    BookChapter,
    BookContentIndex,
    BookPage,
    BookRevision,
    Genre,
    OfflineDownload,
    Tag,
)
from apps.catalog.search_index import ensure_revision_index_from_book_draft
from apps.catalog.search_normalization import normalize_search_text
from apps.catalog.serializers import BookListSerializer, GenreSerializer, TagSerializer
from apps.payments.services import user_owns_book
from apps.catalog.storage_s3 import (
    dev_presign_endpoint_from_request,
    get_object_bytes,
    head_object,
    is_object_storage_configured,
    presign_get,
)

logger = logging.getLogger(__name__)


def _record_offline_download(user, book, rev, device_id: str, expires_iso: str) -> None:
    """Upsert the server-side offline-download ledger row for admin visibility.

    Called on every license issue/renew. Best-effort: never let bookkeeping break
    the download itself.
    """
    if not device_id:
        return
    try:
        expires_at = parse_datetime(expires_iso) if expires_iso else None
        platform = (
            UserDevice.objects.filter(user=user, device_id=device_id)
            .values_list("platform", flat=True)
            .first()
            or ""
        )
        obj, created = OfflineDownload.objects.get_or_create(
            user=user,
            book=book,
            device_id=device_id,
            defaults={
                "revision_id": str(rev.id),
                "platform": platform,
                "license_expires_at": expires_at,
            },
        )
        if not created:
            OfflineDownload.objects.filter(pk=obj.pk).update(
                revision_id=str(rev.id),
                platform=platform or obj.platform,
                license_expires_at=expires_at,
                renew_count=F("renew_count") + 1,
                last_licensed_at=timezone.now(),
            )
    except Exception as exc:  # pragma: no cover - bookkeeping must not block downloads
        logger.warning("offline download bookkeeping failed: %s", exc)


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


class GenreListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Genre.objects.filter(is_active=True)
        return Response({"items": GenreSerializer(qs, many=True).data})


class TagListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Tag.objects.all().order_by("label")
        return Response({"items": TagSerializer(qs, many=True).data})


def _cover_content_type(object_key: str) -> str:
    key = object_key.lower()
    if key.endswith(".png"):
        return "image/png"
    if key.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


class BookCoverView(APIView):
    """Streams a published book's cover image from object storage through the
    API host, so clients never depend on a reachable/short-lived presigned URL.
    Public so <img> / Image.network (no auth header) can load it."""

    permission_classes = [AllowAny]

    def get(self, request, book_id):
        book = (
            Book.objects.filter(
                pk=book_id, catalog_visibility=Book.Visibility.PUBLISHED
            )
            .only("id", "cover_object_key")
            .first()
        )
        key = (book.cover_object_key or "").strip() if book else ""
        if not key or not is_object_storage_configured():
            raise Http404("No cover")
        try:
            data = get_object_bytes(key)
        except Exception as exc:  # noqa: BLE001 - any storage error -> 404
            logger.warning("cover fetch failed for %s: %s", book_id, exc)
            raise Http404("Cover unavailable") from exc
        if not data:
            raise Http404("Empty cover")
        resp = HttpResponse(data, content_type=_cover_content_type(key))
        # Immutable per (id, ?v=updated_at); safe to cache aggressively.
        resp["Cache-Control"] = "public, max-age=604800"
        return resp


def _published_books_queryset():
    # Bible books are included in the catalogue (surfaced under the "Bible"
    # category via genre="bible"); the client hides them from the "All" feed and
    # routes them to the verse reader. They carry the is_bible flag + genre so
    # the client can tell them apart.
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
        if not user_owns_book(request.user, book):
            return Response(
                {
                    "error": {
                        "code": "NOT_ENTITLED",
                        "message": "Purchase this book to download it for offline reading.",
                    }
                },
                status=status.HTTP_403_FORBIDDEN,
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

        device_id = (request.query_params.get("device_id") or "").strip()
        license_payload = issue_license(
            user_id=request.user.id,
            book_id=book.id,
            revision_id=rev.id,
            device_id=device_id,
        )
        _record_offline_download(
            request.user, book, rev, device_id, license_payload.get("expires_at", "")
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
            "license": license_payload,
        }
        return Response(payload)


class BookLicenseView(APIView):
    """Issue or renew an offline-reading lease for a book.

    Used both for the first download and for periodic renewal. Re-checks
    entitlement on every call, so a refunded/revoked purchase stops renewing and
    the device loses offline access once its current lease lapses. Decoupled from
    object storage so offline reading works regardless of the S3 packaging state.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, book_id):
        try:
            book = _published_books_queryset().get(pk=book_id)
        except Book.DoesNotExist:
            return Response(
                {"error": {"code": "NOT_FOUND", "message": "Book not found"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        if not user_owns_book(request.user, book):
            return Response(
                {
                    "error": {
                        "code": "NOT_ENTITLED",
                        "message": "Purchase this book to read it offline.",
                    }
                },
                status=status.HTTP_403_FORBIDDEN,
            )
        rev = book.published_revision
        if rev is None:
            return Response(
                {"error": {"code": "NO_REVISION", "message": "No published revision"}},
                status=status.HTTP_404_NOT_FOUND,
            )
        device_id = (request.data.get("device_id") or "").strip()
        license_payload = issue_license(
            user_id=request.user.id,
            book_id=book.id,
            revision_id=rev.id,
            device_id=device_id,
        )
        _record_offline_download(
            request.user, book, rev, device_id, license_payload.get("expires_at", "")
        )
        return Response(
            {
                "book_id": str(book.id),
                "revision_id": str(rev.id),
                "license": license_payload,
            }
        )


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
