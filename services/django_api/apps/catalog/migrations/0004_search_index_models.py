from django.db import migrations, models
import django.db.models.deletion
import uuid


def backfill_book_search_text(apps, schema_editor):
    del schema_editor
    Book = apps.get_model("catalog", "Book")
    from apps.catalog.search_normalization import normalize_search_text

    for book in Book.objects.all().iterator():
        book.search_text_normalized = normalize_search_text(
            " ".join(
                [
                    book.title or "",
                    book.subtitle or "",
                    book.summary or "",
                    book.author_compiler or "",
                ]
            )
        )
        book.save(update_fields=["search_text_normalized"])


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0003_bookrevision_sha256_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="book",
            name="search_text_normalized",
            field=models.TextField(blank=True, db_index=True, default=""),
        ),
        migrations.CreateModel(
            name="BookChapter",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chapter_key", models.CharField(max_length=200)),
                ("title", models.CharField(blank=True, max_length=500)),
                ("ordinal", models.PositiveIntegerField(default=0)),
                ("start_chunk", models.CharField(blank=True, max_length=200)),
                ("end_chunk", models.CharField(blank=True, max_length=200)),
                (
                    "revision",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="chapters",
                        to="catalog.bookrevision",
                    ),
                ),
            ],
            options={
                "db_table": "book_chapters",
                "ordering": ["revision", "ordinal", "chapter_key"],
            },
        ),
        migrations.CreateModel(
            name="BookContentIndex",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("chunk_key", models.CharField(blank=True, max_length=200)),
                ("chapter_key", models.CharField(blank=True, max_length=200)),
                ("page_number", models.PositiveIntegerField(default=1)),
                ("text_plain", models.TextField(blank=True, default="")),
                ("text_normalized", models.TextField(blank=True, db_index=True, default="")),
                (
                    "book",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="content_index_rows",
                        to="catalog.book",
                    ),
                ),
                (
                    "revision",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="content_index_rows",
                        to="catalog.bookrevision",
                    ),
                ),
            ],
            options={
                "db_table": "book_content_index",
                "ordering": ["revision", "page_number", "chunk_key"],
            },
        ),
        migrations.CreateModel(
            name="BookPage",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("page_number", models.PositiveIntegerField()),
                ("chunk_key", models.CharField(blank=True, max_length=200)),
                ("text_plain", models.TextField(blank=True, default="")),
                (
                    "chapter",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="pages",
                        to="catalog.bookchapter",
                    ),
                ),
                (
                    "revision",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="pages",
                        to="catalog.bookrevision",
                    ),
                ),
            ],
            options={
                "db_table": "book_pages",
                "ordering": ["revision", "page_number"],
            },
        ),
        migrations.AddConstraint(
            model_name="bookchapter",
            constraint=models.UniqueConstraint(
                fields=("revision", "chapter_key"),
                name="uniq_revision_chapter_key",
            ),
        ),
        migrations.AddConstraint(
            model_name="bookpage",
            constraint=models.UniqueConstraint(
                fields=("revision", "page_number"),
                name="uniq_revision_page_number",
            ),
        ),
        migrations.AddIndex(
            model_name="bookcontentindex",
            index=models.Index(fields=["book", "revision"], name="idx_bci_book_revision"),
        ),
        migrations.AddIndex(
            model_name="bookcontentindex",
            index=models.Index(fields=["revision", "chapter_key"], name="idx_bci_rev_chapter"),
        ),
        migrations.AddIndex(
            model_name="bookcontentindex",
            index=models.Index(fields=["revision", "page_number"], name="idx_bci_rev_page"),
        ),
        migrations.RunPython(backfill_book_search_text, migrations.RunPython.noop),
    ]
