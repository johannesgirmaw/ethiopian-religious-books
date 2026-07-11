# Claude Code — Felege Metsahft

Monorepo: Django API (`services/django_api/`), Flutter reader (`apps/reader_flutter/`), infra (`infra/`).

## Nested guides (auto-loaded per subtree)

Each area has its own `CLAUDE.md` that this file's rules combine with — it loads automatically
when you read/edit files in that subtree. **Consult the relevant one before working there.**


| When working in…                                         | Read                                                                                   |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Flutter app (entry, DI, config, security, storage, l10n) | [apps/reader_flutter/CLAUDE.md](apps/reader_flutter/CLAUDE.md)                         |
| Common layer + multi-platform contract                   | [apps/reader_flutter/lib/CLAUDE.md](apps/reader_flutter/lib/CLAUDE.md)                 |
| **iOS + Android** UI                                     | [apps/reader_flutter/lib/mobile/CLAUDE.md](apps/reader_flutter/lib/mobile/CLAUDE.md)   |
| **Web** UI                                               | [apps/reader_flutter/lib/web/CLAUDE.md](apps/reader_flutter/lib/web/CLAUDE.md)         |
| **macOS + Linux + Windows** UI                           | [apps/reader_flutter/lib/desktop/CLAUDE.md](apps/reader_flutter/lib/desktop/CLAUDE.md) |
| Django API                                               | [services/django_api/CLAUDE.md](services/django_api/CLAUDE.md)                         |
| Next.js landing                                          | [apps/landing/CLAUDE.md](apps/landing/CLAUDE.md)                                       |
| Build & deploy scripts                                   | [scripts/CLAUDE.md](scripts/CLAUDE.md)                                                 |


Cursor users: parallel Flutter rules live in `.cursor/rules/reader-flutter-*.mdc` (kept in sync with the `lib/*` guides above).

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


| Target                | UI folder      | Runner                         |
| --------------------- | -------------- | ------------------------------ |
| Android, iOS          | `lib/mobile/`  | `android/`, `ios/`             |
| Web                   | `lib/web/`     | `web/`                         |
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

## Production deployment ([felegemetsahft.com](http://felegemetsahft.com))

**ALWAYS read and follow this section before deploying anything to the server.**

Production runs on a single VPS (SSH alias `felegemetsahft` → [root@187.55.226.86](mailto:root@187.55.226.86), Ubuntu 24.04).
Docker Compose stack (Postgres + Redis + MinIO + Django/gunicorn + Celery) behind host Nginx with
Let's Encrypt TLS. Live hosts:


| Host                         | Serves                                                                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `felegemetsahft.com` / `www` | Next.js **landing** static export (`/var/www/felegemetsahft/landing`) + `/downloads/` app installers (`/var/www/felegemetsahft/downloads`) |
| `app.felegemetsahft.com`     | Flutter **web app** static build (`/var/www/felegemetsahft/web`)                                                                           |
| `api.felegemetsahft.com`     | Django API (`127.0.0.1:8000`)                                                                                                              |
| `files.felegemetsahft.com`   | MinIO S3 for presigned book/cover URLs (`127.0.0.1:9000`)                                                                                  |


Landing lives in `apps/landing/` (Next.js, `output: 'export'`); login/register links point to
`app.felegemetsahft.com/#/login` (Flutter web uses hash routing). Server layout:
`/opt/felegemetsahft/{django_api,prod}` · compose file `prod/docker-compose.prod.yml` · env
`prod/.env.prod` (symlinked as `prod/.env`). All release Flutter builds must set
`--dart-define=API_BASE_URL=https://api.felegemetsahft.com/v1/`. The Flutter web origin is
`app.felegemetsahft.com`, so it MUST stay in the API's `CORS_ALLOWED_ORIGINS` / `CSRF_TRUSTED_ORIGINS`.

**Deploy with the script — do not hand-run ad-hoc rsync/ssh:**

```
scripts/deploy-prod.sh          # api + web + landing
scripts/deploy-prod.sh api      # Django only  (rsync → rebuild → restart; migrations auto-run on start)
scripts/deploy-prod.sh web      # Flutter web app only (app.felegemetsahft.com)
scripts/deploy-prod.sh landing  # Next.js landing only (felegemetsahft.com)
scripts/deploy-prod.sh downloads # upload installers in dist/downloads/ -> /downloads/
```



### Windows (and other desktop) installers

Windows `.exe` **cannot be built on macOS** — it builds in GitHub Actions. Flow:

1. Actions → **"Build apps (all platforms)"** → Run workflow (the Windows job builds the
  runner and packages it into `felege-metsahft-setup.exe` via Inno Setup —
   `apps/reader_flutter/windows/packaging/felege_metsahft.iss`).
2. Download the `felege-metsahft-windows` artifact and drop the `.exe` into `dist/downloads/`
  (git-ignored).
3. `scripts/deploy-prod.sh downloads` (uploads to `/var/www/felegemetsahft/downloads/`, no
  `--delete`), then `scripts/deploy-prod.sh landing` so the landing "Download for Windows"
   link goes live. Landing points at `felege-metsahft-setup.exe` by default.

Build is unsigned → first-run SmartScreen ("More info → Run anyway"); real signing needs a paid
cert. `image_picker` has no Windows impl, so desktop uses `file_picker` for cover uploads.

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

