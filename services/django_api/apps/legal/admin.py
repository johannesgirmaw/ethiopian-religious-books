from django.contrib import admin

from apps.legal.models import LegalAcceptance, LegalDocument


@admin.register(LegalDocument)
class LegalDocumentAdmin(admin.ModelAdmin):
    list_display = ("doc_type", "version", "effective_at")


@admin.register(LegalAcceptance)
class LegalAcceptanceAdmin(admin.ModelAdmin):
    list_display = ("user", "legal_document", "accepted_at")
