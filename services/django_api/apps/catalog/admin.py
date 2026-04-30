from django.contrib import admin

from apps.catalog.models import Book, BookRevision, BookTag, Tag


@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ("title", "catalog_visibility", "updated_at")
    search_fields = ("title", "author_compiler")


@admin.register(BookRevision)
class BookRevisionAdmin(admin.ModelAdmin):
    list_display = ("book", "revision_number", "status", "created_at")


admin.site.register(Tag)
admin.site.register(BookTag)
