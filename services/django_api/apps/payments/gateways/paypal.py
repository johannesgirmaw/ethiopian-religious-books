"""PayPal gateway. Inactive until PayPal credentials are configured."""

from __future__ import annotations

from apps.payments.enums import PaymentMethod
from apps.payments.gateways.base import UnconfiguredGateway


class PayPalGateway(UnconfiguredGateway):
    provider = PaymentMethod.PAYPAL

    # To activate:
    #   1. add ``paypalserversdk`` (or REST calls) to requirements.txt
    #   2. create_checkout  -> Orders create, return approval link + order id
    #   3. verify_payment   -> Orders capture / get, paid = status=="COMPLETED"
    #   4. verify_webhook   -> verify webhook signature via PayPal verify endpoint
    #   5. refund           -> Payments refund on the capture id
