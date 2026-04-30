from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0004_search_index_models"),
    ]

    operations = [
        migrations.AddField(
            model_name="book",
            name="chapters_draft",
            field=models.JSONField(blank=True, default=list),
        ),
    ]
