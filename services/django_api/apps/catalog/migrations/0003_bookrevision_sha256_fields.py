from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0002_bookrevision_content_object_key"),
    ]

    operations = [
        migrations.AddField(
            model_name="bookrevision",
            name="manifest_sha256",
            field=models.CharField(blank=True, max_length=64),
        ),
        migrations.AddField(
            model_name="bookrevision",
            name="content_sha256",
            field=models.CharField(blank=True, max_length=64),
        ),
    ]
