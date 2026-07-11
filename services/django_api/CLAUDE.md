# Django API — DRF backend for the reader platform

Django 5.1 + DRF REST API (JWT auth, drf-spectacular schema, Unfold admin, Celery/Redis, S3/MinIO presigned storage). ALL server-side business logic, models, and endpoints live here. NO UI, NO client code, and NO per-app URL routing — every route is in one flat file.

## Layout

| Path | What |
| --- | --- |
| [`config/settings/{base,dev,prod}.py`](config/settings/) | Split settings via `django-environ`; dev/prod `from ...base import *`. base = INSTALLED_APPS, REST_FRAMEWORK, SIMPLE_JWT, S3/Celery/UNFOLD, feature flags. `manage.py`→dev, `Dockerfile`→prod. |
| [`config/urls.py`](config/urls.py) | Root URLConf: `admin/`, `healthz/`, `api/schema/`, `api/docs/` (name=`swagger-ui`), `v1/`→`apps.api_urls`. `/` returns JSON service index. |
| [`apps/api_urls.py`](apps/api_urls.py) | THE single flat `path()` list of every v1 route. Imports views from all 5 apps. Paths are trailing-slash-LESS. Add new endpoints here. |
| [`apps/accounts/`](apps/accounts/) | Custom `User` (email login, UUID pk, role, `db_table='users'`), JWT views, `UserDevice`, `PasswordResetCode`. `tasks.py`=reset-email/reminders. |
| [`apps/catalog/`](apps/catalog/) | Books domain: `Book`/`BookRevision`/`BookChapter`/`BookPage`/`BookContentIndex`, `Genre`, `Tag`, `OfflineDownload`, Bible models (`BibleSection`/`BibleVerse`). Services: `storage_s3.py`, `docx_import.py`, `licensing.py`, `search_normalization.py`, `permissions.py`, `admin_views.py`, `bible_views.py`. |
| [`apps/study/`](apps/study/) | User activity: bookmarks, highlights, notes, folders, reading plans, reminders, progress, favourites, reviews, notifications. All user-scoped. |
| [`apps/payments/`](apps/payments/) | `PlatformSettings` (singleton), `GatewayCredential` (Fernet), `AuthorCommission`, `PaymentTransaction`, `RevenueLedger`, `AuditLog`. `services.py`, `crypto.py`, `gateways/` (Stripe/PayPal/Telebirr + `registry.py`). |
| [`apps/legal/`](apps/legal/) | `LegalDocument` + `LegalAcceptance`; list + acceptance endpoints. |
| [`config/celery.py`](config/celery.py) | Celery app `religious_books`, Redis broker, `namespace='CELERY'`, autodiscover; exposed as `config.celery_app`. |
| [`config/dashboard.py`](config/dashboard.py) [`middleware.py`](config/middleware.py) | Unfold `DASHBOARD_CALLBACK` (`dashboard_callback`); `CollapseDuplicatePathSlashesMiddleware`. |
| [`docker/entrypoint.sh`](docker/entrypoint.sh) + [`Dockerfile`](Dockerfile) | Prod: `migrate` → `ensure_minio_bucket` (best-effort) → `ensure_superuser` → exec gunicorn. python:3.12-slim, bakes collectstatic. |
| [`apps/*/management/commands/`](apps/catalog/management/commands/) | `seed_dev`, `seed_book_covers`, `import_bible`, `rebuild_content_index`, `ensure_minio_bucket`, `ensure_superuser` (accounts), etc. |

## Conventions

- Every model: `UUIDField(primary_key=True, default=uuid.uuid4)` + explicit `db_table` in `Meta`.
- DRF `DEFAULT_PERMISSION_CLASSES` is **AllowAny** — set `permission_classes` explicitly on EVERY view. Use `IsAuthenticated`, `IsPublisherOrAuthor`/`IsPublisherAdmin` (catalog), `IsPlatformAdmin`/`IsAuthor` (payments); `AllowAny` only for public/webhook/auth-entry.
- Role: `User.role ∈ {reader, author, admin}`. Platform admin = `is_superuser OR role=='admin'`. Helpers in [`apps/catalog/permissions.py`](apps/catalog/permissions.py) (`is_platform_admin`, `can_manage_book`) and [`apps/payments/permissions.py`](apps/payments/permissions.py). Book object ownership via `can_manage_book()`.
- Views are plain DRF `APIView` subclasses (no ViewSets/routers), wired manually in `apps/api_urls.py`.
- Auth = simplejwt with `token_blacklist`; email is `USERNAME_FIELD`. ACCESS 15min, REFRESH 14d, rotate + blacklist-after-rotation. Argon2 first in `PASSWORD_HASHERS`.
- Business logic lives in service modules (`payments/services.py`, `payments/crypto.py`, `catalog/licensing.py`, `storage_s3.py`, `docx_import.py`), NOT views — so admin/Celery reuse.
- Read config via `env(...)` in base.py with a dev-safe default; never hardcode secrets.
- Object storage: use [`apps/catalog/storage_s3.py`](apps/catalog/storage_s3.py) helpers (`presign_get`/`presign_put`/`put_bytes`/`head_object`). Models store object keys (`cover_object_key`, `content_object_key`); API returns short-lived presigned URLs.
- Encrypted secrets use Fernet via [`apps/payments/crypto.py`](apps/payments/crypto.py); models expose `set_secret()`/`secret()`, not raw fields.
- Feature flags in base.py (`FEATURE_BOOK_CONTENT_INDEX`, `FEATURE_CATALOG_TOLERANT_SEARCH`, `FEATURE_STUDY_TOOLS`, `FEATURE_DAILY_PLAN_REMINDERS`, `FEATURE_PAYMENTS`) gate behavior.
- `Book.save()` recomputes `search_text_normalized`; book pages are chunked to `PAGE_BYTE_BUDGET`=1600 bytes so the db-indexed `BookContentIndex.text_normalized` stays under Postgres' ~2704-byte btree limit — see [`apps/catalog/pagination.py`](apps/catalog/pagination.py).
- Unfold is listed FIRST in `INSTALLED_APPS`; sidebar nav is hand-maintained in the `UNFOLD` dict in base.py — add new admin models there.

## Commands

- `make infra-up` — up postgres/redis/minio/mailhog/api/celery_worker (standard local bring-up).
- `make run-dev` — `./scripts/run_dev.sh`, Docker API + Flutter reader.
- `make seed` — `seed_dev` in api container (idempotent admin/legal/sample book).
- `make seed-covers` — `seed_book_covers` in api container.
- `make print-api-url` — print Swagger/health URLs (respects `infra/.env`).
- `make openapi-export` — save `/api/schema/` to `packages/api_contract/openapi.json`.
- `docker compose -f infra/docker-compose.yml --env-file infra/.env exec api python manage.py <cmd>` — any mgmt command in-container.
- `celery -A config worker -l info` — run the Celery worker.

## Gotchas

- AllowAny default: forgetting `permission_classes` silently makes a view public.
- No per-app `urls.py` — a view not registered in `apps/api_urls.py` is unreachable; paths have NO trailing slash.
- `Genre` is a slug STRING on `Book.genre` (default `'other'`), validated against the `Genre` table on write — NOT a FK.
- Two S3 endpoints: `AWS_S3_ENDPOINT_URL` (internal put/head, e.g. `http://minio:9000`) vs `AWS_S3_PRESIGN_ENDPOINT_URL` (device-reachable). `is_object_storage_configured()` gates presign paths. Dev clients may send `X-Dev-S3-Origin` (DEBUG-only, loopback/private IPs).
- Bible books (`is_bible=True`) are excluded from `/books` and served via `/bible/*` as open DB rows — NOT via the encrypted `BookRevision` package.
- prod.py inserts WhiteNoise and sets `STORAGES` default to FileSystemStorage — uploaded media/receipts hit local disk unless overridden.
- `PlatformSettings` is a singleton — always `PlatformSettings.get_solo()`.
- `services/django_api/.venv/` is a stale Python 3.9 venv — real runtime is python:3.12-slim in Docker; `requirements.txt` is the source of truth.
- `PaymentTransaction` has a partial unique constraint on `(payment_method, transaction_reference)` excluding empty ref.
- `db.sqlite3` is only the manage.py fallback; real dev/prod uses Postgres via `DATABASE_URL`.
- `OFFLINE_LICENSE_SIGNING_KEY` and `PAYMENTS_FERNET_KEY` derive from `SECRET_KEY` when unset — rotating `SECRET_KEY` in prod without stable values invalidates live offline licenses and makes gateway secrets undecryptable.

## Never do

- Never create a per-app `urls.py` or a DRF router — route everything through the flat `apps/api_urls.py`.
- Never rely on the default AllowAny — set `permission_classes` explicitly.
- Never hardcode secrets/config — add env-backed settings via `env(...)` in base.py with a dev-safe default.
- Never hand-run `migrate`/`makemigrations` against prod — migrations run in the container entrypoint.
- Never store gateway secrets or license keys in plaintext fields — use `crypto.py` Fernet / model `set_secret()`.
- Never add a model without a UUID pk + explicit `db_table` (and a UNFOLD nav entry if it has admin).
- Never query `PlatformSettings.objects` directly — use `get_solo()`.
- Never put business logic in views when it belongs in a service module reused by admin/Celery.
- Never bypass the `storage_s3` helpers with ad-hoc boto3 clients; never write `.md` report files.

## Related

- [Root CLAUDE.md](../../CLAUDE.md) — monorepo map, platform layout, production deploy safety rules (read before deploying).
