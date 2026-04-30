from rest_framework import serializers

from apps.catalog.models import Book, BookRevision, Tag


class PublishedRevisionSerializer(serializers.ModelSerializer):
    updated_at = serializers.DateTimeField(source="created_at")

    class Meta:
        model = BookRevision
        fields = ("id", "revision_number", "updated_at", "total_bytes", "content_format")


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ("slug", "label")


class BookListSerializer(serializers.ModelSerializer):
    published_revision = PublishedRevisionSerializer(allow_null=True)
    cover_url = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()

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
            "catalog_visibility",
            "cover_url",
            "published_revision",
            "tags",
        )

    def get_cover_url(self, obj: Book) -> str | None:
        del obj  # reserved for presigned URLs (MinIO) later
        return None

    def get_tags(self, obj: Book):
        tags = Tag.objects.filter(booktag__book=obj)
        return TagSerializer(tags, many=True).data
