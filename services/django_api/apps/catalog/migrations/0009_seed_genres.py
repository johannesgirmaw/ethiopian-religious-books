from django.db import migrations

SEED = [
    ("psalms", "Psalms & Mezmur", "መዝሙር እና ዳዊት", "music_note_rounded", 1),
    ("marian", "Marian", "ማርያማዊ", "favorite_rounded", 2),
    ("liturgy", "Liturgy", "ቅዳሴ", "local_fire_department_rounded", 3),
    ("synaxarium", "Synaxarium", "ስንክሳር", "calendar_month_rounded", 4),
    ("saints", "Saints & Gedl", "ገድላት", "self_improvement_rounded", 5),
    ("other", "General", "አጠቃላይ", "menu_book_rounded", 99),
]


def seed_genres(apps, schema_editor):
    Genre = apps.get_model("catalog", "Genre")
    for slug, label, label_am, icon, ordinal in SEED:
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


def unseed_genres(apps, schema_editor):
    Genre = apps.get_model("catalog", "Genre")
    Genre.objects.filter(slug__in=[s[0] for s in SEED]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0008_genre_alter_book_genre"),
    ]

    operations = [
        migrations.RunPython(seed_genres, unseed_genres),
    ]
