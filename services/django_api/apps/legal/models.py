import uuid

from django.conf import settings
from django.db import models


class LegalDocument(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doc_type = models.CharField(max_length=32)
    version = models.PositiveIntegerField()
    content_url = models.URLField(max_length=500)
    effective_at = models.DateTimeField()

    class Meta:
        db_table = "legal_documents"
        constraints = [
            models.UniqueConstraint(fields=["doc_type", "version"], name="uniq_legal_doc_type_version"),
        ]
        ordering = ["doc_type", "-version"]


class LegalAcceptance(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="legal_acceptances")
    legal_document = models.ForeignKey(LegalDocument, on_delete=models.CASCADE)
    accepted_at = models.DateTimeField()

    class Meta:
        db_table = "legal_acceptances"
        constraints = [
            models.UniqueConstraint(fields=["user", "legal_document"], name="uniq_user_legal_doc"),
        ]
