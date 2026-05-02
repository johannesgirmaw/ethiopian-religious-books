from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline

from apps.catalog.models import (
    Book,
    BookChapter,
    BookContentIndex,
    BookPage,
    BookRevision,
    BookTag,
    Tag,
)


class BookRevisionInline(TabularInline):
    model = BookRevision
    extra = 0
    show_change_link = True
    fields = (
        "revision_number",
        "status",
        "content_format",
        "total_bytes",
        "created_at",
        "created_by",
    )
    readonly_fields = ("created_at",)
    raw_id_fields = ("created_by",)
    ordering = ("-revision_number",)


class BookTagInline(TabularInline):
    model = BookTag
    extra = 0
    autocomplete_fields = ("tag",)


@admin.register(Book)
class BookAdmin(ModelAdmin):
    list_display = (
        "title",
        "catalog_visibility",
        "published_revision_link",
        "primary_language",
        "updated_at",
    )
    list_filter = ("catalog_visibility", "primary_language")
    search_fields = ("title", "subtitle", "author_compiler", "summary")
    ordering = ("title",)
    readonly_fields = ("id", "search_text_normalized", "created_at", "updated_at")
    raw_id_fields = ("published_revision", "created_by")
    inlines = (BookRevisionInline, BookTagInline)
    fieldsets = (
        (None, {"fields": ("title", "subtitle", "summary", "author_compiler")}),
        (
            "Catalog",
            {
                "fields": (
                    "primary_language",
                    "script_tags",
                    "catalog_visibility",
                    "published_revision",
                )
            },
        ),
        ("Draft structure", {"fields": ("chapters_draft",), "classes": ("wide",)}),
        ("Object storage", {"fields": ("cover_object_key",)}),
        (
            "System",
            {
                "fields": ("id", "created_by", "created_at", "updated_at", "search_text_normalized"),
                "classes": ("collapse",),
            },
        ),
    )

    @admin.display(description="Published revision")
    def published_revision_link(self, obj):
        rev = obj.published_revision
        if not rev:
            return "—"
        url = reverse("admin:catalog_bookrevision_change", args=[rev.pk])
        return format_html('<a href="{}">#{} ({})</a>', url, rev.revision_number, rev.status)


class BookChapterInline(TabularInline):
    model = BookChapter
    extra = 0
    fields = ("ordinal", "chapter_key", "title", "start_chunk", "end_chunk")


@admin.register(BookRevision)
class BookRevisionAdmin(ModelAdmin):
    list_display = (
        "book",
        "revision_number",
        "status",
        "content_format",
        "total_bytes",
        "created_at",
    )
    list_filter = ("status", "content_format")
    search_fields = ("book__title", "manifest_object_key", "content_object_key")
    ordering = ("book", "-revision_number")
    readonly_fields = ("id", "created_at")
    raw_id_fields = ("book", "created_by")
    inlines = (BookChapterInline,)
    fieldsets = (
        (None, {"fields": ("book", "revision_number", "status", "created_by")}),
        (
            "Storage",
            {
                "fields": (
                    "manifest_object_key",
                    "content_object_key",
                    "content_format",
                    "total_bytes",
                    "manifest_sha256",
                    "content_sha256",
                    "cek_wrapped",
                )
            },
        ),
        ("System", {"fields": ("id", "created_at"), "classes": ("collapse",)}),
    )


@admin.register(Tag)
class TagAdmin(ModelAdmin):
    list_display = ("label", "slug")
    search_fields = ("label", "slug")
    ordering = ("label",)


@admin.register(BookTag)
class BookTagAdmin(ModelAdmin):
    list_display = ("book", "tag")
    list_select_related = ("book", "tag")
    autocomplete_fields = ("book", "tag")
    search_fields = ("book__title", "tag__label", "tag__slug")


@admin.register(BookChapter)
class BookChapterAdmin(ModelAdmin):
    list_display = ("revision", "ordinal", "chapter_key", "title")
    list_filter = ("revision__book",)
    search_fields = ("chapter_key", "title", "revision__book__title")
    ordering = ("revision", "ordinal")
    raw_id_fields = ("revision",)


@admin.register(BookPage)
class BookPageAdmin(ModelAdmin):
    list_display = ("revision", "page_number", "page_title", "text_preview", "chunk_key")
    list_filter = ("revision__book",)
    search_fields = ("page_title", "chunk_key", "text_plain", "revision__book__title")
    ordering = ("revision", "page_number")
    raw_id_fields = ("revision", "chapter")
    readonly_fields = ("id",)

    @admin.display(description="Text preview")
    def text_preview(self, obj):
        t = obj.text_plain or ""
        if len(t) <= 100:
            return t
        return t[:100] + "…"


@admin.register(BookContentIndex)
class BookContentIndexAdmin(ModelAdmin):
    list_display = ("book", "revision", "page_number", "chapter_key", "chunk_key", "snippet")
    list_filter = ("book",)
    search_fields = ("chunk_key", "chapter_key", "text_plain", "book__title")
    ordering = ("revision", "page_number")
    raw_id_fields = ("book", "revision")
    readonly_fields = ("id",)

    @admin.display(description="Snippet")
    def snippet(self, obj):
        t = obj.text_plain or ""
        if len(t) <= 80:
            return t
        return t[:80] + "…"
