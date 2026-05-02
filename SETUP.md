# Local development setup

This guide speeds up day-to-day work for **Flutter** + **Django** + **Docker Compose** (see [README-IMPLEMENTATION.md](README-IMPLEMENTATION.md)). It collects **ergonomics** practices: one-command startup, hot reload, device networking, seeds, codegen, and quality gates.

---

## Prerequisites

- **Docker Desktop** (or Docker Engine + Compose v2)  
- **Flutter** SDK (stable), Android toolchain / emulator as needed  
- **Node.js 20+** (for admin web)  
- **Python 3.12+** (if you run Django on the host against Docker-only data services)  
- Optional: `**just`** or use `**make**` (Makefile provided)  
- Optional: **[direnv](https://direnv.net/)** for auto-loading env vars in `infra/`

---

## Quick start

```bash
# From repo root (ethiopian-religious-books/)
cp infra/.env.example infra/.env          # edit if needed
cd infra
docker compose up --build -d              # postgres, redis, minio, mailhog, api, celery
```

Wait until `api` is healthy, then seed demo users + sample book:

```bash
docker compose exec api python manage.py seed_dev
```

Smoke test (uses the **real** host port for `api`, not always `8000`):

```bash
# From repo root — prints Swagger + health URLs (reads infra/.env API_PORT)
./scripts/print_api_url.sh

# Or set PORT manually from: cd infra && docker compose port api 8000
PORT=$(cd infra && docker compose --env-file .env port api 8000 2>/dev/null | sed 's/.*://')
curl -s "http://127.0.0.1:${PORT}/healthz/"
curl -s -X POST "http://127.0.0.1:${PORT}/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"reader@localhost","password":"readerreader"}'
```

**If the browser shows the wrong app or 404:** your `[infra/.env](infra/.env)` `**API_PORT`** may differ from what you typed (default in `.env.example` is **8000**). This project’s API is whatever port `**docker compose port api 8000`** prints (host → container mapping). Open **Swagger** at `http://127.0.0.1:<that-port>/api/docs/`.

From repo root you can also use `**make dev`** (foreground `docker compose up`) or `**make infra-up**` for **data services only** (no API).

### Reader app (Flutter) — Android-first

1. Install **Flutter** and the **Android toolchain** (Android Studio + SDK): [macOS Android setup](https://docs.flutter.dev/get-started/install/macos#android-setup). Run `flutter doctor` and `flutter doctor --android-licenses`.
2. With the API reachable on the host (see smoke test above), from repo root:
  ```bash
   ./scripts/setup_reader_flutter.sh     # pub get + macOS pods (iOS pods only if INSTALL_READER_IOS=1)
   ./scripts/run_reader_flutter.sh       # Android if available; else macOS desktop (no Android SDK OK)
  ```
   Or `**make reader-setup**`, `**make reader-run**`, `**make reader-run-android**`, `**make reader-run-macos**`. Optional iOS: `**make reader-run-ios**` after `INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh`.
3. Details, MinIO presign, and `API_BASE_URL`: [apps/reader_flutter/README.md](apps/reader_flutter/README.md).

---

## 1. One command to start the stack


| Command            | What it does                                                                                                            |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| `make infra-up`    | Starts **postgres, redis, minio, mailhog** from `[infra/docker-compose.yml](infra/docker-compose.yml)`.                 |
| `make infra-down`  | Stops those services.                                                                                                   |
| `./scripts/dev.sh` | Ensures `infra/.env` exists, runs **full** `docker compose up` (expects `api` + `celery` in compose when you add them). |
| `make dev`         | Same as `./scripts/dev.sh`.                                                                                             |


**Tip:** Add a `**Makefile`** target for **admin web** and **Flutter** only if you want one terminal per process; otherwise document URLs in a comment block (below).

**Default local URLs (infra only)**


| Service       | URL                                                               |
| ------------- | ----------------------------------------------------------------- |
| PostgreSQL    | `localhost:15432` (host `POSTGRES_PORT`; container is still 5432) |
| Redis         | `localhost:16379` (host `REDIS_PORT`)                             |
| MinIO S3 API  | `http://localhost:19000` (host `MINIO_API_PORT`)                  |
| MinIO console | `http://localhost:19001` (host `MINIO_CONSOLE_PORT`)              |
| Mailhog UI    | `http://localhost:18025` (host `MAILHOG_UI_PORT`)                 |


When the API container listens on **:8000** and is published as `**API_PORT`** (default **8000**), and Vite on **:5173**, add those to your team wiki or print them from `scripts/dev.sh`.

---

## 2. Hot reload for Django in Docker

**Problem:** Rebuilding the image on every Python change is slow.

**Approach:** Use a **development override** that bind-mounts the Django project and runs `**runserver`** (or **granian** / **uvicorn** with reload).

1. Copy the example override:
  ```bash
   cp infra/docker-compose.override.example.yml infra/docker-compose.override.yml
  ```
2. Adjust **service names** (`api`, `web`, etc.) to match your real `docker-compose.yml`.
3. Typical override pattern:
  - **Volumes:** `.:/app` (or `./services/django_api:/app`)  
  - **Command:** `python manage.py runserver 0.0.0.0:8000`  
  - **Environment:** `DEBUG=1`, `PYTHONUNBUFFERED=1`
4. `docker compose up api` — edits on the host reflect immediately.

**Do not commit** `docker-compose.override.yml` if it contains machine-specific paths; **do commit** `[docker-compose.override.example.yml](infra/docker-compose.override.example.yml)`.

---

## 3. Flutter ↔ API ↔ MinIO (Android-first)


| Client                            | API base URL                                              |
| --------------------------------- | --------------------------------------------------------- |
| **Android emulator** (v1 default) | `http://10.0.2.2:8000` (match `API_PORT` in `infra/.env`) |
| Physical Android (same Wi‑Fi)     | `http://<your-computer-LAN-IP>:8000`                      |
| iOS Simulator (optional)          | `http://localhost:8000`                                   |


**Presigned MinIO URLs** often use `localhost` or an internal Docker hostname — **phones cannot resolve them**.

**Mitigations (pick one early):**

1. Set Django / storage settings so presigned URLs use `**AWS_S3_ENDPOINT_URL`** or public host `**http://<LAN-IP>:19000**` in dev (match host `MINIO_API_PORT`).
2. Put **nginx** in front of API + MinIO under one host/port (more setup, fewer client hacks).
3. Use **Android emulator** only until this is fixed.

Document the chosen approach in `infra/.env.example` comments.

**Flutter:** use `**--dart-define=API_BASE_URL=...`** or **flavors** (`dev`, `staging`) so you switch targets without editing source.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

**Admin web (Vite):** `VITE_API_BASE_URL=http://localhost:8000/v1` in `.env.local` (match `API_PORT`).

---

## 4. Pre-commit, formatters, and static checks

Install once per clone:

```bash
pip install pre-commit
pre-commit install
```

Config: `[.pre-commit-config.yaml](.pre-commit-config.yaml)` (Ruff, Black, basic file hygiene). **Add a Flutter/Dart hook** when the app exists, for example:

```yaml
  - repo: local
    hooks:
      - id: dart-format
        name: dart format
        entry: dart format --output=none --set-exit-if-changed .
        language: system
        pass_filenames: false
        files: \.dart$
```

Run manually: `pre-commit run --all-files`.

---

## 5. Seed data and demo users

**Goal:** Flutter and admin developers can work without publishing a full book pipeline every time.

Add a Django management command, e.g.:

```bash
python manage.py seed_dev
```

It should create:

- `admin@localhost` / known password (document in SETUP only for **dev**, never prod)  
- 1–2 **published** books with minimal revision metadata (or stub revisions)  
- Sample **tags**

**Rule:** `seed_dev` is **idempotent** (safe to run twice). Wire into Makefile:

```bash
make seed   # docker compose exec api python manage.py seed_dev
```

(Adjust when `api` container exists.)

---

## 6. `docker compose watch` (optional)

Compose **v2.22+** supports rebuilding when `Dockerfile` or `requirements.txt` changes:

```bash
docker compose watch
```

Useful alongside **bind mounts** for Python code (watch for dependency changes; code still via volume).

---

## 7. Mailhog

With infra compose, SMTP points to `**mailhog:1025`** from inside Docker, or `**localhost:11025**` from Django on the host (host `MAILHOG_SMTP_PORT`, default 11025).

**Django `EMAIL_BACKEND`:** `django.core.mail.backends.smtp.EmailBackend` + `EMAIL_HOST=localhost` when Django runs on host.

View messages: **[http://localhost:18025](http://localhost:18025)** (host `MAILHOG_UI_PORT`).

---

## 8. OpenAPI → Dart / TypeScript

When `drf-spectacular` exposes `/api/schema/`, add targets (example):

```bash
# After API is running:
make openapi-export    # curl schema to packages/api_contract/openapi.json
make gen-dart          # openapi-generator-cli generate -i openapi.json -g dart-dio ...
make gen-ts            # openapi-typescript ...
```

Check generated clients into git **or** regenerate in CI; pick one policy for the team.

---

## 9. Faster pytest

In `requirements-dev.txt` (or equivalent):

```text
pytest-xdist>=3.0
```

```bash
pytest -n auto
```

Use `**pytest-django**` with a **test** database; optionally run tests inside `docker compose run --rm api pytest`.

---

## 10. Environment files and direnv

- `**[infra/.env.example](infra/.env.example)`** — document **every** variable; copy to `**infra/.env`** (gitignored).  
- **direnv:** in `infra/.envrc`:
  ```bash
  dotenv .env
  ```
  So `cd infra` loads vars for host-run `manage.py` or scripts.

---

## 11. Flutter flavors / defines (summary)


| Target   | Example                                           |
| -------- | ------------------------------------------------- |
| Emulator | `API_BASE_URL=http://10.0.2.2:8000/v1`            |
| Device   | `API_BASE_URL=http://192.168.1.10:8000/v1`        |
| Staging  | `API_BASE_URL=https://api-staging.example.com/v1` |


Use `**flutter run --dart-define=...**` or `**--flavor dev**` with `android/app/build.gradle.kts` product flavors.

---

## 12. Optional: mocked API for pure UI work

For UI-only sessions without backend:

- Check in **fixture JSON** under `apps/reader_flutter/test/fixtures/`  
- Or **Mockoon** / **WireMock** with recorded responses

Do not rely on mocks for **download + decrypt + reader** integration — use real stack periodically.

---

## 13. Compose healthchecks and startup order

Avoid races on first boot:

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

Postgres service should define `**healthcheck**` (`pg_isready`). Then `api` runs `**migrate**` or starts Gunicorn only when DB is ready.

---

## 14. Common pitfalls


| Symptom                | Likely cause                                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ |
| Empty catalog in app   | Not logged in, or Drift not synced; check `GET /v1/sync/catalog`.                                            |
| 403 on admin           | JWT role not `admin`.                                                                                        |
| Celery task never runs | Worker container down; Redis URL wrong.                                                                      |
| Email not sent         | `EMAIL_*` points to real SMTP instead of Mailhog in dev.                                                     |
| MinIO 403              | Bucket not created; run init script or create via console on host **:19001** (default `MINIO_CONSOLE_PORT`). |


---

## 15. Checklist before “I’m set up”

- `make infra-up` succeeds; MinIO console loads.  
- `infra/.env` created from `.env.example`.  
- Mailhog receives a test email from Django.  
- Flutter hits API from **emulator** using `10.0.2.2`.  
- `pre-commit install` done.  
- (When API exists) `make seed` or `seed_dev` run once.  
- (When API exists) Override file enables **Django hot reload** in Docker.

---

## Related docs

- [README.md](README.md) — product requirements and data model  
- [README-IMPLEMENTATION.md](README-IMPLEMENTATION.md) — architecture, APIs, Docker policy §12.1  
- [README-UI-UX.md](README-UI-UX.md) — reader UX constraints

