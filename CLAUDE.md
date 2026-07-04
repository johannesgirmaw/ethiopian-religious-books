# Claude Code — Ethiopian Religious Books

Monorepo: Django API (`services/django_api/`), Flutter reader (`apps/reader_flutter/`), infra (`infra/`).

## Reader folder layout

```
apps/reader_flutter/lib/
├── config/ design/ l10n/ models/ providers/ router/ storage/ utils/   ← COMMON
├── common/platform/platform_shell.dart   ← useMobileShell, useWebShell, useDesktopShell
├── screens/                              ← route adapters (branch to platform UI)
├── mobile/                               ← iOS + Android ONLY
├── web/                                  ← Flutter Web ONLY
└── desktop/                              ← macOS + Linux + Windows ONLY
```

Each platform folder mirrors the same internal shape:

```
<platform>/
  design/     # platform layout tokens (extend lib/design/app_tokens.dart)
  layout/     # breakpoints, scope, insets
  screens/    # screen bodies / full screens
  widgets/    # shell/, catalog/, reader/, common/
```

## Platform map

| Target | UI folder | Runner |
| --- | --- | --- |
| Android, iOS | `lib/mobile/` | `android/`, `ios/` |
| Web | `lib/web/` | `web/` |
| macOS, Linux, Windows | `lib/desktop/` | `macos/`, `linux/`, `windows/` |

**Legacy:** mobile widgets still in `lib/widgets/`; migrate to `lib/mobile/` when editing.

## Rules

1. **Common once** — logic, models, providers, storage, l10n, shared brand tokens in root `lib/` folders.
2. **UI per platform** — implement separately in `mobile/`, `web/`, `desktop/`. No cross-imports between them.
3. **Feature parity** — every user-facing feature on all six targets unless explicitly scoped.
4. **Route adapters** (`lib/screens/`) branch in order: web → desktop → mobile.

```dart
if (useWebShell(context)) { return WebPageScaffold(body: HomeScreenBody()); }
if (useDesktopShell(context)) { return DesktopPageScaffold(body: HomeScreenBody()); }
return const MobileHomeScreen();
```

## Run / build

`make reader-run-{android,ios,web,macos,linux,windows}` from repo root.

## Cursor rules

`.cursor/rules/reader-flutter-{multiplatform,common,mobile-ui,web-ui,desktop-ui}.mdc`

## Backend

`make infra-up`, `make run-dev` · API config: `lib/config/app_config.dart`

## Production deployment (felegemetsahft.com)

**ALWAYS read and follow this section before deploying anything to the server.**

Production runs on a single VPS (SSH alias `felegemetsahft` → root@187.55.226.86, Ubuntu 24.04).
Docker Compose stack (Postgres + Redis + MinIO + Django/gunicorn + Celery) behind host Nginx with
Let's Encrypt TLS. Live hosts:

| Host | Serves |
| --- | --- |
| `felegemetsahft.com` / `www` | Flutter **web** static build (`/var/www/felegemetsahft/web`) |
| `api.felegemetsahft.com` | Django API (`127.0.0.1:8000`) |
| `files.felegemetsahft.com` | MinIO S3 for presigned book/cover URLs (`127.0.0.1:9000`) |

Server layout: `/opt/felegemetsahft/{django_api,prod}` · compose file `prod/docker-compose.prod.yml`
· env `prod/.env.prod` (symlinked as `prod/.env`). All release Flutter builds must set
`--dart-define=API_BASE_URL=https://api.felegemetsahft.com/v1/`.

**Deploy with the script — do not hand-run ad-hoc rsync/ssh:**

```
scripts/deploy-prod.sh        # api + web
scripts/deploy-prod.sh api    # Django only  (rsync → rebuild → restart; migrations auto-run on start)
scripts/deploy-prod.sh web    # Flutter web only
```

### Deployment rules (MUST follow)

1. **Never** commit or print secrets. `prod/.env.prod` (DB/MinIO/Django/admin creds) lives ONLY on the
   server and is git-ignored — never recreate it in the repo or paste its contents into chat/commits.
2. **Never** run `docker compose down -v`, drop volumes, or `Reset DNS records` — `pgdata`/`minio_data`
   hold all books and users. Destructive DB/volume ops require explicit user confirmation.
3. Confirm you are deploying the intended branch/commit; the API image is built from the rsynced source,
   not from git on the server.
4. After every deploy, verify the three health checks pass (the script does this): web/api/files → 200.
   If any is non-200, investigate before reporting success.
5. Schema/data migrations run automatically in the container entrypoint on start — no manual `migrate`.
6. Changing API URL, CORS, or hostnames means rebuilding the web bundle (URL is baked at build time)
   AND updating `_productionApiBaseUrl` in `lib/config/app_config.dart` for desktop/mobile.
7. TLS auto-renews via Certbot; if adding a new subdomain, extend the Nginx site + rerun certbot with
   all `-d` domains.
