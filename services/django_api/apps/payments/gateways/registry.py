"""Resolve a :class:`PaymentGateway` for a payment method."""

from __future__ import annotations

from apps.payments.enums import ONLINE_METHODS, PaymentMethod
from apps.payments.gateways.base import GatewayError, PaymentGateway
from apps.payments.gateways.paypal import PayPalGateway
from apps.payments.gateways.stripe import StripeGateway
from apps.payments.gateways.telebirr import TelebirrGateway
from apps.payments.models import GatewayCredential

_REGISTRY: dict[str, type[PaymentGateway]] = {
    PaymentMethod.STRIPE: StripeGateway,
    PaymentMethod.PAYPAL: PayPalGateway,
    PaymentMethod.TELEBIRR: TelebirrGateway,
}


def get_gateway(method: str) -> PaymentGateway:
    """Return the gateway strategy for an online ``method``.

    Raises :class:`GatewayError` for methods that are not online gateways
    (e.g. the manual bank-transfer flow).
    """
    if method not in ONLINE_METHODS:
        raise GatewayError(f"{method} is not an online gateway.")
    cls = _REGISTRY[method]
    credential = GatewayCredential.objects.filter(provider=method).first()
    return cls(credential)
