import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0004_alter_user_role"),
    ]

    operations = [
        migrations.CreateModel(
            name="UserDevice",
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
                (
                    "public_key",
                    models.TextField(
                        blank=True,
                        help_text="PEM/base64 device public key used to wrap content keys.",
                    ),
                ),
                ("platform", models.CharField(blank=True, max_length=40)),
                ("label", models.CharField(blank=True, max_length=120)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("last_seen", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="devices",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "user_devices",
                "ordering": ["-last_seen"],
            },
        ),
        migrations.AddConstraint(
            model_name="userdevice",
            constraint=models.UniqueConstraint(
                fields=("user", "device_id"), name="uniq_user_device"
            ),
        ),
    ]
