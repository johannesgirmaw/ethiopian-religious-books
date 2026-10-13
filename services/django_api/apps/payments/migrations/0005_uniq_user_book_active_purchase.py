"""One open or completed purchase per buyer per book.

Older duplicate checkouts (a buyer starting the form more than once) are
cancelled so the partial unique constraint can be added. When several
completed rows exist, the newest one is kept and the older ones are cancelled.
"""

from django.db import migrations, models
from django.db.models import Count


ACTIVE = ("pending", "on_review", "approved", "completed")
RANK = {"completed": 0, "approved": 1, "on_review": 2, "pending": 3}


def dedupe_active_purchases(apps, schema_editor):
    PaymentTransaction = apps.get_model("payments", "PaymentTransaction")
    groups = (
        PaymentTransaction.objects.filter(status__in=ACTIVE)
        .order_by()
        .values("user_id", "book_id")
        .annotate(n=Count("id"))
        .filter(n__gt=1)
    )
    for group in groups:
        rows = list(
            PaymentTransaction.objects.filter(
                user_id=group["user_id"],
                book_id=group["book_id"],
                status__in=ACTIVE,
            )
        )
        if len(rows) < 2:
            continue
        completed = [row for row in rows if row.status == "completed"]
        if completed:
            keep = max(completed, key=lambda row: row.created_at)
        else:

            def sort_key(row):
                created = row.created_at.timestamp() if row.created_at else 0
                return (RANK.get(row.status, 9), -created)

            keep = min(rows, key=sort_key)
        for extra in rows:
            if extra.pk == keep.pk:
                continue
            extra.status = "cancelled"
            extra.save(update_fields=["status"])


class Migration(migrations.Migration):

    dependencies = [
        ("payments", "0004_recalculate_commission_10_to_20"),
    ]

    operations = [
        migrations.RunPython(dedupe_active_purchases, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="paymenttransaction",
            constraint=models.UniqueConstraint(
                condition=models.Q(
                    status__in=["pending", "on_review", "approved", "completed"]
                ),
                fields=("user", "book"),
                name="uniq_user_book_active_purchase",
            ),
        ),
    ]
