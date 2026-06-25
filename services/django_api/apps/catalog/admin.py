from uuid import UUID

from django.contrib import admin, messages
from django.db import models
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.urls import path, reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.contrib.forms.widgets import WysiwygWidget
from unfold.widgets import UnfoldAdminTextareaWidget

from apps.catalog.models import (
    Book,
    BookChapter,
    BookContentIndex,
    BookPage,
    BookRevision,
    BookTag,
    Genre,
    Tag,
)
from apps.catalog.publishing import publish_book, unpublish_book, validate_draft_warnings


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
    change_form_after_template = "admin/catalog/book/publish_panel.html"
    formfield_overrides = {
        models.TextField: {"widget": WysiwygWidget()},
        models.JSONField: {
            "widget": UnfoldAdminTextareaWidget(
                attrs={
                    "rows": 22,
                    "class": "font-mono text-xs min-h-[20rem] w-full max-w-full",
                }
            )
        },
    }
    list_display = (
        "title",
        "catalog_visibility",
        "is_premium",
        "price",
        "currency",
        "published_revision_link",
        "primary_language",
        "updated_at",
    )
    list_filter = ("catalog_visibility", "primary_language", "is_premium")
    search_fields = ("title", "subtitle", "author_compiler", "summary")
    ordering = ("title",)
    readonly_fields = ("id", "search_text_normalized", "created_at", "updated_at")
    raw_id_fields = ("published_revision", "created_by", "author")
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
        (
            "Pricing & commission",
            {
                "fields": (
                    "author",
                    "is_premium",
                    "currency",
                    "price",
                    "sale_price",
                    "commission_percent",
                ),
                "description": (
                    "Premium titles with a price require a purchase to read. "
                    "Leave commission blank to fall back to the author override, "
                    "then the platform default. <code>author</code> is the User "
                    "(with the author role) who receives the author share."
                ),
            },
        ),
        (
            "Draft structure",
            {
                "fields": ("chapters_draft",),
                "classes": ("wide",),
                "description": (
                    "JSON array of chapters used to build the packaged book when you publish. "
                    "Example: [{\"chapter_key\":\"intro\",\"title\":\"Introduction\","
                    "\"pages\":[{\"page_number\":1,\"title\":\"Page 1\",\"body\":\"<p>HTML or plain text</p>\"}]}]"
                ),
            },
        ),
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

    def get_urls(self):
        info = self.opts.app_label, self.opts.model_name
        return [
            path(
                "<uuid:object_id>/publish/",
                self.admin_site.admin_view(self.publish_from_admin),
                name=f"{info[0]}_{info[1]}_publish",
            ),
            path(
                "<uuid:object_id>/unpublish/",
                self.admin_site.admin_view(self.unpublish_from_admin),
                name=f"{info[0]}_{info[1]}_unpublish",
            ),
            *super().get_urls(),
        ]

    def changeform_view(self, request, object_id=None, form_url="", extra_context=None):
        extra_context = extra_context or {}
        if object_id:
            book = Book.objects.filter(pk=object_id).first()
            if book:
                extra_context["draft_validation"] = validate_draft_warnings(
                    book.chapters_draft if isinstance(book.chapters_draft, list) else []
                )
                extra_context["draft_revisions"] = list(
                    BookRevision.objects.filter(book=book, status=BookRevision.Status.DRAFT).order_by(
                        "-revision_number"
                    )
                )
        return super().changeform_view(request, object_id, form_url, extra_context)

    def publish_from_admin(self, request, object_id):
        if not request.user.is_superuser:
            self.message_user(
                request,
                "Only superusers can publish books.",
                level=messages.ERROR,
            )
            return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))
        if request.method != "POST":
            return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))
        book = get_object_or_404(Book, pk=object_id)
        raw_rid = (request.POST.get("revision_id") or "").strip()
        revision_id = None
        if raw_rid:
            try:
                revision_id = UUID(raw_rid)
            except ValueError:
                revision_id = None
        outcome = publish_book(book, request.user, revision_id)
        if outcome.ok:
            self.message_user(request, "Book published successfully.", level=messages.SUCCESS)
        else:
            msg = "Publish failed."
            payload = outcome.error or {}
            err = payload.get("error")
            if isinstance(err, dict) and err.get("message"):
                msg = str(err["message"])
            val = payload.get("validation")
            if isinstance(val, dict):
                warns = val.get("warnings") or []
                if warns:
                    msg = f"{msg} ({warns[0]})"
            self.message_user(request, msg, level=messages.ERROR)
        return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))

    def unpublish_from_admin(self, request, object_id):
        if not request.user.is_superuser:
            self.message_user(
                request,
                "Only superusers can unpublish books.",
                level=messages.ERROR,
            )
            return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))
        if request.method != "POST":
            return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))
        book = get_object_or_404(Book, pk=object_id)
        unpublish_book(book)
        self.message_user(request, "Book unpublished (hidden from catalog).", level=messages.SUCCESS)
        return HttpResponseRedirect(reverse("admin:catalog_book_change", args=[object_id]))


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


@admin.register(Genre)
class GenreAdmin(ModelAdmin):
    list_display = ("label", "slug", "ordinal", "is_active")
    list_editable = ("ordinal", "is_active")
    search_fields = ("label", "slug")
    ordering = ("ordinal", "label")
    prepopulated_fields = {"slug": ("label",)}


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
    fieldsets = (
        (None, {"fields": ("revision", "chapter_key", "title", "ordinal", "start_chunk", "end_chunk")}),
    )
    list_display = ("revision", "ordinal", "chapter_key", "title")
    list_filter = ("revision__book",)
    search_fields = ("chapter_key", "title", "revision__book__title")
    ordering = ("revision", "ordinal")
    raw_id_fields = ("revision",)


@admin.register(BookPage)
class BookPageAdmin(ModelAdmin):
    formfield_overrides = {
        models.TextField: {"widget": WysiwygWidget()},
    }
    fieldsets = (
        (
            None,
            {
                "fields": ("revision", "chapter", "page_number", "page_title", "chunk_key"),
            },
        ),
        (
            "Page body",
            {
                "fields": ("text_plain",),
                "classes": ("wide",),
                "description": (
                    "Rich text for this indexed page. When you publish, admin-built chapters/pages "
                    "are copied back into “Draft structure” first; encrypted (.enc) revisions cannot "
                    "be refreshed from the DB."
                ),
            },
        ),
    )
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
