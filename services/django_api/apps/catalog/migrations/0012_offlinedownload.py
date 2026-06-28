import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalog", "0011_book_author_book_commission_percent_book_currency_and_more"),
    ]

    operations = [
        migrations.CreateModel(
            name="OfflineDownload",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("device_id", models.CharField(max_length=128)),
                ("platform", models.CharField(blank=True, max_length=40)),
                ("revision_id", models.CharField(blank=True, max_length=64)),
                ("first_downloaded_at", models.DateTimeField(auto_now_add=True)),
                ("last_licensed_at", models.DateTimeField(auto_now=True)),
                ("license_expires_at", models.DateTimeField(blank=True, null=True)),
                ("renew_count", models.PositiveIntegerField(default=0)),
                (
                    "book",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="offline_downloads",
                        to="catalog.book",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="offline_downloads",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "offline_downloads",
                "ordering": ["-last_licensed_at"],
                "verbose_name": "Offline book download",
                "verbose_name_plural": "Offline book downloads",
            },
        ),
        migrations.AddIndex(
            model_name="offlinedownload",
            index=models.Index(
                fields=["user", "-last_licensed_at"], name="idx_offdl_user"
            ),
        ),
        migrations.AddIndex(
            model_name="offlinedownload",
            index=models.Index(
                fields=["book", "-last_licensed_at"], name="idx_offdl_book"
            ),
        ),
        migrations.AddConstraint(
            model_name="offlinedownload",
            constraint=models.UniqueConstraint(
                fields=("user", "book", "device_id"), name="uniq_offline_download"
            ),
        ),
    ]
