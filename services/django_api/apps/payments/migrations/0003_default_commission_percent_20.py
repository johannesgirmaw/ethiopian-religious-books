# Raise the platform default commission from 10% → 20% of book sale price.
from decimal import Decimal

from django.db import migrations, models


_OLD = Decimal("10.00")
_NEW = Decimal("20.00")


def forwards(apps, schema_editor):
    PlatformSettings = apps.get_model("payments", "PlatformSettings")
    Book = apps.get_model("catalog", "Book")
    AuthorCommission = apps.get_model("payments", "AuthorCommission")

    PlatformSettings.objects.filter(default_commission_percent=_OLD).update(
        default_commission_percent=_NEW
    )
    # Per-book / per-author overrides that still mirror the old platform default
    # should follow the new rate so sales keep using 20%.
    Book.objects.filter(commission_percent=_OLD).update(commission_percent=_NEW)
    AuthorCommission.objects.filter(commission_percent=_OLD).update(
        commission_percent=_NEW
    )


def backwards(apps, schema_editor):
    PlatformSettings = apps.get_model("payments", "PlatformSettings")
    # Only reverse the platform singleton. Book/author rows that were already
    # 20% before this migration cannot be distinguished from ones we updated.
    PlatformSettings.objects.filter(default_commission_percent=_NEW).update(
        default_commission_percent=_OLD
    )


class Migration(migrations.Migration):

    dependencies = [
        ("payments", "0002_authorprofile_photo_object_key_authorapplication"),
        ("catalog", "0011_book_author_book_commission_percent_book_currency_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="platformsettings",
            name="default_commission_percent",
            field=models.DecimalField(
                decimal_places=2, default=Decimal("20.00"), max_digits=5
            ),
        ),
        migrations.RunPython(forwards, backwards),
    ]
