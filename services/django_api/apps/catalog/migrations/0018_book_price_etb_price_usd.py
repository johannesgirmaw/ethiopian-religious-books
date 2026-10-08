from django.db import migrations, models


def copy_legacy_prices(apps, schema_editor):
    """Existing books have a single price. Copy it into the matching currency."""
    Book = apps.get_model("catalog", "Book")
    Book.objects.filter(currency__iexact="ETB").update(price_etb=models.F("price"))
    Book.objects.filter(currency__iexact="USD").update(price_usd=models.F("price"))


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0017_book_review_status_and_notes"),
    ]

    operations = [
        migrations.AddField(
            model_name="book",
            name="price_etb",
            field=models.DecimalField(
                decimal_places=2,
                default=0,
                help_text="List price in Ethiopian birr (ETB).",
                max_digits=12,
            ),
        ),
        migrations.AddField(
            model_name="book",
            name="price_usd",
            field=models.DecimalField(
                decimal_places=2,
                default=0,
                help_text="List price in US dollars (USD).",
                max_digits=12,
            ),
        ),
        migrations.RunPython(copy_legacy_prices, migrations.RunPython.noop),
    ]
