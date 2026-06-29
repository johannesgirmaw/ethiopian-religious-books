# Encrypted Offline Reading

How the reader app lets users download **purchased or free** books and read them
offline, while keeping the stored content **encrypted at rest** and **revocable**.

- **Backend:** `services/django_api/`
- **App (mobile + desktop + web):** `apps/reader_flutter/`

---

## 1. Goals & threat model

### What this delivers
- Books download to the **device disk** (never a shared/cloud location) and are
  stored **AES-256-GCM encrypted**.
- The decryption key lives in the device's **hardware-backed secure store**
  (iOS Keychain / Android Keystore / macOS Keychain / Linux libsecret / Windows
  DPAPI) and is **never written into any file**.
- Offline access is governed by a **server-signed license (lease)** that expires
  and must be renewed online — so a **refunded/revoked** purchase loses offline
  access.

### What is guaranteed
Files copied off the device — backups, file managers, another app's sandbox, a
lost/stolen device — are **useless ciphertext**. This is the achievable, real
"no one can steal my data" guarantee.

### Honest limitation
No client-side scheme can stop a determined attacker on a **rooted/jailbroken
device they fully control** from dumping plaintext from memory at the moment a
page is rendered (the page must be decrypted to be displayed). We raise the cost
enormously but cannot make it mathematically impossible — the same limit Kindle,
Google Play Books and Readium LCP live with. **"Uncrackable at rest" — yes.
"Unextractable by the legitimate user on a hacked device" — no.**

---

## 2. Architecture at a glance

```
                       ┌──────────────────────────── Django API ───────────────────────────┐
                       │                                                                     │
  Download request ───▶│  BookLicenseView / BookDownloadView                                 │
  (device_id)          │   ├─ user_owns_book(user, book)?  ── free OR COMPLETED purchase     │
                       │   │      └─ no → 403 NOT_ENTITLED                                    │
                       │   └─ issue_license(...) ── HS256 JWT {user,book,rev,device,exp+30d}  │
                       │                                                                     │
                       │  DeviceRegisterView  ── stores UserDevice(user, device_id, pubkey)  │
                       └─────────────────────────────────────────────────────────────────────┘
                                                  │  license token + book content (over TLS)
                                                  ▼
   ┌──────────────────────────────── Flutter app (device) ───────────────────────────────┐
   │                                                                                       │
   │  runOfflineBookDownload                                                               │
   │    1. DeviceIdentity.ensureRegistered + deviceId()                                    │
   │    2. POST /books/{id}/license  → license token (entitlement-checked server-side)     │
   │    3. fetch /books/{id}/content → BookContentTree                                     │
   │    4. SecureBookStore seals content + meta + license with AES-256-GCM                 │
   │                                                                                       │
   │  BookCrypto                 SecureKeyValue                vault/ (conditional I/O)     │
   │   AES-256-GCM seal/open  ──▶ device master key  ◀──┐      vault_fs_io.dart  (files)    │
   │   (key never on disk)       in Keychain/Keystore   │      vault_fs_stub.dart (web)     │
   │                                                    │                                   │
   │  Disk: {appDocuments}/library/{bookId}/ content.enc · meta.enc · license.enc          │
   └───────────────────────────────────────────────────────────────────────────────────────┘
```

This is **envelope-style DRM** (à la Readium LCP): the bulk content is sealed
with a device-bound key, and a small signed lease controls how long it stays
readable offline.

---

## 3. Backend

### 3.1 Entitlement gate — `apps/payments/services.py`

```python
def user_owns_book(user, book) -> bool:
    # True if the book is free (final_price <= 0) or the user has a COMPLETED purchase.
```

Single source of truth shared by the download endpoint, the license endpoint and
the reader buy-gate, so they never disagree. Mirrors the query in
`EntitlementsView`.

### 3.2 Offline license — `apps/catalog/licensing.py`

A license is a **HMAC-SHA256 (HS256) signed JWT** lease:

| Claim | Meaning |
|-------|---------|
| `typ` | `offline-license` |
| `sub` | user id |
| `book` / `rev` | book + published revision id |
| `device` | the device id the lease is bound to |
| `iat` / `nbf` / `exp` | issued / not-before / expiry (`now + lease_days`) |
| `jti` | unique token id |

- `issue_license(...)` → `{token, expires_at, lease_days}`
- `verify_license(token)` → claims, or `None` if invalid/expired/wrong type
- Signing key: `OFFLINE_LICENSE_SIGNING_KEY` (falls back to a key derived from
  `SECRET_KEY` for dev). **Independent of the user-JWT signing key.**

### 3.3 Endpoints — `apps/catalog/views.py`, `apps/accounts/views.py`, `apps/api_urls.py`

| Method & path | View | Purpose |
|---------------|------|---------|
| `POST /v1/devices/register` | `DeviceRegisterView` | Register/rotate a device's public key; idempotent on `(user, device_id)` |
| `POST /v1/books/{id}/license` | `BookLicenseView` | **Issue or renew** an offline lease. Re-checks entitlement every call (the revocation lever). Decoupled from S3. |
| `GET /v1/books/{id}/download` | `BookDownloadView` | Now **entitlement-gated** (403 if not owned); also embeds a license in its payload |

Request/response shapes:

```jsonc
// POST /v1/devices/register
{ "device_id": "….", "public_key": "…", "platform": "macos", "label": "…" }
→ { "device_id": "….", "registered": true }

// POST /v1/books/{id}/license
{ "device_id": "…." }
→ { "book_id": "…", "revision_id": "…",
    "license": { "token": "<jwt>", "expires_at": "2026-07-…T…Z", "lease_days": 30 } }
// → 403 { "error": { "code": "NOT_ENTITLED", … } } when the user doesn't own it
```

### 3.4 Device registry — `apps/accounts/models.py` (+ migration `0005_userdevice.py`)

`UserDevice(user, device_id, public_key, platform, label, created_at, last_seen)`
with a unique `(user, device_id)`. The **public key** is stored for future
server-side per-device key-wrapping; the private half never leaves the device.

### 3.5 Settings — `config/settings/base.py`

```python
OFFLINE_LICENSE_SIGNING_KEY = env("OFFLINE_LICENSE_SIGNING_KEY", default="")  # set in prod
OFFLINE_LICENSE_LEASE_DAYS  = env.int("OFFLINE_LICENSE_LEASE_DAYS", default=30)
```

---

## 4. Flutter app

### 4.1 Secrets — `lib/security/secure_key_value.dart`

Thin secure key/value store for the **device master key** and **device id**.
Mirrors `TokenStorage`: on **macOS debug** it falls back to SharedPreferences to
avoid the login-keychain password prompt / `-34018` that otherwise hangs the app;
release macOS and all other platforms use the hardware keychain/keystore.
Override in debug with `--dart-define=USE_MACOS_KEYCHAIN=true`.

### 4.2 Crypto core — `lib/security/book_crypto.dart`

- A single **256-bit AES-GCM master key** (KEK), generated on first use and kept
  via `SecureKeyValue`. **Never written into a vault file.**
- Blob format: `nonce(12) ‖ ciphertext ‖ mac(16)`. The 128-bit GCM tag
  authenticates every blob — tampering makes `open()` throw, not return forgeries.
- API: `seal` / `open`, `sealJson` / `openJson`, `wipeMasterKey()`.
- Native acceleration via the `cryptography_flutter` plugin (auto-registered).

### 4.3 Device identity — `lib/security/device_identity.dart`

- Stable, **private** per-install id (random 128-bit, stored via `SecureKeyValue`)
  — not derived from hardware serials, so it leaks nothing about the user.
- `ensureRegistered(dio)` — best-effort `POST /devices/register` (no-ops offline,
  retries next time).
- `platformLabel()` — `android` / `ios` / `macos` / `windows` / `linux` / `web`.

### 4.4 Encrypted vault — `lib/storage/secure_book_store.dart` + `lib/storage/vault/`

On-disk layout (native): `{appDocuments}/library/{bookId}/`

| File | Sealed contents |
|------|-----------------|
| `content.enc` | the `BookContentTree` JSON |
| `meta.enc` | title/author/language (so the **library list itself** doesn't leak) |
| `license.enc` | the `OfflineLicense` (token + expiry + device id) |

- `vault/vault_fs_io.dart` — native byte I/O (`dart:io` + `path_provider`,
  write-then-rename for crash safety).
- `vault/vault_fs_stub.dart` — web fallback (base64 in SharedPreferences).
- Selected by conditional import:
  `import 'vault/vault_fs_stub.dart' if (dart.library.io) 'vault/vault_fs_io.dart';`
  so web keeps building.

`OfflineLicense` exposes `isExpired` and `needsRenewal({days})`;
`SecureBookStore.hasValidOfflineAccess(bookId, deviceId)` is the offline gate:
a sealed, unexpired, **this-device** license must be present.

### 4.5 Cache façade + legacy wipe — `lib/storage/book_content_cache_storage.dart`

Same public API as before, but now **delegates to `SecureBookStore`** (everything
encrypted at rest). On first use it performs a **one-time wipe** of the old
plaintext `book_content_cache_*` SharedPreferences keys (guarded by
`vault_legacy_wiped_v1`).

### 4.6 Download pipeline — `lib/utils/offline_book_download.dart`

`runOfflineBookDownload(ref, bookId)`:
1. Register device + get `deviceId`.
2. `POST /books/{id}/license` (entitlement-checked) → license token.
3. Fetch content via `bookContentProvider` — which **seals it into the vault** as
   a side effect (no plaintext on disk).
4. Persist the license with `SecureBookStore.writeLicense`.

Failures surface clear messages: **403 → "purchase this book first"**,
404 → "not available for download yet", empty content → "no readable content yet".
**No S3** is involved.

### 4.7 Decrypt-on-read + renewal — `lib/providers/catalog_providers.dart`

`bookContentProvider`:
- **Online:** fetch `/content`, seal to vault, and **silently renew** the lease if
  it's near expiry (`_maybeRenewOfflineLicense`). A **403 on renewal** (purchase
  revoked) drops the local license, ending offline access at the current lease's end.
- **Offline:** serve the encrypted cache **only** if a valid this-device license
  exists; otherwise it refuses (you must Download to read offline).

The reader UI (`reader_screen.dart`, `stored_rich_text_view.dart`) is unchanged —
it still consumes a `BookContentTree`.

### 4.8 Logout wipe — `lib/providers/session_notifier.dart`

`clear()` wipes the vault (`SecureBookStore.clearAll()`) and the master key
(`BookCrypto.wipeMasterKey()`) so a different user on the same device cannot read
the previous user's downloads.

### 4.9 Dependencies — `apps/reader_flutter/pubspec.yaml`

```yaml
cryptography: ^2.7.0          # AES-256-GCM
cryptography_flutter: ^2.3.2  # platform-native acceleration
# (flutter_secure_storage, shared_preferences, path_provider already present)
```

---

## 5. Key lifecycle & flows

**Download (online):** register device → license (entitlement-gated) → fetch
content → seal `content.enc` + `meta.enc` + `license.enc` under the device master
key.

**Read offline:** read `license.enc` → valid + unexpired + this-device? → unseal
`content.enc` with the master key → render. No valid license → blocked.

**Renewal (online):** when a lease is within ~5 days of expiry, the app silently
re-requests a license; entitlement is re-checked server-side.

**Revocation:** mark the purchase non-`COMPLETED` (refund/chargeback). The next
online renewal returns **403**; the app drops the local license and offline
access ends when the current lease expires.

**Logout:** vault + master key wiped → all downloads become unreadable.

---

## 6. Configuration

| Setting | Where | Default | Notes |
|---------|-------|---------|-------|
| `OFFLINE_LICENSE_SIGNING_KEY` | API env | derived from `SECRET_KEY` | **Set a stable secret in production** |
| `OFFLINE_LICENSE_LEASE_DAYS` | API env | `30` | Offline lease length; lower it to test expiry |
| `FEATURE_BOOK_CONTENT_INDEX` | API env | `true` | `/content` returns book text from the DB |
| `USE_MACOS_KEYCHAIN` | Flutter `--dart-define` | `false` | Force the real keychain in macOS debug |

---

## 7. Platform notes

| Target | Key store | Vault store |
|--------|-----------|-------------|
| Android | Keystore (TEE/StrongBox-backed) | files |
| iOS | Keychain / Secure Enclave-protected | files |
| macOS | Keychain (release) · SharedPreferences (debug) | files |
| Windows | DPAPI | files |
| Linux | libsecret | files |
| Web | localStorage-backed secure storage (weaker) | SharedPreferences |

Encrypted offline reading is primarily targeted at **mobile + desktop**; web keeps
building and functioning but its at-rest protection is weaker (no hardware
keystore). Linux/Windows lack a mobile-class TEE but still bind the key to the
user/device.

---

## 8. Testing

### Backend — `services/django_api/apps/catalog/tests_offline.py`
Run in the Docker/CI environment (needs the full Python deps):

```bash
docker compose -f infra/docker-compose.yml exec api \
  python manage.py test apps.catalog.tests_offline
```

Covers: free book issues a license; paid book blocked without purchase (403);
allowed after purchase; **renewal denied after revoke**; download gated by
entitlement; device register idempotent + key rotation; license JWT round-trip.

### Flutter — `apps/reader_flutter/test/security/offline_encryption_test.dart`

```bash
cd apps/reader_flutter && flutter test test/security/offline_encryption_test.dart
```

Covers: AES-256-GCM round-trip; ciphertext isn't plaintext; **tamper detection**
(GCM tag); **wrong device key cannot open**; lease-window logic
(`isExpired` / `needsRenewal`).

### Prove encryption at rest (manual)
After downloading a book, inspect the vault:
```bash
# macOS example
strings ~/Library/Containers/*/Data/Documents/library/*/content.enc | grep -i "<a phrase from the book>"   # → no match
xxd     ~/Library/Containers/*/Data/Documents/library/*/content.enc | head                                  # → random bytes
```
A full black-box QA plan (device-binding, revocation, lease expiry, logout wipe)
is in the project QA gates.

---

## 9. Limitations & future work

- **Content in object storage is currently plaintext HTML** (the publishing
  pipeline writes `content.html`; the server-side `.enc`/CEK fields are
  scaffolding). Protection today is **client-side encryption-at-rest + lease**,
  which meets the stated goal. The device public key is already captured, so the
  natural next step is to **encrypt content in S3 and wrap the per-book content
  key (CEK) to each device's public key** (ECIES/RSA-OAEP) — no rework of this
  layer required.
- **Hardware-non-exportable keys:** the master key is hardware-*protected* at
  rest but is read into Dart memory to encrypt/decrypt. A future hardening is to
  perform wrap/unwrap inside the Secure Enclave / StrongBox via a platform
  channel so the key never enters app memory.
- **Anti-extraction layers** (optional, cost-raising, documented as non-absolute):
  Android `FLAG_SECURE` + iOS capture detection on reader screens, root/jailbreak
  detection gating decryption, TLS certificate pinning, and obfuscated release
  builds (`flutter build --obfuscate --split-debug-info`).

---

## 10. Admin visibility (who downloaded what)

The encrypted books live on devices, so the server keeps a small **ledger** so
admins can see offline activity. `OfflineDownload` (`offline_downloads` table) is
**upserted on every license issue/renew** — one row per `(user, book, device)` —
recording the device, platform, first-download time, current lease expiry and a
`renew_count`.

Django admin (`/admin/`, django-unfold theme):

| Page | Shows |
|------|-------|
| **Catalog → Offline downloads** | Every download: user · book · platform · device · first downloaded · lease expiry · **License active** (✓/✗) · renewals. Filter by platform/date/expiry; search by user email, book title, device id. Read-only. |
| **Accounts → User devices** | Each registered device: user · device · platform · **Offline books** count · last seen. |
| **Accounts → Users** | Adds **Offline books** and **Devices** count columns per user (annotated, sortable). |

Populated by `_record_offline_download(...)` in `apps/catalog/views.py`, called
from both `BookLicenseView` and `BookDownloadView`. Bookkeeping is best-effort and
never blocks a download.

> Requires running migrations (`accounts 0005`, `catalog 0012`). The ledger only
> reflects downloads made **after** this is deployed.

---

## 11. File reference

**Backend**
- `apps/payments/services.py` — `user_owns_book`
- `apps/catalog/licensing.py` — license issue/verify
- `apps/catalog/views.py` — `BookDownloadView` (gated), `BookLicenseView`, `_record_offline_download`
- `apps/catalog/models.py` — `OfflineDownload` ledger (+ `migrations/0012_offlinedownload.py`)
- `apps/catalog/admin.py` — `OfflineDownloadAdmin`
- `apps/accounts/models.py` — `UserDevice` (+ `migrations/0005_userdevice.py`)
- `apps/accounts/views.py` — `DeviceRegisterView`
- `apps/accounts/admin.py` — `UserDeviceAdmin` + per-user download/device counts
- `apps/api_urls.py` — routes
- `config/settings/base.py` — license settings
- `apps/catalog/tests_offline.py` — tests

**Flutter**
- `lib/security/secure_key_value.dart` — secure secret store (macOS-debug safe)
- `lib/security/book_crypto.dart` — AES-256-GCM seal/open + master key
- `lib/security/device_identity.dart` — device id + registration
- `lib/storage/secure_book_store.dart` — encrypted vault + `OfflineLicense`
- `lib/storage/vault/vault_fs_io.dart` · `vault_fs_stub.dart` — byte I/O
- `lib/storage/book_content_cache_storage.dart` — façade + legacy wipe
- `lib/utils/offline_book_download.dart` — download pipeline
- `lib/providers/catalog_providers.dart` — decrypt-on-read + renewal
- `lib/providers/session_notifier.dart` — logout wipe
- `test/security/offline_encryption_test.dart` — tests
