import logging
import uuid

from django.conf import settings as dj_settings
from django.db import IntegrityError
from django.db.models import Count, Sum
from django.http import Http404, HttpResponse
from django.shortcuts import get_object_or_404
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.authentication import SessionAuthentication
from rest_framework.exceptions import APIException
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from apps.catalog.storage_s3 import (
    dev_presign_endpoint_from_request,
    is_object_storage_configured,
    presign_put,
)
from apps.payments.enums import (
    AuthorApplicationStatus,
    MANUAL_METHODS,
    ONLINE_METHODS,
    PaymentMethod,
    TERMINAL_STATUSES,
    TransactionStatus,
)
from apps.payments.gateways.base import GatewayError, GatewayNotConfigured
from apps.payments.gateways.registry import get_gateway
from apps.payments.models import (
    AuthorApplication,
    AuthorProfile,
    Bank,
    PaymentTransaction,
    PlatformSettings,
    RevenueLedger,
)
from apps.payments.permissions import IsAuthor
from apps.payments.receipts import read_receipt, receipt_content_type, store_receipt
from apps.payments.serializers import (
    AuthorApplicationSerializer,
    AuthorProfileSerializer,
    CreateTransactionSerializer,
    PaymentTransactionSerializer,
    PublicBankSerializer,
    SubmitReceiptSerializer,
)
from apps.payments.services import (
    compute_amounts,
    record_audit,
    submit_author_application,
)

logger = logging.getLogger(__name__)

_ALLOWED_PHOTO_TYPES = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


def _feature_disabled_response():
    if not getattr(dj_settings, "FEATURE_PAYMENTS", True):
        return Response(
            {"error": {"code": "FEATURE_DISABLED", "message": "Payments are disabled."}},
            status=status.HTTP_404_NOT_FOUND,
        )
    return None


class FeatureDisabled(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    default_detail = "Payments are disabled."
    default_code = "FEATURE_DISABLED"


class _PaymentsView(APIView):
    permission_classes = [IsAuthenticated]

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if not getattr(dj_settings, "FEATURE_PAYMENTS", True):
            raise FeatureDisabled()


class PaymentMethodsView(_PaymentsView):
    """Methods the platform currently accepts."""

    def get(self, request):
        ps = PlatformSettings.get_solo()
        return Response(
            {
                "methods": ps.enabled_methods(),
                "manual_payment_enabled": ps.manual_payment_enabled,
            }
        )


class EntitlementsView(_PaymentsView):
    """Books the current user is entitled to read because they completed a
    purchase. The reader/buy gate uses this so a paid book opens directly
    instead of sending the buyer back to checkout."""

    def get(self, request):
        ids = (
            PaymentTransaction.objects.filter(
                user=request.user, status=TransactionStatus.COMPLETED
            )
            .values_list("book_id", flat=True)
            .distinct()
        )
        return Response({"book_ids": [str(i) for i in ids]})


class BankListView(_PaymentsView):
    """Active banks for the manual bank-transfer flow."""

    @extend_schema(responses=PublicBankSerializer(many=True))
    def get(self, request):
        banks = Bank.objects.filter(is_active=True)
        return Response({"items": PublicBankSerializer(banks, many=True).data})


class PaymentTransactionsView(_PaymentsView):
    @extend_schema(responses=PaymentTransactionSerializer(many=True))
    def get(self, request):
        qs = PaymentTransaction.objects.filter(user=request.user).select_related(
            "book", "bank"
        )
        return Response({"items": PaymentTransactionSerializer(qs, many=True, context={"request": request}).data})

    @extend_schema(
        request=CreateTransactionSerializer, responses=PaymentTransactionSerializer
    )
    def post(self, request):
        ser = CreateTransactionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        book = ser.validated_data["book"]
        method = ser.validated_data["payment_method"]
        bank = ser.validated_data.get("bank")

        ps = PlatformSettings.get_solo()
        if not ps.is_method_enabled(method):
            return Response(
                {"error": {"code": "METHOD_DISABLED", "message": "Payment method unavailable."}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        amounts = compute_amounts(book, ps)
        if amounts["sale_amount"] <= 0:
            return Response(
                {"error": {"code": "NOT_FOR_SALE", "message": "This book is not for sale."}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        txn = PaymentTransaction.objects.create(
            user=request.user,
            book=book,
            bank=bank if method in MANUAL_METHODS else None,
            currency=book.currency,
            amount=amounts["sale_amount"],
            commission_amount=amounts["commission_amount"],
            payment_method=method,
            status=TransactionStatus.PENDING,
        )
        record_audit(
            actor=request.user,
            action="transaction.create",
            target_type="PaymentTransaction",
            target_id=txn.id,
            metadata={"method": method, "amount": str(txn.amount)},
            request=request,
        )

        payload = {"transaction": PaymentTransactionSerializer(txn, context={"request": request}).data}

        if method in ONLINE_METHODS:
            try:
                gateway = get_gateway(method)
                result = gateway.create_checkout(
                    txn,
                    success_url=request.data.get("success_url", ""),
                    cancel_url=request.data.get("cancel_url", ""),
                )
            except GatewayNotConfigured as exc:
                return Response(
                    {"error": {"code": "GATEWAY_UNAVAILABLE", "message": str(exc)},
                     "transaction": payload["transaction"]},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            except GatewayError as exc:
                return Response(
                    {"error": {"code": "GATEWAY_ERROR", "message": str(exc)}},
                    status=status.HTTP_502_BAD_GATEWAY,
                )
            if result.gateway_reference:
                txn.gateway_reference = result.gateway_reference
                txn.save(update_fields=["gateway_reference", "updated_at"])
            payload["checkout"] = {
                "gateway_reference": result.gateway_reference,
                "checkout_url": result.checkout_url,
                "client_secret": result.client_secret,
                **result.extra,
            }
        else:
            # Manual flow: hand back what the buyer needs to transfer & upload.
            payload["banks"] = PublicBankSerializer(
                Bank.objects.filter(is_active=True), many=True
            ).data
            payload["transaction"] = PaymentTransactionSerializer(txn, context={"request": request}).data

        return Response(payload, status=status.HTTP_201_CREATED)


class PaymentTransactionDetailView(_PaymentsView):
    @extend_schema(responses=PaymentTransactionSerializer)
    def get(self, request, transaction_id):
        txn = get_object_or_404(
            PaymentTransaction, pk=transaction_id, user=request.user
        )
        return Response(PaymentTransactionSerializer(txn, context={"request": request}).data)


class ReceiptFileView(APIView):
    """Streams a transaction's uploaded receipt to the buyer who owns it or to a
    platform admin. Receipts are private financial documents, so (unlike book
    covers) this endpoint requires authentication. Supports JWT (mobile/web/
    desktop apps) and session auth (the Django admin "View receipt" link)."""

    authentication_classes = [JWTAuthentication, SessionAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, transaction_id):
        txn = get_object_or_404(PaymentTransaction, pk=transaction_id)
        user = request.user
        is_admin = bool(
            user.is_superuser
            or user.is_staff
            or getattr(user, "role", "") == "admin"
        )
        if not (is_admin or txn.user_id == user.id):
            return Response(
                {"error": {"code": "FORBIDDEN", "message": "Not allowed."}},
                status=status.HTTP_403_FORBIDDEN,
            )
        if not txn.receipt_object_key:
            raise Http404("No receipt")
        data = read_receipt(txn.receipt_object_key)
        if not data:
            raise Http404("Receipt unavailable")
        resp = HttpResponse(
            data, content_type=receipt_content_type(txn.receipt_object_key)
        )
        resp["Cache-Control"] = "private, max-age=300"
        return resp


class SubmitReceiptView(_PaymentsView):
    """Upload a receipt + reference for a manual bank-transfer transaction."""

    @extend_schema(
        request=SubmitReceiptSerializer, responses=PaymentTransactionSerializer
    )
    def post(self, request, transaction_id):
        txn = get_object_or_404(
            PaymentTransaction, pk=transaction_id, user=request.user
        )
        if txn.payment_method not in MANUAL_METHODS:
            return Response(
                {"error": {"code": "NOT_MANUAL", "message": "Not a manual payment."}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if txn.status in TERMINAL_STATUSES:
            return Response(
                {"error": {"code": "LOCKED", "message": "Transaction can no longer be edited."}},
                status=status.HTTP_409_CONFLICT,
            )

        ser = SubmitReceiptSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        reference = ser.validated_data["transaction_reference"].strip()
        bank = ser.validated_data.get("bank") or txn.bank

        # Duplicate-transaction prevention (application-level + DB constraint).
        dup = (
            PaymentTransaction.objects.filter(
                payment_method=txn.payment_method, transaction_reference=reference
            )
            .exclude(pk=txn.pk)
            .exists()
        )
        if dup:
            return Response(
                {"error": {"code": "DUPLICATE_REFERENCE",
                           "message": "This transaction reference was already used."}},
                status=status.HTTP_409_CONFLICT,
            )

        object_key = store_receipt(txn.id, ser.validated_data["receipt"])

        txn.transaction_reference = reference
        txn.bank = bank
        txn.receipt_object_key = object_key
        txn.status = TransactionStatus.ON_REVIEW
        try:
            txn.save(
                update_fields=[
                    "transaction_reference",
                    "bank",
                    "receipt_object_key",
                    "status",
                    "updated_at",
                ]
            )
        except IntegrityError:
            return Response(
                {"error": {"code": "DUPLICATE_REFERENCE",
                           "message": "This transaction reference was already used."}},
                status=status.HTTP_409_CONFLICT,
            )

        record_audit(
            actor=request.user,
            action="transaction.submit_receipt",
            target_type="PaymentTransaction",
            target_id=txn.id,
            metadata={"reference": reference},
            request=request,
        )
        return Response(PaymentTransactionSerializer(txn, context={"request": request}).data)


# --- Author dashboard & profile -----------------------------------------


class AuthorDashboardView(APIView):
    permission_classes = [IsAuthor]

    def get(self, request):
        disabled = _feature_disabled_response()
        if disabled is not None:
            return disabled
        rows = RevenueLedger.objects.filter(author=request.user)
        agg = rows.aggregate(
            total_sales=Count("id"),
            gross_revenue=Sum("sale_amount"),
            platform_commission=Sum("commission_amount"),
            net_revenue=Sum("author_amount"),
        )
        return Response(
            {
                "total_sales": agg["total_sales"] or 0,
                "gross_revenue": str(agg["gross_revenue"] or 0),
                "platform_commission": str(agg["platform_commission"] or 0),
                "net_revenue": str(agg["net_revenue"] or 0),
            }
        )


class AuthorProfileView(APIView):
    permission_classes = [IsAuthor]

    @extend_schema(responses=AuthorProfileSerializer)
    def get(self, request):
        disabled = _feature_disabled_response()
        if disabled is not None:
            return disabled
        profile, _ = AuthorProfile.objects.get_or_create(user=request.user)
        return Response(AuthorProfileSerializer(profile).data)

    @extend_schema(request=AuthorProfileSerializer, responses=AuthorProfileSerializer)
    def patch(self, request):
        disabled = _feature_disabled_response()
        if disabled is not None:
            return disabled
        profile, _ = AuthorProfile.objects.get_or_create(user=request.user)
        ser = AuthorProfileSerializer(profile, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(AuthorProfileSerializer(profile).data)


# --- Author application (reader -> author request) ----------------------


def _is_already_author(user) -> bool:
    return bool(user.is_superuser or getattr(user, "role", "") in {"author", "admin"})


class AuthorApplicationView(APIView):
    """A reader's own author application: read status, submit, or edit.

    Not gated by ``FEATURE_PAYMENTS`` — becoming an author is independent of the
    payment flow.
    """

    permission_classes = [IsAuthenticated]

    @extend_schema(responses=AuthorApplicationSerializer)
    def get(self, request):
        application = AuthorApplication.objects.filter(user=request.user).first()
        data = (
            AuthorApplicationSerializer(application, context={"request": request}).data
            if application is not None
            else None
        )
        return Response(
            {"application": data, "is_author": _is_already_author(request.user)}
        )

    @extend_schema(
        request=AuthorApplicationSerializer, responses=AuthorApplicationSerializer
    )
    def post(self, request):
        return self._upsert(request, partial=False)

    @extend_schema(
        request=AuthorApplicationSerializer, responses=AuthorApplicationSerializer
    )
    def patch(self, request):
        return self._upsert(request, partial=True)

    def _upsert(self, request, *, partial: bool):
        if _is_already_author(request.user):
            return Response(
                {"error": {"code": "ALREADY_AUTHOR", "message": "You are already an author."}},
                status=status.HTTP_409_CONFLICT,
            )
        existing = AuthorApplication.objects.filter(user=request.user).first()
        if existing is not None and existing.status == AuthorApplicationStatus.APPROVED:
            return Response(
                {"error": {"code": "LOCKED", "message": "This application was already approved."}},
                status=status.HTTP_409_CONFLICT,
            )
        ser = AuthorApplicationSerializer(
            existing, data=request.data, partial=partial, context={"request": request}
        )
        ser.is_valid(raise_exception=True)
        application = submit_author_application(request.user, ser.validated_data)
        record_audit(
            actor=request.user,
            action="author_application.submit",
            target_type="AuthorApplication",
            target_id=application.id,
            metadata={"status": application.status},
            request=request,
        )
        return Response(
            AuthorApplicationSerializer(application, context={"request": request}).data,
            status=status.HTTP_201_CREATED if existing is None else status.HTTP_200_OK,
        )


class AuthorApplicationPhotoPresignView(APIView):
    """Presigned PUT URL for the applicant's own photo (mirrors book covers)."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        if _is_already_author(request.user):
            return Response(
                {"error": {"code": "ALREADY_AUTHOR", "message": "You are already an author."}},
                status=status.HTTP_409_CONFLICT,
            )
        if not is_object_storage_configured():
            return Response(
                {"error": {"code": "STORAGE_UNAVAILABLE", "message": "Uploads are unavailable."}},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        content_type = (request.data.get("content_type") or "image/jpeg").strip().lower()
        if content_type not in _ALLOWED_PHOTO_TYPES:
            return Response(
                {"error": {"code": "INVALID_CONTENT_TYPE", "message": "Use image/jpeg, image/png, or image/webp."}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        ext = _ALLOWED_PHOTO_TYPES[content_type]
        object_key = f"author-applications/{request.user.id}/photo/{uuid.uuid4()}.{ext}"
        try:
            put_url = presign_put(
                object_key,
                content_type=content_type,
                presign_endpoint_url=dev_presign_endpoint_from_request(request),
            )
        except Exception as exc:
            logger.exception("author photo presign failed: %s", exc)
            return Response(
                {"error": {"code": "PRESIGN_FAILED", "message": "Could not create upload URL."}},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response({"object_key": object_key, "put_url": put_url})


# --- Webhooks (gateway -> us). CSRF-exempt, no auth; verified by signature. --


@method_decorator(csrf_exempt, name="dispatch")
class _WebhookView(APIView):
    permission_classes = []
    authentication_classes = []
    method = ""

    def post(self, request):
        disabled = _feature_disabled_response()
        if disabled is not None:
            return disabled
        try:
            gateway = get_gateway(self.method)
            result = gateway.verify_webhook(
                payload=request.body, headers=dict(request.headers)
            )
        except GatewayNotConfigured as exc:
            return Response(
                {"error": {"code": "GATEWAY_UNAVAILABLE", "message": str(exc)}},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except GatewayError as exc:
            return Response(
                {"error": {"code": "WEBHOOK_INVALID", "message": str(exc)}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response({"received": True, "paid": result.paid})


class StripeWebhookView(_WebhookView):
    method = PaymentMethod.STRIPE


class PayPalWebhookView(_WebhookView):
    method = PaymentMethod.PAYPAL


class TelebirrWebhookView(_WebhookView):
    method = PaymentMethod.TELEBIRR
