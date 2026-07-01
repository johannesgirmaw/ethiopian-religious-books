"""Trigram GIN index for fast verse full-text (contains) search.

PostgreSQL-only: guarded on connection.vendor so the migration is a harmless
no-op on SQLite (used in some dev setups). On Postgres it enables the pg_trgm
extension and adds a GIN trigram index on ``bible_verses.text_normalized``,
which makes the ``__contains`` search used by the /bible/search endpoint fast.
"""

from django.db import migrations


def create_trigram_index(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    schema_editor.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    schema_editor.execute(
        "CREATE INDEX IF NOT EXISTS idx_bible_verse_text_trgm "
        "ON bible_verses USING gin (text_normalized gin_trgm_ops)"
    )


def drop_trigram_index(apps, schema_editor):
    if schema_editor.connection.vendor != "postgresql":
        return
    schema_editor.execute("DROP INDEX IF EXISTS idx_bible_verse_text_trgm")


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0013_book_bible_name_en_book_bible_short_name_am_and_more"),
    ]

    operations = [
        migrations.RunPython(create_trigram_index, drop_trigram_index),
    ]
