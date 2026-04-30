from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.legal.models import LegalAcceptance, LegalDocument
from apps.legal.serializers import LegalAcceptanceBulkSerializer, LegalDocumentSerializer


class LegalDocumentListView(APIView):
    """Latest document per doc_type (terms, privacy)."""

    permission_classes = [AllowAny]

    def get(self, request):
        out = []
        for doc_type in ("terms", "privacy"):
            doc = LegalDocument.objects.filter(doc_type=doc_type).order_by("-version").first()
            if doc:
                out.append(LegalDocumentSerializer(doc).data)
        return Response({"documents": out})


class LegalAcceptanceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ser = LegalAcceptanceBulkSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        for item in ser.validated_data["acceptances"]:
            try:
                doc = LegalDocument.objects.get(pk=item["legal_document_id"])
            except LegalDocument.DoesNotExist:
                return Response(
                    {"error": {"code": "NOT_FOUND", "message": "Invalid legal_document_id"}},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            LegalAcceptance.objects.update_or_create(
                user=request.user,
                legal_document=doc,
                defaults={"accepted_at": item["accepted_at"]},
            )
        return Response(status=status.HTTP_204_NO_CONTENT)
