# Build & deploy scripts — bash orchestration for building/running/deploying the reader + local API. NO app logic, NO secrets, NO server-side config live here (those are in `services/django_api/`, `infra/`, and only on the VPS).

## Layout
| File | Role |
| --- | --- |
| [`deploy-prod.sh`](deploy-prod.sh) | ONLY sanctioned prod deploy driver: `api\|web\|landing\|downloads\|all`. rsync → ssh `felegemetsahft` → `docker compose -f docker-compose.prod.yml up -d --build` → 4 curl health checks. |
| [`flutter_reader_common.sh`](flutter_reader_common.sh) | Sourced helper lib (guarded by `FLUTTER_READER_COMMON_LOADED`): `PRODUCTION_API_BASE_URL`, platform validation, host-build guards, dev/release API URL resolution, dart_defines, emulator/sim boot, `ensure_local_api_running`. |
| [`build_reader_flutter.sh`](build_reader_flutter.sh) | Release build entrypoint `<platform>`. Env: `API_BASE_URL`, `READER_APK_ABI`, `READER_BUILD_FORMAT`, `FLUTTER_CREATE_PLATFORM`. |
| `build_reader_{apk_release,ios,macos,web,linux,windows}.sh` | Thin `exec` wrappers → `build_reader_flutter.sh <platform>`. |
| [`run_reader_flutter.sh`](run_reader_flutter.sh) | Debug run entrypoint: discover device, resolve LOCAL dev API URL, `flutter run`. |
| `run_reader_{web,linux,windows}.sh`, `run_reader_{android_emulator,ios_simulator}.sh` | Run wrappers; emulator/sim scripts boot a device (`--no-backend`, `--no-seed`, `ANDROID_AVD`/`IOS_SIMULATOR_UDID`). |
| [`setup_reader_flutter.sh`](setup_reader_flutter.sh) | One-time: `flutter config` enables + `pub get`; iOS pods only if `INSTALL_READER_IOS=1`. |
| [`run_dev.sh`](run_dev.sh) | Local full loop: Docker stack + migrate + `seed_dev` + run reader. `--down`/`--no-backend`/`--no-seed`. |
| [`dev.sh`](dev.sh) (+ dup `dev`) | Foreground `docker compose up --build` of infra only. |
| [`verify_backend.sh`](verify_backend.sh) | Backend HTTP smoke test (login/books/authz/presigned/ETag) vs Compose stack. |
| [`print_api_url.sh`](print_api_url.sh) | Print local API base URL + Swagger/health from running container port. |
| [`seed_ethiopian_history.sh`](seed_ethiopian_history.sh) | Run `seed_ethiopian_history` in api container. |
| [`../.github/workflows/build-apps.yml`](../.github/workflows/build-apps.yml) | Manual CI (`workflow_dispatch`): Windows `.exe`, Linux tar, Android APK, macOS dmg. Flutter 3.44.0. |

## Conventions
- Every script uses `set -euo pipefail` and self-locates its root via `cd "$(dirname "${BASH_SOURCE[0]}")/.."` — invoke from any cwd.
- Do NOT reimplement logic in per-platform scripts: source `flutter_reader_common.sh`; keep wrappers as 2-3 line `exec` calls.
- The `Makefile` is the front door — most script-backed `make` targets `chmod +x` then run the script (infra/seed/openapi targets call `docker compose`/`flutter` directly). Document both the make target and the script.
- API URL: DEBUG uses `dev_api_base_url_for_platform` (localhost / android `10.0.2.2` + `infra/.env` `API_PORT`); RELEASE uses `release_api_base_url` (defaults `PRODUCTION_API_BASE_URL`, override via `API_BASE_URL`). Always normalized to trailing `/`.
- Local Docker always `-f infra/docker-compose.yml --env-file infra/.env`; prod runs on server via ssh with `-f docker-compose.prod.yml`. Never mix the two compose files.
- Host guards (`ensure_host_can_build`) REJECT cross-compiling: macOS/iOS need Darwin, Windows needs a Windows host.
- Names: Flutter product = `ethiopian_reader`; user brand = `Felege Metsahft` (installer/dmg/tarball).

## Commands
- `scripts/deploy-prod.sh [api|web|landing|downloads|all]` — deploy to prod VPS + health checks (no arg = api+web+landing).
- `scripts/deploy-prod.sh downloads` — rsync `dist/downloads/` → server (NO `--delete`; hard-fails if empty).
- `make run-dev` / `scripts/run_dev.sh` — Docker API + migrate + seed_dev, then run reader.
- `make dev` / `scripts/dev.sh` — foreground infra `docker compose up --build`.
- `scripts/verify_backend.sh` — backend HTTP smoke test vs Compose stack.
- `make reader-setup` — pub get + flutter config enables.
- `make reader-run-{android,ios,macos,web,linux,windows}` — debug run (dev API auto-resolved).
- `make reader-build-{apk-release,android,ios,macos,web,linux,windows}` — release build (defaults prod API).
- `make infra-up` / `infra-down` / `infra-logs` — local infra lifecycle.
- `make seed` / `seed-covers` · `scripts/seed_ethiopian_history.sh` — Django seed commands in api container.
- `make print-api-url` — show local API/Swagger/health URLs.
- Actions → "Build apps (all platforms)" (`workflow_dispatch`) — ONLY way to build the Windows `.exe`.

## Gotchas
- CRITICAL: `flutter_reader_common.sh` still defaults `PRODUCTION_API_BASE_URL` to the RETIRED Render host `https://religious-books-api-wz6y.onrender.com/v1/`, NOT `https://api.felegemetsahft.com/v1/` (its "keep in sync with `app_config.dart`" comment is stale — `_productionApiBaseUrl` there is already correct). Local desktop/mobile release builds bake the WRONG URL unless you pass `API_BASE_URL=https://api.felegemetsahft.com/v1/`. `deploy-prod.sh web` hardcodes the correct URL and `build-apps.yml` defaults its `api_base_url` input to it, so only local release scripts are affected.
- Windows `.exe` can't build on macOS/Linux (enforced). Flow: Actions → download `felege-metsahft-windows` → `dist/downloads/` → `deploy-prod.sh downloads` → `deploy-prod.sh landing`. Build is unsigned (SmartScreen).
- `deploy-prod.sh` builds web (`flutter build web`) and landing (`npm run build`) on YOUR machine (need flutter + node); only the API image builds server-side from rsynced source — confirm your branch/commit first.
- `web`/`landing`/`api` rsync with `--delete` (mirror); `downloads` omits it so other-platform installers survive. `dist/downloads/` is git-ignored — populate before deploying.
- Local API port is NOT hardcoded — resolved from `infra/.env` `API_PORT` (default 8000) or the running container's mapped port. Use `print_api_url.sh` rather than assuming. (Other compose offsets: pg 15432, redis 16379, minio 19000/19001, mailhog UI 18025.)
- `run_dev.sh`'s `free_host_port` STOPS conflicting containers and KILLs host PIDs on the API port (skips the Docker daemon) — surprising if another service owns it.
- `dev` and `dev.sh` are near-identical duplicates (one whitespace diff); the Makefile only calls `dev.sh` — edit `dev.sh`.

## Never do
- NEVER hand-run ad-hoc rsync/ssh/`docker compose` against prod — use `deploy-prod.sh`. See ROOT CLAUDE.md "Production deployment" for authoritative safety rules.
- NEVER `docker compose down -v`, drop volumes, or reset DNS on prod (pgdata/minio_data hold all books + users) without explicit user confirmation.
- NEVER put secrets, the server IP, or `prod/.env.prod` contents in these scripts or in chat/commits.
- NEVER ship a local desktop/mobile release build without `API_BASE_URL=https://api.felegemetsahft.com/v1/`.
- NEVER report a deploy successful if any of the 4 health checks (landing/app/api/files) is non-200.
- NEVER add application/business logic here — app code belongs in `services/django_api` or `apps/reader_flutter`.
- NEVER duplicate the shared helpers — extend `flutter_reader_common.sh`; keep per-platform files thin `exec` wrappers.

## Related
- [Root CLAUDE.md](../CLAUDE.md) — monorepo map, platform map, production deploy safety.
