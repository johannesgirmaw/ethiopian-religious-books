import uuid

from django.conf import settings
from django.db import models

from apps.catalog.models import Book, BookRevision


class StudyFolder(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="study_folders")
    name = models.CharField(max_length=140)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "study_folders"
        ordering = ["name"]
        constraints = [models.UniqueConstraint(fields=["user", "name"], name="uniq_study_folder_name")]


class UserBookmark(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="study_bookmarks",
    )
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey(BookRevision, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(null=True, blank=True)
    locator = models.CharField(max_length=300, blank=True)
    label = models.CharField(max_length=200, blank=True)
    snippet = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_bookmarks"
        ordering = ["-created_at"]


class UserHighlight(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="study_highlights",
    )
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey(BookRevision, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(null=True, blank=True)
    locator = models.CharField(max_length=300, blank=True)
    excerpt = models.TextField(blank=True)
    color = models.CharField(max_length=32, default="yellow")
    start_offset = models.PositiveIntegerField(default=0)
    end_offset = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_highlights"
        ordering = ["-created_at"]


class UserNote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="study_notes")
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey(BookRevision, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    linked_highlight = models.ForeignKey(
        UserHighlight,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="notes",
    )
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(null=True, blank=True)
    locator = models.CharField(max_length=300, blank=True)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_notes"
        ordering = ["-updated_at"]


class StudyFolderEntry(models.Model):
    class ItemType(models.TextChoices):
        BOOKMARK = "bookmark", "bookmark"
        HIGHLIGHT = "highlight", "highlight"
        NOTE = "note", "note"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    folder = models.ForeignKey(StudyFolder, on_delete=models.CASCADE, related_name="entries")
    item_type = models.CharField(max_length=20, choices=ItemType.choices)
    item_id = models.UUIDField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "study_folder_entries"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["folder", "item_type", "item_id"],
                name="uniq_folder_item_link",
            )
        ]


class DailyReadingPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="daily_plans")
    title = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "daily_reading_plans"
        ordering = ["-updated_at"]


class DailyReadingPlanItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    plan = models.ForeignKey(DailyReadingPlan, on_delete=models.CASCADE, related_name="items")
    day_index = models.PositiveIntegerField(default=1)
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    chapter_key = models.CharField(max_length=200, blank=True)
    page_start = models.PositiveIntegerField(null=True, blank=True)
    page_end = models.PositiveIntegerField(null=True, blank=True)
    note = models.CharField(max_length=280, blank=True)

    class Meta:
        db_table = "daily_reading_plan_items"
        ordering = ["plan", "day_index", "chapter_key"]
        constraints = [
            models.UniqueConstraint(
                fields=["plan", "day_index", "book", "chapter_key", "page_start", "page_end"],
                name="uniq_plan_item",
            )
        ]


class ReminderPreference(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reminder_preference",
    )
    enabled = models.BooleanField(default=False)
    hour_utc = models.PositiveSmallIntegerField(default=6)
    minute_utc = models.PositiveSmallIntegerField(default=0)
    weekdays_only = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "reminder_preferences"


class StudyReminder(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "pending"
        SENT = "sent", "sent"
        SKIPPED = "skipped", "skipped"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="study_reminders")
    plan = models.ForeignKey(DailyReadingPlan, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    plan_item = models.ForeignKey(
        DailyReadingPlanItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    scheduled_for = models.DateTimeField()
    message = models.CharField(max_length=280)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    sent_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "study_reminders"
        ordering = ["-scheduled_for"]


class UserReadingProgress(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reading_progress_rows",
    )
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey(BookRevision, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(null=True, blank=True)
    progress_percent = models.PositiveSmallIntegerField(default=0)
    last_read_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_reading_progress"
        ordering = ["-last_read_at"]
        constraints = [
            models.UniqueConstraint(fields=["user", "book"], name="uniq_user_book_progress"),
        ]


class ReaderEvent(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reader_events",
    )
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey(BookRevision, on_delete=models.SET_NULL, null=True, blank=True, related_name="+")
    event_name = models.CharField(max_length=80)
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(null=True, blank=True)
    payload = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "reader_events"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "event_name", "-created_at"], name="idx_reader_event_user_name"),
            models.Index(fields=["book", "event_name", "-created_at"], name="idx_reader_event_book_name"),
        ]
