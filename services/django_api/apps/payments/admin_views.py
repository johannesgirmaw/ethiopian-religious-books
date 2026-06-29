from django.db.models import Count, Sum
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.payments.enums import TERMINAL_STATUSES, TransactionStatus
from apps.payments.models import (
    AuthorCommission,
    Bank,
    GatewayCredential,
    PaymentTransaction,
    PlatformSettings,
)
from apps.payments.permissions import IsPlatformAdmin
from apps.payments.serializers import (
    AuthorCommissionSerializer,
    BankSerializer,
    GatewayCredentialSerializer,
    PaymentTransactionSerializer,
    PlatformSettingsSerializer,
)
from apps.payments.services import complete_transaction, record_audit, reject_transaction


class _AdminView(APIView):
    permission_classes = [IsPlatformAdmin]


class AdminPaymentDashboardView(_AdminView):
    def get(self, request):
        from apps.payments.models import RevenueLedger

        ledger = RevenueLedger.objects.aggregate(
            gross_revenue=Sum("sale_amount"),
            platform_revenue=Sum("commission_amount"),
            author_revenue=Sum("author_amount"),
        )
        txns = PaymentTransaction.objects.aggregate(
            completed=Count("id", filter=_qfilter(status=TransactionStatus.COMPLETED)),
            pending_reviews=Count("id", filter=_qfilter(status=TransactionStatus.ON_REVIEW)),
        )
        return Response(
            {
                "total_sales": txns["completed"] or 0,
                "gross_revenue": str(ledger["gross_revenue"] or 0),
                "platform_revenue": str(ledger["platform_revenue"] or 0),
                "author_revenue": str(ledger["author_revenue"] or 0),
                "pending_reviews": txns["pending_reviews"] or 0,
                "completed_transactions": txns["completed"] or 0,
            }
        )


class AdminTransactionsView(_AdminView):
    @extend_schema(responses=PaymentTransactionSerializer(many=True))
    def get(self, request):
        qs = PaymentTransaction.objects.select_related("book", "bank", "user")
        status_filter = request.query_params.get("status")
        method_filter = request.query_params.get("method")
        if status_filter:
            qs = qs.filter(status=status_filter)
        if method_filter:
            qs = qs.filter(payment_method=method_filter)
        return Response({"items": PaymentTransactionSerializer(qs, many=True, context={"request": request}).data})


class AdminTransactionDetailView(_AdminView):
    @extend_schema(responses=PaymentTransactionSerializer)
    def get(self, request, transaction_id):
        txn = get_object_or_404(PaymentTransaction, pk=transaction_id)
        return Response(PaymentTransactionSerializer(txn, context={"request": request}).data)


class AdminApproveTransactionView(_AdminView):
    @extend_schema(request=None, responses=PaymentTransactionSerializer)
    def post(self, request, transaction_id):
        txn = get_object_or_404(PaymentTransaction, pk=transaction_id)
        if txn.status in TERMINAL_STATUSES:
            return Response(
                {"error": {"code": "LOCKED", "message": "Transaction already finalised."}},
                status=status.HTTP_409_CONFLICT,
            )
        txn = complete_transaction(txn, reviewer=request.user)
        record_audit(
            actor=request.user,
            action="transaction.approve",
            target_type="PaymentTransaction",
            target_id=txn.id,
            metadata={"amount": str(txn.amount)},
            request=request,
        )
        return Response(PaymentTransactionSerializer(txn, context={"request": request}).data)


class AdminRejectTransactionView(_AdminView):
    @extend_schema(request=None, responses=PaymentTransactionSerializer)
    def post(self, request, transaction_id):
        txn = get_object_or_404(PaymentTransaction, pk=transaction_id)
        if txn.status in TERMINAL_STATUSES:
            return Response(
                {"error": {"code": "LOCKED", "message": "Transaction already finalised."}},
                status=status.HTTP_409_CONFLICT,
            )
        note = (request.data.get("note") or "").strip()
        txn = reject_transaction(txn, reviewer=request.user, note=note)
        record_audit(
            actor=request.user,
            action="transaction.reject",
            target_type="PaymentTransaction",
            target_id=txn.id,
            metadata={"note": note},
            request=request,
        )
        return Response(PaymentTransactionSerializer(txn, context={"request": request}).data)


class AdminBanksView(_AdminView):
    @extend_schema(responses=BankSerializer(many=True))
    def get(self, request):
        return Response({"items": BankSerializer(Bank.objects.all(), many=True).data})

    @extend_schema(request=BankSerializer, responses=BankSerializer)
    def post(self, request):
        ser = BankSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        bank = ser.save()
        record_audit(
            actor=request.user,
            action="bank.create",
            target_type="Bank",
            target_id=bank.id,
            request=request,
        )
        return Response(BankSerializer(bank).data, status=status.HTTP_201_CREATED)


class AdminBankDetailView(_AdminView):
    @extend_schema(responses=BankSerializer)
    def get(self, request, bank_id):
        return Response(BankSerializer(get_object_or_404(Bank, pk=bank_id)).data)

    @extend_schema(request=BankSerializer, responses=BankSerializer)
    def patch(self, request, bank_id):
        bank = get_object_or_404(Bank, pk=bank_id)
        ser = BankSerializer(bank, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        record_audit(
            actor=request.user,
            action="bank.update",
            target_type="Bank",
            target_id=bank.id,
            request=request,
        )
        return Response(BankSerializer(bank).data)

    def delete(self, request, bank_id):
        bank = get_object_or_404(Bank, pk=bank_id)
        record_audit(
            actor=request.user,
            action="bank.delete",
            target_type="Bank",
            target_id=bank.id,
            request=request,
        )
        bank.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AdminPlatformSettingsView(_AdminView):
    @extend_schema(responses=PlatformSettingsSerializer)
    def get(self, request):
        return Response(PlatformSettingsSerializer(PlatformSettings.get_solo()).data)

    @extend_schema(request=PlatformSettingsSerializer, responses=PlatformSettingsSerializer)
    def patch(self, request):
        ps = PlatformSettings.get_solo()
        ser = PlatformSettingsSerializer(ps, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        record_audit(
            actor=request.user,
            action="settings.update",
            target_type="PlatformSettings",
            target_id=ps.id,
            metadata={k: str(v) for k, v in request.data.items()},
            request=request,
        )
        return Response(PlatformSettingsSerializer(ps).data)


class AdminGatewayCredentialsView(_AdminView):
    @extend_schema(responses=GatewayCredentialSerializer(many=True))
    def get(self, request):
        creds = GatewayCredential.objects.all()
        return Response({"items": GatewayCredentialSerializer(creds, many=True).data})


class AdminGatewayCredentialDetailView(_AdminView):
    """Upsert credentials for a provider; secrets are stored encrypted."""

    @extend_schema(request=GatewayCredentialSerializer, responses=GatewayCredentialSerializer)
    def put(self, request, provider):
        if provider not in dict(GatewayCredential.Provider.choices):
            return Response(
                {"error": {"code": "UNKNOWN_PROVIDER", "message": "Unknown gateway."}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        cred, _ = GatewayCredential.objects.get_or_create(provider=provider)
        ser = GatewayCredentialSerializer(cred, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        record_audit(
            actor=request.user,
            action="credential.update",
            target_type="GatewayCredential",
            target_id=cred.id,
            metadata={"provider": provider},
            request=request,
        )
        return Response(GatewayCredentialSerializer(cred).data)


class AdminAuthorCommissionsView(_AdminView):
    @extend_schema(responses=AuthorCommissionSerializer(many=True))
    def get(self, request):
        qs = AuthorCommission.objects.select_related("author")
        return Response({"items": AuthorCommissionSerializer(qs, many=True).data})

    @extend_schema(request=AuthorCommissionSerializer, responses=AuthorCommissionSerializer)
    def post(self, request):
        ser = AuthorCommissionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        # Upsert so re-assigning an author updates the existing override.
        author = ser.validated_data["author"]
        obj, _ = AuthorCommission.objects.update_or_create(
            author=author,
            defaults={"commission_percent": ser.validated_data["commission_percent"]},
        )
        record_audit(
            actor=request.user,
            action="author_commission.set",
            target_type="AuthorCommission",
            target_id=obj.id,
            metadata={"percent": str(obj.commission_percent)},
            request=request,
        )
        return Response(
            AuthorCommissionSerializer(obj).data, status=status.HTTP_201_CREATED
        )


class AdminAuthorCommissionDetailView(_AdminView):
    @extend_schema(request=AuthorCommissionSerializer, responses=AuthorCommissionSerializer)
    def patch(self, request, commission_id):
        obj = get_object_or_404(AuthorCommission, pk=commission_id)
        ser = AuthorCommissionSerializer(obj, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(AuthorCommissionSerializer(obj).data)

    def delete(self, request, commission_id):
        obj = get_object_or_404(AuthorCommission, pk=commission_id)
        record_audit(
            actor=request.user,
            action="author_commission.remove",
            target_type="AuthorCommission",
            target_id=obj.id,
            request=request,
        )
        obj.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


def _qfilter(**kwargs):
    """Small helper so aggregate filters read cleanly above."""
    from django.db.models import Q

    return Q(**kwargs)
