"""Payment-gateway abstraction.

Each online provider (Stripe, PayPal, Telebirr) implements :class:`PaymentGateway`.
Real network/SDK calls are intentionally not wired yet — they require provider
credentials and sandbox accounts. Until a gateway's credentials are configured
(``GatewayCredential.is_configured``) every operation raises
:class:`GatewayNotConfigured`, which the API turns into a clean ``503``.

The contract is fully specified here so that activating a provider later is a
drop-in change (fill in the method bodies, add the SDK to requirements) with no
churn in the views, serializers or transaction state machine.
"""

from __future__ import annotations

import abc
from dataclasses import dataclass, field

from apps.payments.models import GatewayCredential, PaymentTransaction


class GatewayError(Exception):
    """Base class for gateway failures."""


class GatewayNotConfigured(GatewayError):
    """Raised when a provider is selected but has no active credentials."""


@dataclass
class CheckoutResult:
    """What the client needs to continue an online payment."""

    gateway_reference: str
    checkout_url: str = ""
    client_secret: str = ""
    extra: dict = field(default_factory=dict)


@dataclass
class VerificationResult:
    paid: bool
    gateway_reference: str = ""
    amount: str = ""
    currency: str = ""
    raw: dict = field(default_factory=dict)


class PaymentGateway(abc.ABC):
    """Strategy interface for an online payment provider."""

    #: matches ``PaymentMethod`` / ``GatewayCredential.Provider`` value
    provider: str = ""

    def __init__(self, credential: GatewayCredential | None):
        self.credential = credential

    # -- configuration ----------------------------------------------------
    @property
    def is_configured(self) -> bool:
        return bool(self.credential and self.credential.is_configured)

    def ensure_configured(self) -> None:
        if not self.is_configured:
            raise GatewayNotConfigured(
                f"The {self.provider} gateway is not configured. "
                "Add active credentials in platform settings first."
            )

    # -- operations -------------------------------------------------------
    @abc.abstractmethod
    def create_checkout(
        self, txn: PaymentTransaction, *, success_url: str = "", cancel_url: str = ""
    ) -> CheckoutResult:
        """Start a payment and return what the client must do next."""

    @abc.abstractmethod
    def verify_payment(self, txn: PaymentTransaction) -> VerificationResult:
        """Poll/confirm the provider that the payment succeeded."""

    @abc.abstractmethod
    def verify_webhook(self, *, payload: bytes, headers: dict) -> VerificationResult:
        """Validate a webhook signature and return its outcome."""

    @abc.abstractmethod
    def refund(self, txn: PaymentTransaction, *, amount: str = "") -> dict:
        """Refund a (partial or full) completed payment."""


class UnconfiguredGateway(PaymentGateway):
    """Default implementation: every operation reports "not configured".

    Online providers subclass this so that, until their SDK code is filled in,
    they behave consistently (clean ``503`` rather than a ``NotImplementedError``).
    """

    def create_checkout(self, txn, *, success_url="", cancel_url=""):
        self.ensure_configured()
        raise GatewayNotConfigured(f"{self.provider} checkout is not available yet.")

    def verify_payment(self, txn):
        self.ensure_configured()
        raise GatewayNotConfigured(f"{self.provider} verification is not available yet.")

    def verify_webhook(self, *, payload, headers):
        self.ensure_configured()
        raise GatewayNotConfigured(f"{self.provider} webhooks are not available yet.")

    def refund(self, txn, *, amount=""):
        self.ensure_configured()
        raise GatewayNotConfigured(f"{self.provider} refunds are not available yet.")
