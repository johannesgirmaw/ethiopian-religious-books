from rest_framework import serializers

from apps.catalog.models import Book, BookRevision, Genre, Tag


class PublishedRevisionSerializer(serializers.ModelSerializer):
    updated_at = serializers.DateTimeField(source="created_at")

    class Meta:
        model = BookRevision
        fields = ("id", "revision_number", "updated_at", "total_bytes", "content_format")


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ("slug", "label")


class GenreSerializer(serializers.ModelSerializer):
    class Meta:
        model = Genre
        fields = ("slug", "label", "label_am", "icon", "ordinal")


class BookListSerializer(serializers.ModelSerializer):
    published_revision = PublishedRevisionSerializer(allow_null=True)
    cover_url = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()
    # The price a buyer actually pays (sale_price when set, else price). Computed
    # inline so the catalog app keeps no dependency on the payments app.
    final_price = serializers.SerializerMethodField()

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
            "published_year",
            "rating_average",
            "rating_count",
            "readers_count",
            "is_premium",
            "is_featured",
            "catalog_visibility",
            "cover_url",
            "currency",
            "price",
            "sale_price",
            "final_price",
            "published_revision",
            "created_at",
            "tags",
        )

    def get_final_price(self, obj: Book) -> str:
        value = obj.sale_price if obj.sale_price is not None else obj.price
        return str(value if value is not None else 0)

    def get_cover_url(self, obj: Book) -> str | None:
        if not (obj.cover_object_key or "").strip():
            return None
        # Stable, always-reachable URL served through the API host (no presign
        # expiry / host-reachability issues). `?v=` busts client/image caches
        # when the cover is replaced.
        ver = int(obj.updated_at.timestamp()) if obj.updated_at else 0
        path = f"/v1/books/{obj.id}/cover?v={ver}"
        request = self.context.get("request")
        if request is not None:
            return request.build_absolute_uri(path)
        return path

    def get_tags(self, obj: Book):
        tags = Tag.objects.filter(booktag__book=obj)
        return TagSerializer(tags, many=True).data
