import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def backfill_review_status(apps, schema_editor):
    """Existing live (published) books predate the review workflow — mark them
    ``reviewed`` so they stay publishable after any future unpublish/republish
    (the new publish gate requires ``review_status == 'reviewed'``)."""
    Book = apps.get_model("catalog", "Book")
    Book.objects.filter(catalog_visibility="published").update(review_status="reviewed")


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalog", "0016_seed_bible_genre"),
    ]

    operations = [
        migrations.AddField(
            model_name="book",
            name="review_status",
            field=models.CharField(
                choices=[
                    ("draft", "draft"),
                    ("in_review", "in review"),
                    ("reviewed", "reviewed"),
                ],
                db_index=True,
                default="draft",
                max_length=20,
            ),
        ),
        migrations.CreateModel(
            name="BookReviewNote",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "decision",
                    models.CharField(
                        choices=[
                            ("submitted", "submitted for review"),
                            ("approved", "approved"),
                            ("changes_requested", "changes requested"),
                            ("withdrawn", "withdrawn"),
                        ],
                        max_length=20,
                    ),
                ),
                ("comment", models.TextField(blank=True, default="")),
                ("comment_plain", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "book",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="review_notes",
                        to="catalog.book",
                    ),
                ),
                (
                    "reviewer",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="book_reviews_made",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "book_review_notes",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="bookreviewnote",
            index=models.Index(
                fields=["book", "-created_at"], name="idx_review_note_book"
            ),
        ),
        migrations.RunPython(backfill_review_status, migrations.RunPython.noop),
    ]
