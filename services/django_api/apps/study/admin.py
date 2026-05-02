from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline

from apps.study.models import (
    DailyReadingPlan,
    DailyReadingPlanItem,
    ReaderEvent,
    ReminderPreference,
    StudyFolder,
    StudyFolderEntry,
    StudyReminder,
    UserBookmark,
    UserHighlight,
    UserNote,
    UserReadingProgress,
)


class DailyReadingPlanItemInline(TabularInline):
    model = DailyReadingPlanItem
    extra = 0
    raw_id_fields = ("book",)


@admin.register(DailyReadingPlan)
class DailyReadingPlanAdmin(ModelAdmin):
    list_display = ("title", "user", "is_active", "updated_at")
    list_filter = ("is_active",)
    search_fields = ("title", "user__email")
    raw_id_fields = ("user",)
    inlines = (DailyReadingPlanItemInline,)


@admin.register(DailyReadingPlanItem)
class DailyReadingPlanItemAdmin(ModelAdmin):
    list_display = ("plan", "day_index", "book", "chapter_key", "page_start", "page_end")
    list_filter = ("plan",)
    search_fields = ("plan__title", "book__title", "chapter_key")
    raw_id_fields = ("plan", "book")


@admin.register(StudyFolder)
class StudyFolderAdmin(ModelAdmin):
    list_display = ("name", "user", "created_at", "updated_at")
    search_fields = ("name", "user__email")
    raw_id_fields = ("user",)


@admin.register(UserBookmark)
class UserBookmarkAdmin(ModelAdmin):
    list_display = ("user", "book", "chapter_key", "page_number", "label", "created_at")
    list_filter = ("book",)
    search_fields = ("user__email", "book__title", "label", "snippet")
    date_hierarchy = "created_at"
    raw_id_fields = ("user", "book", "revision")


@admin.register(UserHighlight)
class UserHighlightAdmin(ModelAdmin):
    list_display = ("user", "book", "color", "chapter_key", "page_number", "created_at")
    list_filter = ("color", "book")
    search_fields = ("user__email", "book__title", "excerpt")
    date_hierarchy = "created_at"
    raw_id_fields = ("user", "book", "revision")


@admin.register(UserNote)
class UserNoteAdmin(ModelAdmin):
    list_display = ("user", "book", "chapter_key", "page_number", "body_preview", "updated_at")
    list_filter = ("book",)
    search_fields = ("user__email", "book__title", "body")
    date_hierarchy = "updated_at"
    raw_id_fields = ("user", "book", "revision", "linked_highlight")

    @admin.display(description="Body")
    def body_preview(self, obj):
        t = obj.body or ""
        return t[:120] + ("…" if len(t) > 120 else "")


@admin.register(StudyFolderEntry)
class StudyFolderEntryAdmin(ModelAdmin):
    list_display = ("folder", "item_type", "item_id", "created_at")
    list_filter = ("item_type",)
    search_fields = ("folder__name", "folder__user__email")
    raw_id_fields = ("folder",)


@admin.register(ReminderPreference)
class ReminderPreferenceAdmin(ModelAdmin):
    list_display = ("user", "enabled", "hour_utc", "minute_utc", "weekdays_only", "updated_at")
    list_filter = ("enabled", "weekdays_only")
    search_fields = ("user__email",)
    raw_id_fields = ("user",)


@admin.register(StudyReminder)
class StudyReminderAdmin(ModelAdmin):
    list_display = ("user", "status", "scheduled_for", "message_short", "plan", "created_at")
    list_filter = ("status",)
    search_fields = ("user__email", "message")
    date_hierarchy = "scheduled_for"
    raw_id_fields = ("user", "plan", "plan_item")

    @admin.display(description="Message")
    def message_short(self, obj):
        m = obj.message or ""
        return m[:60] + ("…" if len(m) > 60 else "")


@admin.register(UserReadingProgress)
class UserReadingProgressAdmin(ModelAdmin):
    list_display = ("user", "book", "progress_percent", "chapter_key", "page_number", "last_read_at")
    list_filter = ("book",)
    search_fields = ("user__email", "book__title", "chapter_key")
    raw_id_fields = ("user", "book", "revision")


@admin.register(ReaderEvent)
class ReaderEventAdmin(ModelAdmin):
    list_display = (
        "created_at",
        "user",
        "book",
        "event_name",
        "chapter_key",
        "page_number",
    )
    list_filter = ("event_name", "book")
    search_fields = ("user__email", "book__title", "event_name", "chapter_key")
    date_hierarchy = "created_at"
    raw_id_fields = ("user", "book", "revision")
    readonly_fields = ("id", "created_at")
