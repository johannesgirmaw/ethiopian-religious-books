# Payments & commissions

Backend for the book marketplace: pricing, commission resolution, the manual
bank-transfer purchase flow, an admin review/management surface, a revenue
ledger, and a pluggable interface for online gateways (Stripe / PayPal /
Telebirr).

> Status: the **manual bank-transfer flow is fully implemented and tested**.
> Online gateways are wired through a clean strategy interface but stay
> **inactive** until provider credentials are configured — every online
> operation returns a clean `503 GATEWAY_UNAVAILABLE` in the meantime.

## Data model

| Model | Purpose |
| --- | --- |
| `Book` (catalog, extended) | `author`, `currency`, `price`, `sale_price`, `commission_percent` |
| `PlatformSettings` | singleton: gateway toggles, default commission, override flags |
| `GatewayCredential` | per-provider **encrypted** secret/webhook keys |
| `AuthorCommission` | per-author commission override |
| `AuthorProfile` | author publishing identity + payout info |
| `Bank` | admin-managed banks for manual transfers (no hardcoding) |
| `PaymentTransaction` | one purchase attempt + its lifecycle |
| `RevenueLedger` | **source of truth** for reporting (one row per COMPLETED txn) |
| `AuditLog` | immutable trail of sensitive actions |

### Commission resolution (`services.resolve_commission_percent`)
1. `Book.commission_percent` — if `allow_book_override`
2. `AuthorCommission.commission_percent` for `book.author` — if `allow_author_override`
3. `PlatformSettings.default_commission_percent`

### Amounts (`services.compute_amounts`)
`sale = sale_price or price`; `commission = sale * percent / 100`;
`author = sale - commission` (rounded to cents).

### Transaction lifecycle
`PENDING → ON_REVIEW → COMPLETED` (approve) / `REJECTED` (reject); also
`APPROVED`, `CANCELLED`. Reaching **COMPLETED** is the *only* path that writes a
`RevenueLedger` row (`services.create_revenue_ledger`, idempotent).

## Manual bank-transfer flow
1. `POST /v1/payments/transactions` `{book, payment_method:"bank_transfer", bank}` → PENDING txn + bank details
2. user transfers money, then
   `POST /v1/payments/transactions/{id}/receipt` (multipart: `receipt`, `transaction_reference`) → ON_REVIEW
3. admin `POST /v1/admin/payments/transactions/{id}/approve` → COMPLETED + ledger entry

Receipts: JPG/PNG/PDF, ≤10MB, validated by extension **and** magic bytes;
duplicate `(method, reference)` pairs are blocked at the app layer and by a DB
unique constraint.

## API surface (all under `/v1/`)
- Buyer: `payments/methods`, `payments/banks`, `payments/transactions[/{id}[/receipt]]`
- Author: `author/dashboard`, `author/profile`
- Webhooks: `payments/webhooks/{stripe,paypal,telebirr}` (signature-verified, CSRF-exempt)
- Admin: `admin/payments/{dashboard,transactions[/{id}[/approve|reject]],banks[/{id}],settings,credentials[/{provider}],author-commissions[/{id}]}`

Documented via drf-spectacular (`/api/docs/`). Admin endpoints require the
`admin` role or superuser (`permissions.IsPlatformAdmin`); author endpoints
require the `author` role (`permissions.IsAuthor`).

## Security
- Role-based permissions on every endpoint; buyers only see their own txns.
- Gateway secrets stored Fernet-encrypted (`crypto.py`); never returned by the API or shown in the admin.
- Webhook handlers validate provider signatures before acting.
- Duplicate-transaction detection (app + DB constraint).
- File-type/size/magic-byte validation on receipts.
- `AuditLog` records create/approve/reject/settings/credential/bank changes.

## Activating an online gateway later
1. Add the provider SDK to `requirements.txt`.
2. Fill in the method bodies in `gateways/<provider>.py` (the steps are listed in each file).
3. Enable the method in `PlatformSettings` and store credentials via
   `PUT /v1/admin/payments/credentials/{provider}` (`is_active: true`).

No changes to views, serializers, URLs, or the transaction state machine are
required — the registry (`gateways/registry.py`) resolves the strategy.

## Settings
`FEATURE_PAYMENTS` (default on), `PAYMENTS_FERNET_KEY` (set a stable Fernet key
in production), `MEDIA_ROOT`/`MEDIA_URL` (receipt storage via `default_storage`).

## Tests
`python manage.py test apps.payments` — covers commission resolution, pricing,
ledger idempotency, encryption, the full manual flow (incl. duplicate/file
validation), gateway-inactive behaviour, admin review/CRUD, and author earnings.
