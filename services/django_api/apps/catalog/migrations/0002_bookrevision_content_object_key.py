from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="bookrevision",
            name="content_object_key",
            field=models.CharField(
                blank=True,
                help_text="Primary encrypted (or dev plaintext) package blob in object storage.",
                max_length=500,
            ),
        ),
    ]
