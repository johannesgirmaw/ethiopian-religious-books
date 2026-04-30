# Django API (`services/django_api`)

## Run with Docker (recommended)

From repo root:

```bash
cd infra
cp -n .env.example .env
docker compose up --build api
```

- **Browser (Swagger):** from repo root run `./scripts/print_api_url.sh` or `make print-api-url` — the host port is **`API_PORT`** in `infra/.env` (default in `.env.example` is **8000**). Example: `http://127.0.0.1:8000/api/docs/`.
- Health: `GET /healthz/`
- OpenAPI YAML: `GET /api/schema/`
- OpenAPI JSON: `GET /api/schema/?format=json`
- Swagger UI: `GET /api/docs/`

After first boot, seed demo data:

```bash
docker compose exec api python manage.py seed_dev
```

Log in as **admin@localhost** / **adminadminadmin** (Django admin) or **reader@localhost** / **readerreader** (API reader).

## Auth examples

Register:

```bash
curl -s -X POST http://localhost:8000/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"u@example.com","password":"longpassword1","display_name":"U"}'
```

Login:

```bash
curl -s -X POST http://localhost:8000/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"reader@localhost","password":"readerreader"}'
```

Books (needs `Authorization: Bearer <access>`):

```bash
curl -s http://localhost:8000/v1/books -H "Authorization: Bearer ACCESS"
```

## Migrations

If `migrate` fails on a dependency error for `auth.0012_...`, your Django version may differ. Regenerate with:

```bash
docker compose run --rm api python manage.py makemigrations
```

(Use Python 3.12+ in Docker; local older Python is not supported for `manage.py` without Docker.)

## Celery

```bash
docker compose up celery_worker
```
