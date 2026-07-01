"""Seed the "Bible" catalogue category and tag existing Bible books with it.

Bible books are shown in the catalogue only under this category; the client
filters on ``genre="bible"`` and hides them from the "All" feed.
"""

from django.db import migrations

BIBLE = ("bible", "Bible", "መጽሐፍ ቅዱስ", "menu_book_rounded", 0)


def seed(apps, schema_editor):
    Genre = apps.get_model("catalog", "Genre")
    slug, label, label_am, icon, ordinal = BIBLE
    Genre.objects.update_or_create(
        slug=slug,
        defaults={
            "label": label,
            "label_am": label_am,
            "icon": icon,
            "ordinal": ordinal,
            "is_active": True,
        },
    )
    Book = apps.get_model("catalog", "Book")
    Book.objects.filter(is_bible=True).update(genre="bible")


def unseed(apps, schema_editor):
    Genre = apps.get_model("catalog", "Genre")
    Genre.objects.filter(slug=BIBLE[0]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0015_alter_bibleverse_options_and_more"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
