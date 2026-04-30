import logging

from rest_framework import serializers

from apps.catalog.models import Book, BookRevision, BookTag, Tag
from apps.catalog.storage_s3 import presign_get

logger = logging.getLogger(__name__)


def _validate_chapters_draft(value):
    if value in (None, ""):
        return []
    if not isinstance(value, list):
        raise serializers.ValidationError("chapters_draft must be a list.")

    seen_keys: set[str] = set()
    normalized: list[dict] = []
    for chapter_idx, chapter in enumerate(value, start=1):
        if not isinstance(chapter, dict):
            raise serializers.ValidationError(
                f"chapters_draft[{chapter_idx}] must be an object."
            )
        chapter_key = str(chapter.get("chapter_key") or "").strip()
        title = str(chapter.get("title") or "").strip()
        pages = chapter.get("pages") if "pages" in chapter else []
        if not chapter_key:
            raise serializers.ValidationError(
                f"chapters_draft[{chapter_idx}].chapter_key is required."
            )
        if chapter_key in seen_keys:
            raise serializers.ValidationError(
                f"Duplicate chapter_key: {chapter_key}"
            )
        seen_keys.add(chapter_key)
        if not isinstance(pages, list):
            raise serializers.ValidationError(
                f"chapters_draft[{chapter_idx}].pages must be a list."
            )

        seen_page_numbers: set[int] = set()
        normalized_pages: list[dict] = []
        for page_idx, page in enumerate(pages, start=1):
            if not isinstance(page, dict):
                raise serializers.ValidationError(
                    f"chapters_draft[{chapter_idx}].pages[{page_idx}] must be an object."
                )
            try:
                page_number = int(page.get("page_number"))
            except (TypeError, ValueError):
                raise serializers.ValidationError(
                    f"chapters_draft[{chapter_idx}].pages[{page_idx}].page_number must be a positive integer."
                )
            if page_number < 1:
                raise serializers.ValidationError(
                    f"chapters_draft[{chapter_idx}].pages[{page_idx}].page_number must be >= 1."
                )
            if page_number in seen_page_numbers:
                raise serializers.ValidationError(
                    f"Duplicate page_number {page_number} in chapter {chapter_key}."
                )
            seen_page_numbers.add(page_number)
            normalized_pages.append(
                {
                    "page_number": page_number,
                    "title": str(page.get("title") or f"Page {page_number}").strip(),
                    "body": str(page.get("body") or "").strip(),
                }
            )

        normalized.append(
            {
                "chapter_key": chapter_key,
                "title": title or chapter_key,
                "pages": sorted(normalized_pages, key=lambda p: p["page_number"]),
            }
        )

    return normalized


class AdminBookCreateSerializer(serializers.ModelSerializer):
    tag_slugs = serializers.ListField(
        child=serializers.SlugField(),
        required=False,
        default=list,
    )

    class Meta:
        model = Book
        fields = (
            "title",
            "subtitle",
            "summary",
            "author_compiler",
            "primary_language",
            "script_tags",
            "chapters_draft",
            "tag_slugs",
        )

    def validate_chapters_draft(self, value):
        return _validate_chapters_draft(value)

    def create(self, validated_data):
        tag_slugs = validated_data.pop("tag_slugs", [])
        user = self.context["request"].user
        book = Book.objects.create(created_by=user, **validated_data)
        for slug in tag_slugs:
            tag, _ = Tag.objects.get_or_create(slug=slug, defaults={"label": slug})
            BookTag.objects.get_or_create(book=book, tag=tag)
        return book


class AdminBookSerializer(serializers.ModelSerializer):
    published_revision_number = serializers.SerializerMethodField()
    cover_get_url = serializers.SerializerMethodField()

    def get_published_revision_number(self, obj: Book):
        rev = getattr(obj, "published_revision", None)
        return rev.revision_number if rev is not None else None

    def get_cover_get_url(self, obj: Book) -> str | None:
        key = (obj.cover_object_key or "").strip()
        if not key:
            return None
        try:
            return presign_get(key, expires_in=3600)
        except Exception:
            logger.warning("cover presign GET failed for book %s", obj.id, exc_info=True)
            return None

    class Meta:
        model = Book
        fields = (
            "id",
            "title",
            "subtitle",
            "summary",
            "author_compiler",
            "primary_language",
            "script_tags",
            "chapters_draft",
            "catalog_visibility",
            "cover_object_key",
            "cover_get_url",
            "published_revision_id",
            "published_revision_number",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "created_at",
            "updated_at",
            "published_revision_id",
            "cover_object_key",
            "cover_get_url",
        )


class AdminBookPatchSerializer(serializers.ModelSerializer):
    cover_object_key = serializers.CharField(max_length=500, allow_blank=True, required=False)

    def validate_chapters_draft(self, value):
        return _validate_chapters_draft(value)

    def validate_cover_object_key(self, value: str) -> str:
        v = (value or "").strip()
        if not v:
            return ""
        book = self.instance
        if book is None:
            raise serializers.ValidationError("Book instance is required.")
        prefix = f"books/{book.pk}/covers/"
        if not v.startswith(prefix):
            raise serializers.ValidationError("cover_object_key does not match this book.")
        return v

    class Meta:
        model = Book
        fields = (
            "title",
            "subtitle",
            "summary",
            "author_compiler",
            "primary_language",
            "script_tags",
            "chapters_draft",
            "catalog_visibility",
            "cover_object_key",
        )


class AdminRevisionCreateSerializer(serializers.Serializer):
    content_format = serializers.CharField(default="html_chunks")
    expected_total_bytes = serializers.IntegerField(min_value=0, required=False)
    files = serializers.ListField(
        child=serializers.DictField(),
        min_length=1,
    )


class AdminPublishSerializer(serializers.Serializer):
    revision_id = serializers.UUIDField(required=False)


class AdminRevisionCompleteSerializer(serializers.Serializer):
    manifest_sha256 = serializers.CharField(max_length=64, required=False, allow_blank=True)
    content_sha256 = serializers.CharField(max_length=64, required=False, allow_blank=True)
