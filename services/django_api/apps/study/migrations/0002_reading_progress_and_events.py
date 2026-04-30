import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models
import uuid


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalog", "0006_bookpage_title"),
        ("study", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ReaderEvent",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("event_name", models.CharField(max_length=80)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(blank=True, null=True)),
                ("payload", models.JSONField(blank=True, default=dict)),
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
                        related_name="reader_events",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "reader_events", "ordering": ["-created_at"]},
        ),
        migrations.CreateModel(
            name="UserReadingProgress",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(blank=True, null=True)),
                ("progress_percent", models.PositiveSmallIntegerField(default=0)),
                ("last_read_at", models.DateTimeField(auto_now=True)),
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
                        related_name="reading_progress_rows",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"db_table": "user_reading_progress", "ordering": ["-last_read_at"]},
        ),
        migrations.AddConstraint(
            model_name="userreadingprogress",
            constraint=models.UniqueConstraint(
                fields=("user", "book"),
                name="uniq_user_book_progress",
            ),
        ),
        migrations.AddIndex(
            model_name="readerevent",
            index=models.Index(
                fields=["user", "event_name", "-created_at"],
                name="idx_reader_event_user_name",
            ),
        ),
        migrations.AddIndex(
            model_name="readerevent",
            index=models.Index(
                fields=["book", "event_name", "-created_at"],
                name="idx_reader_event_book_name",
            ),
        ),
    ]
