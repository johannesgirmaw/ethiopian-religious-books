import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0006_passwordresetcode"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="phone",
            field=models.CharField(blank=True, max_length=20, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="user",
            name="phone_verified_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="user",
            name="telegram_chat_id",
            field=models.BigIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="user",
            name="telegram_linked_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="user",
            name="telegram_user_id",
            field=models.BigIntegerField(blank=True, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="user",
            name="telegram_username",
            field=models.CharField(blank=True, default="", max_length=64),
        ),
        migrations.AddField(
            model_name="passwordresetcode",
            name="channel",
            field=models.CharField(
                choices=[("email", "email"), ("telegram", "telegram")],
                default="email",
                max_length=16,
            ),
        ),
        migrations.AddField(
            model_name="passwordresetcode",
            name="purpose",
            field=models.CharField(
                choices=[("password_reset", "password_reset")],
                default="password_reset",
                max_length=32,
            ),
        ),
        migrations.CreateModel(
            name="TelegramAuthSession",
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
                ("phone", models.CharField(max_length=20)),
                (
                    "purpose",
                    models.CharField(
                        choices=[("login", "login"), ("phone_link", "phone_link")],
                        max_length=32,
                    ),
                ),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("pending", "pending"),
                            ("awaiting_contact", "awaiting_contact"),
                            ("code_sent", "code_sent"),
                            ("verified", "verified"),
                            ("expired", "expired"),
                        ],
                        default="pending",
                        max_length=32,
                    ),
                ),
                ("telegram_user_id", models.BigIntegerField(blank=True, null=True)),
                ("telegram_chat_id", models.BigIntegerField(blank=True, null=True)),
                (
                    "telegram_username",
                    models.CharField(blank=True, default="", max_length=64),
                ),
                ("code_hash", models.CharField(blank=True, default="", max_length=64)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("expires_at", models.DateTimeField()),
                ("code_expires_at", models.DateTimeField(blank=True, null=True)),
                ("consumed_at", models.DateTimeField(blank=True, null=True)),
                (
                    "requested_ip",
                    models.GenericIPAddressField(blank=True, null=True),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="telegram_auth_sessions",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "telegram_auth_sessions",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="telegramauthsession",
            index=models.Index(fields=["phone", "status"], name="tg_auth_phone_status"),
        ),
        migrations.AddIndex(
            model_name="telegramauthsession",
            index=models.Index(
                fields=["telegram_chat_id", "status"],
                name="tg_auth_chat_status",
            ),
        ),
        migrations.AddIndex(
            model_name="telegramauthsession",
            index=models.Index(fields=["expires_at"], name="tg_auth_expires"),
        ),
    ]
