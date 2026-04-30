from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0005_book_chapters_draft"),
    ]

    operations = [
        migrations.AddField(
            model_name="bookpage",
            name="page_title",
            field=models.CharField(blank=True, max_length=300),
        ),
    ]
