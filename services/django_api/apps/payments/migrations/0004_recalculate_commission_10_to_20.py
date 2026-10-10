"""Recalculate historical payment splits that used the old 10% platform rate.

Rows whose commission is exactly 10% of the sale are rewritten to 20% so the
revenue ledger and open transactions match PlatformSettings (20%).
"""
from decimal import Decimal, ROUND_HALF_UP

from django.db import migrations

_HUNDRED = Decimal("100")
_OLD_PCT = Decimal("10")
_NEW_PCT = Decimal("20")
_CENT = Decimal("0.01")


def _money(value: Decimal) -> Decimal:
    return value.quantize(_CENT, rounding=ROUND_HALF_UP)


def _is_pct(sale: Decimal, commission: Decimal, pct: Decimal) -> bool:
    if sale is None or commission is None or sale == 0:
        return False
    return commission == _money(sale * pct / _HUNDRED)


def forwards(apps, schema_editor):
    PaymentTransaction = apps.get_model("payments", "PaymentTransaction")
    RevenueLedger = apps.get_model("payments", "RevenueLedger")

    for txn in PaymentTransaction.objects.all().iterator():
        sale = txn.amount
        if not _is_pct(sale, txn.commission_amount, _OLD_PCT):
            continue
        txn.commission_amount = _money(sale * _NEW_PCT / _HUNDRED)
        txn.save(update_fields=["commission_amount", "updated_at"])

    for ledger in RevenueLedger.objects.all().iterator():
        sale = ledger.sale_amount
        if not _is_pct(sale, ledger.commission_amount, _OLD_PCT):
            continue
        commission = _money(sale * _NEW_PCT / _HUNDRED)
        ledger.commission_amount = commission
        ledger.author_amount = _money(sale - commission)
        ledger.save(update_fields=["commission_amount", "author_amount"])


def backwards(apps, schema_editor):
    # Irreversible: rows that were already at 20% cannot be told apart from
    # ones this migration rewrote from 10%.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("payments", "0003_default_commission_percent_20"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
