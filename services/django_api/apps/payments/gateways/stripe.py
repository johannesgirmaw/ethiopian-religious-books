"""Stripe gateway.

Inactive until Stripe credentials are configured. The method bodies below
document exactly where the Stripe SDK calls go (Checkout Session, PaymentIntent
verification, webhook signature check, refund) so activation is a focused change.
"""

from __future__ import annotations

from apps.payments.enums import PaymentMethod
from apps.payments.gateways.base import (
    CheckoutResult,  # noqa: F401  (referenced in the activation notes below)
    UnconfiguredGateway,
    VerificationResult,  # noqa: F401
)


class StripeGateway(UnconfiguredGateway):
    provider = PaymentMethod.STRIPE

    # To activate:
    #   1. add ``stripe`` to requirements.txt
    #   2. create_checkout  -> stripe.checkout.Session.create(...), return its url/id
    #   3. verify_payment   -> stripe.PaymentIntent.retrieve(...), paid = status=="succeeded"
    #   4. verify_webhook   -> stripe.Webhook.construct_event(payload, sig, webhook_secret)
    #   5. refund           -> stripe.Refund.create(payment_intent=...)
