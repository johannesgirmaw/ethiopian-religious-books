from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0019_book_pin_order"),
    ]

    operations = [
        migrations.AddField(
            model_name="bookrevision",
            name="preview_object_key",
            field=models.CharField(blank=True, max_length=500),
        ),
        migrations.AddField(
            model_name="bookrevision",
            name="preview_page_numbers",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="bookrevision",
            name="preview_sha256",
            field=models.CharField(blank=True, max_length=64),
        ),
    ]
