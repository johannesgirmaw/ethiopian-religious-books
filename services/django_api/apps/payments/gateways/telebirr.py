"""Telebirr gateway. Inactive until Telebirr credentials are configured."""

from __future__ import annotations

from apps.payments.enums import PaymentMethod
from apps.payments.gateways.base import UnconfiguredGateway


class TelebirrGateway(UnconfiguredGateway):
    provider = PaymentMethod.TELEBIRR

    # To activate:
    #   1. create_checkout  -> Telebirr "prepare order" / payment-request, return toPayUrl
    #   2. verify_payment   -> query order status, paid = tradeStatus indicates success
    #   3. verify_webhook   -> validate the callback/notify signature, then mark paid
    #   4. refund           -> Telebirr refund API on the trade no
