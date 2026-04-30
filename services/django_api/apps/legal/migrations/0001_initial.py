import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="LegalDocument",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("doc_type", models.CharField(max_length=32)),
                ("version", models.PositiveIntegerField()),
                ("content_url", models.URLField(max_length=500)),
                ("effective_at", models.DateTimeField()),
            ],
            options={
                "db_table": "legal_documents",
                "ordering": ["doc_type", "-version"],
            },
        ),
        migrations.CreateModel(
            name="LegalAcceptance",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("accepted_at", models.DateTimeField()),
                (
                    "legal_document",
                    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="legal.legaldocument"),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="legal_acceptances",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "legal_acceptances",
            },
        ),
        migrations.AddConstraint(
            model_name="legaldocument",
            constraint=models.UniqueConstraint(
                fields=("doc_type", "version"),
                name="uniq_legal_doc_type_version",
            ),
        ),
        migrations.AddConstraint(
            model_name="legalacceptance",
            constraint=models.UniqueConstraint(
                fields=("user", "legal_document"),
                name="uniq_user_legal_doc",
            ),
        ),
    ]
