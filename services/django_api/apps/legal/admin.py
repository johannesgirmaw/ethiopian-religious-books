from django.contrib import admin
from unfold.admin import ModelAdmin

from apps.legal.models import LegalAcceptance, LegalDocument


@admin.register(LegalDocument)
class LegalDocumentAdmin(ModelAdmin):
    list_display = ("doc_type", "version", "effective_at", "content_url")
    list_filter = ("doc_type",)
    search_fields = ("doc_type", "content_url")
    ordering = ("doc_type", "-version")


@admin.register(LegalAcceptance)
class LegalAcceptanceAdmin(ModelAdmin):
    list_display = ("user", "legal_document", "accepted_at")
    list_filter = ("legal_document",)
    search_fields = ("user__email", "legal_document__doc_type")
    date_hierarchy = "accepted_at"
    raw_id_fields = ("user", "legal_document")
