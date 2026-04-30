import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models
import uuid


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalog", "0004_search_index_models"),
    ]

    operations = [
        migrations.CreateModel(
            name="DailyReadingPlan",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("title", models.CharField(max_length=200)),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="daily_plans",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "daily_reading_plans", "ordering": ["-updated_at"]},
        ),
        migrations.CreateModel(
            name="ReminderPreference",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("enabled", models.BooleanField(default=False)),
                ("hour_utc", models.PositiveSmallIntegerField(default=6)),
                ("minute_utc", models.PositiveSmallIntegerField(default=0)),
                ("weekdays_only", models.BooleanField(default=False)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="reminder_preference",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "reminder_preferences"},
        ),
        migrations.CreateModel(
            name="StudyFolder",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("name", models.CharField(max_length=140)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="study_folders",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "study_folders", "ordering": ["name"]},
        ),
        migrations.CreateModel(
            name="DailyReadingPlanItem",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("day_index", models.PositiveIntegerField(default=1)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_start", models.PositiveIntegerField(blank=True, null=True)),
                ("page_end", models.PositiveIntegerField(blank=True, null=True)),
                ("note", models.CharField(blank=True, max_length=280)),
                (
                    "book",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="+", to="catalog.book"),
                ),
                (
                    "plan",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="items",
                        to="study.dailyreadingplan",
                    ),
                ),
            ],
            options={
                "db_table": "daily_reading_plan_items",
                "ordering": ["plan", "day_index", "chapter_key"],
            },
        ),
        migrations.CreateModel(
            name="UserHighlight",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(blank=True, null=True)),
                ("locator", models.CharField(blank=True, max_length=300)),
                ("excerpt", models.TextField(blank=True)),
                ("color", models.CharField(default="yellow", max_length=32)),
                ("start_offset", models.PositiveIntegerField(default=0)),
                ("end_offset", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "book",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="+", to="catalog.book"),
                ),
                (
                    "revision",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="+",
                        to="catalog.bookrevision",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="study_highlights",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "user_highlights", "ordering": ["-created_at"]},
        ),
        migrations.CreateModel(
            name="UserBookmark",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(blank=True, null=True)),
                ("locator", models.CharField(blank=True, max_length=300)),
                ("label", models.CharField(blank=True, max_length=200)),
                ("snippet", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "book",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="+", to="catalog.book"),
                ),
                (
                    "revision",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="+",
                        to="catalog.bookrevision",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="study_bookmarks",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "user_bookmarks", "ordering": ["-created_at"]},
        ),
        migrations.CreateModel(
            name="UserNote",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(blank=True, null=True)),
                ("locator", models.CharField(blank=True, max_length=300)),
                ("body", models.TextField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "book",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="+", to="catalog.book"),
                ),
                (
                    "linked_highlight",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="notes",
                        to="study.userhighlight",
                    ),
                ),
                (
                    "revision",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="+",
                        to="catalog.bookrevision",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="study_notes",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "user_notes", "ordering": ["-updated_at"]},
        ),
        migrations.CreateModel(
            name="StudyFolderEntry",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                (
                    "item_type",
                    models.CharField(
                        choices=[("bookmark", "bookmark"), ("highlight", "highlight"), ("note", "note")],
                        max_length=20,
                    ),
                ),
                ("item_id", models.UUIDField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "folder",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="entries",
                        to="study.studyfolder",
                    ),
                ),
            ],
            options={"db_table": "study_folder_entries", "ordering": ["-created_at"]},
        ),
        migrations.CreateModel(
            name="StudyReminder",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("scheduled_for", models.DateTimeField()),
                ("message", models.CharField(max_length=280)),
                (
                    "status",
                    models.CharField(
                        choices=[("pending", "pending"), ("sent", "sent"), ("skipped", "skipped")],
                        default="pending",
                        max_length=20,
                    ),
                ),
                ("sent_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "plan",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="+",
                        to="study.dailyreadingplan",
                    ),
                ),
                (
                    "plan_item",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="+",
                        to="study.dailyreadingplanitem",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="study_reminders",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "study_reminders", "ordering": ["-scheduled_for"]},
        ),
        migrations.AddConstraint(
            model_name="studyfolder",
            constraint=models.UniqueConstraint(fields=("user", "name"), name="uniq_study_folder_name"),
        ),
        migrations.AddConstraint(
            model_name="studyfolderentry",
            constraint=models.UniqueConstraint(
                fields=("folder", "item_type", "item_id"),
                name="uniq_folder_item_link",
            ),
        ),
        migrations.AddConstraint(
            model_name="dailyreadingplanitem",
            constraint=models.UniqueConstraint(
                fields=("plan", "day_index", "book", "chapter_key", "page_start", "page_end"),
                name="uniq_plan_item",
            ),
        ),
    ]
