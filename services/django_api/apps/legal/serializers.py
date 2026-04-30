from rest_framework import serializers

from apps.legal.models import LegalDocument


class LegalDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = LegalDocument
        fields = ("id", "doc_type", "version", "content_url", "effective_at")


class LegalAcceptanceItemSerializer(serializers.Serializer):
    legal_document_id = serializers.UUIDField()
    accepted_at = serializers.DateTimeField()


class LegalAcceptanceBulkSerializer(serializers.Serializer):
    acceptances = LegalAcceptanceItemSerializer(many=True)
