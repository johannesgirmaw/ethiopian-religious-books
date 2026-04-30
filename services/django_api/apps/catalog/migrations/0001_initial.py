import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Tag",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("slug", models.SlugField(max_length=64, unique=True)),
                ("label", models.CharField(max_length=200)),
            ],
            options={
                "db_table": "tags",
            },
        ),
        migrations.CreateModel(
            name="Book",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("title", models.CharField(max_length=500)),
                ("subtitle", models.CharField(blank=True, max_length=500)),
                ("summary", models.TextField(blank=True)),
                ("author_compiler", models.CharField(blank=True, max_length=500)),
                ("primary_language", models.CharField(default="am", max_length=32)),
                ("script_tags", models.JSONField(blank=True, default=list)),
                ("cover_object_key", models.CharField(blank=True, max_length=500)),
                (
                    "catalog_visibility",
                    models.CharField(
                        choices=[("published", "published"), ("hidden", "hidden")],
                        default="hidden",
                        max_length=20,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "created_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="books_created",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "books",
                "ordering": ["title"],
            },
        ),
        migrations.CreateModel(
            name="BookRevision",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("revision_number", models.PositiveIntegerField()),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("draft", "draft"),
                            ("published", "published"),
                            ("superseded", "superseded"),
                        ],
                        default="draft",
                        max_length=20,
                    ),
                ),
                ("manifest_object_key", models.CharField(blank=True, max_length=500)),
                ("content_format", models.CharField(default="html_chunks", max_length=64)),
                ("total_bytes", models.BigIntegerField(default=0)),
                ("cek_wrapped", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "book",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="revisions",
                        to="catalog.book",
                    ),
                ),
                (
                    "created_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="revisions_created",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "book_revisions",
                "ordering": ["book", "-revision_number"],
            },
        ),
        migrations.AddField(
            model_name="book",
            name="published_revision",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="+",
                to="catalog.bookrevision",
            ),
        ),
        migrations.CreateModel(
            name="BookTag",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                (
                    "book",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="catalog.book"),
                ),
                (
                    "tag",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="catalog.tag"),
                ),
            ],
            options={
                "db_table": "book_tags",
            },
        ),
        migrations.AddConstraint(
            model_name="bookrevision",
            constraint=models.UniqueConstraint(
                fields=("book", "revision_number"),
                name="uniq_book_revision_number",
            ),
        ),
        migrations.AddConstraint(
            model_name="booktag",
            constraint=models.UniqueConstraint(fields=("book", "tag"), name="uniq_book_tag"),
        ),
    ]
