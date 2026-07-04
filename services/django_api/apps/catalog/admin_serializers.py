import logging
import re

from rest_framework import serializers

from apps.catalog.docx_import import ALL_MODES
from apps.catalog.models import Book, BookRevision, BookTag, Tag
from apps.catalog.publishing import normalize_chapters_draft
from apps.catalog.storage_s3 import presign_get

logger = logging.getLogger(__name__)


def _validate_chapters_draft(value):
    try:
        return normalize_chapters_draft(value)
    except ValueError as exc:
        raise serializers.ValidationError(str(exc)) from exc


def _validate_percent(value):
    if value is None:
        return value
    if value < 0 or value > 100:
        raise serializers.ValidationError("Commission percent must be between 0 and 100.")
    return value


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
            "genre",
            "is_bible",
            "testament_type",
            "published_year",
            "is_premium",
            "is_featured",
            "author",
            "currency",
            "price",
            "sale_price",
            "commission_percent",
            "chapters_draft",
            "tag_slugs",
        )

    def validate_chapters_draft(self, value):
        return _validate_chapters_draft(value)

    def validate_commission_percent(self, value):
        return _validate_percent(value)

    def create(self, validated_data):
        tag_slugs = validated_data.pop("tag_slugs", [])
        user = self.context["request"].user
        # When an author creates a book and no author was set explicitly,
        # attribute it to them so commission/revenue accrue correctly.
        if not validated_data.get("author") and getattr(user, "role", "") == "author":
            validated_data["author"] = user
        book = Book.objects.create(created_by=user, **validated_data)
        for slug in tag_slugs:
            tag, _ = Tag.objects.get_or_create(slug=slug, defaults={"label": slug})
            BookTag.objects.get_or_create(book=book, tag=tag)
        return book


class AdminBookSerializer(serializers.ModelSerializer):
    published_revision_number = serializers.SerializerMethodField()
    cover_get_url = serializers.SerializerMethodField()
    tag_slugs = serializers.SerializerMethodField()
    final_price = serializers.SerializerMethodField()

    def get_final_price(self, obj: Book) -> str:
        value = obj.sale_price if obj.sale_price is not None else obj.price
        return str(value if value is not None else 0)

    def get_published_revision_number(self, obj: Book):
        rev = getattr(obj, "published_revision", None)
        return rev.revision_number if rev is not None else None

    def get_tag_slugs(self, obj: Book):
        return list(
            Tag.objects.filter(booktag__book=obj)
            .order_by("label")
            .values_list("slug", flat=True)
        )

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
            "genre",
            "is_bible",
            "testament_type",
            "published_year",
            "rating_average",
            "rating_count",
            "readers_count",
            "is_premium",
            "is_featured",
            "author",
            "currency",
            "price",
            "sale_price",
            "commission_percent",
            "final_price",
            "chapters_draft",
            "catalog_visibility",
            "cover_object_key",
            "cover_get_url",
            "published_revision_id",
            "published_revision_number",
            "tag_slugs",
            "created_by_id",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "created_by_id",
            "created_at",
            "updated_at",
            "published_revision_id",
            "cover_object_key",
            "cover_get_url",
            "tag_slugs",
            "final_price",
            "rating_average",
            "rating_count",
            "readers_count",
        )


class AdminBookPatchSerializer(serializers.ModelSerializer):
    cover_object_key = serializers.CharField(max_length=500, allow_blank=True, required=False)
    tag_slugs = serializers.ListField(
        child=serializers.SlugField(),
        required=False,
    )

    def validate_chapters_draft(self, value):
        return _validate_chapters_draft(value)

    def validate_commission_percent(self, value):
        return _validate_percent(value)

    def update(self, instance, validated_data):
        tag_slugs = validated_data.pop("tag_slugs", None)
        book = super().update(instance, validated_data)
        if tag_slugs is not None:
            BookTag.objects.filter(book=book).delete()
            for slug in tag_slugs:
                tag, _ = Tag.objects.get_or_create(slug=slug, defaults={"label": slug})
                BookTag.objects.get_or_create(book=book, tag=tag)
        return book

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
            "genre",
            "is_bible",
            "testament_type",
            "published_year",
            "is_premium",
            "is_featured",
            "author",
            "currency",
            "price",
            "sale_price",
            "commission_percent",
            "chapters_draft",
            "cover_object_key",
            "tag_slugs",
        )


class AdminBookImportDocxSerializer(serializers.Serializer):
    """Validate a Word (.docx) upload plus optional metadata for the new book."""

    file = serializers.FileField()
    title = serializers.CharField(max_length=500, required=False, allow_blank=True)
    primary_language = serializers.CharField(max_length=32, required=False, default="am")
    genre = serializers.CharField(max_length=64, required=False, allow_blank=True)
    author_compiler = serializers.CharField(max_length=500, required=False, allow_blank=True)
    is_premium = serializers.BooleanField(required=False, default=False)
    # Structure-detection controls (see apps.catalog.docx_import).
    mode = serializers.ChoiceField(choices=ALL_MODES, required=False, default="auto")
    pattern = serializers.CharField(max_length=300, required=False, allow_blank=True)
    marker = serializers.CharField(max_length=120, required=False, allow_blank=True)

    def validate_pattern(self, value):
        v = (value or "").strip()
        if v:
            try:
                re.compile(v)
            except re.error as exc:
                raise serializers.ValidationError(f"Invalid chapter pattern: {exc}")
        return v


class AdminBookImportDocxPreviewSerializer(AdminBookImportDocxSerializer):
    """Preview (dry-run) shares the upload/detection fields; metadata is ignored."""


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
