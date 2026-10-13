from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0018_book_price_etb_price_usd"),
    ]

    operations = [
        migrations.AddField(
            model_name="book",
            name="pin_order",
            field=models.PositiveIntegerField(
                blank=True,
                db_index=True,
                help_text="Ascending pin rank for Explore sorting; null when unpinned.",
                null=True,
            ),
        ),
    ]
