# Reader Flutter — app-level shell

App entry, DI, routing, config, l10n, security/storage for all six targets. Per-platform **UI** lives in [`lib/mobile/`](lib/mobile), [`lib/web/`](lib/web), [`lib/desktop/`](lib/desktop) — do NOT put UI here. See [root CLAUDE.md](../../CLAUDE.md) for the monorepo map, platform table, and prod-deploy safety.

## Layout

| Path | Purpose |
| --- | --- |
| [`lib/main.dart`](lib/main.dart) | Entry: init `AppConfig`, load persisted locale + Geez-number pref, run `ProviderScope(EthiopianReaderApp())`. |
| [`lib/app.dart`](lib/app.dart) | Root `ConsumerWidget`: `MaterialApp.router` on `goRouterProvider` + `appLocaleProvider`; theme = `AppTheme.light` (light-only). |
| [`lib/config/app_config.dart`](lib/config/app_config.dart) | API base URL resolver. `_productionApiBaseUrl` = prod; debug picks per-platform localhost; overrides normalized to a trailing slash. |
| `lib/config/resolve_api_host_{io,stub}.dart` | Conditional-import LAN-IPv4 discovery; macOS debug only. |
| [`lib/security/book_crypto.dart`](lib/security/book_crypto.dart) | AES-256-GCM seal/open. Device master key (KEK) in secure store key `vault_master_key_v1`. Blob = nonce(12)‖ct‖mac(16). |
| [`lib/security/device_identity.dart`](lib/security/device_identity.dart) | Per-install 128-bit device id (`device_id_v1`), `ensureRegistered(dio)`. |
| [`lib/security/secure_key_value.dart`](lib/security/secure_key_value.dart) | Secure KV; macOS DEBUG falls back to SharedPreferences to dodge keychain -34018 hang. |
| [`lib/storage/secure_book_store.dart`](lib/storage/secure_book_store.dart) | Encrypted vault `{docs}/library/{bookId}/{content,meta,license}.enc`; `hasValidOfflineAccess()` is the offline gate. |
| `lib/storage/vault/vault_fs_{io,stub}.dart` | Conditional-import byte I/O: native write-then-rename vs web base64-in-prefs. |
| [`lib/storage/token_storage.dart`](lib/storage/token_storage.dart) | Access/refresh token + user-JSON persistence for `SessionNotifier`. |
| `lib/storage/*_storage.dart` | app_locale, number_system, reader_prefs, catalog_cache, book_content_cache, download_jobs, form_draft. |
| [`lib/providers/api_client.dart`](lib/providers/api_client.dart) | `apiDioProvider`: Dio (connect 20s/receive 120s) + `AuthInterceptor` (Bearer inject, one 401→refresh retry). |
| [`lib/providers/session_notifier.dart`](lib/providers/session_notifier.dart) | `sessionNotifierProvider` AsyncNotifier; `tryRefresh` uses own token-less Dio; `clear()` wipes tokens + vault + master key. |
| `lib/providers/` | ~14 Riverpod providers (catalog, bible, study, engagement, payment, admin, download_jobs, continue_reading, locale, number_system). |
| [`lib/router/app_router.dart`](lib/router/app_router.dart) | `goRouterProvider`; `/splash` initial; redirect guards for `/admin`; two ShellRoutes; `/book/:id`→`/bible/book/:id` for Bible. |
| [`lib/screens/`](lib/screens) | ~22 route adapters that branch web→desktop→mobile (no platform UI). |
| [`lib/l10n/`](lib/l10n) | `app_en.arb` (template) + `app_am.arb`; generated `app_localizations*.dart`. Config in [`l10n.yaml`](l10n.yaml). |
| [`lib/common/platform/platform_shell.dart`](lib/common/platform/platform_shell.dart) | `isMobilePlatform`/`isDesktopPlatform` + `useMobileShell`/`useDesktopShell` (web's `useWebShell` lives in `lib/web/layout/app_layout_scope.dart`). |

## Conventions

- State/DI is **Riverpod** everywhere; providers named `*Provider`. No other state mgmt.
- All authenticated calls go through `apiDioProvider`'s Dio; the only hand-built Dio is the deliberate token-less one in `SessionNotifier.tryRefresh`.
- Offline books are envelope-DRM: AES-256-GCM with a device master key in the OS secure store, gated by a server-signed HS256 offline license in `license.enc`. Read the crypto/vault code; never re-implement.
- Conditional imports pick platform impls (`import 'stub.dart' if (dart.library.io) 'io.dart'`) for vault I/O and API-host resolution — keep BOTH sides compiling (web has no `dart:io`).
- New user-facing strings go in BOTH `app_en.arb` AND `app_am.arb`, then regenerate; access via `AppLocalizations.of(context)`. Never hardcode UI strings.
- `image_picker` has no Windows/Linux impl — on `isDesktopPlatform` use `file_picker` (see [`lib/screens/admin/admin_book_edit_screen.dart`](lib/screens/admin/admin_book_edit_screen.dart) ~L323).
- Route guards live in `app_router.dart` redirect: `/admin` needs auth, `/admin/books` needs `user.canManageBooks`, other `/admin` needs `user.isPlatformAdmin`.

## Commands

| Command | Does |
| --- | --- |
| `make reader-run-{android,ios,web,macos,linux,windows}` | Run on a target (dev API auto-injected). |
| `make reader-run-{android-emulator,ios-simulator}` | Boot device then run. |
| `make reader-pubget` | `flutter pub get`. |
| `make reader-test` | `flutter test`. |
| `make reader-build PLATFORM=<...>` | Release build (defaults API to prod, injects `--dart-define`). |
| `make reader-build-apk-release` | Release APK/AAB (`READER_APK_ABI`, `READER_BUILD_FORMAT`). |
| `make reader-build-web` | Static web build → `build/web/`. |
| `cd apps/reader_flutter && flutter test test/security/offline_encryption_test.dart` | AES-GCM / tamper / lease tests. |
| `API_BASE_URL=... make reader-build PLATFORM=web` | Override baked API URL. |
| `flutter gen-l10n` | Regenerate `app_localizations*.dart` from `.arb`. |

## Gotchas

- Release/profile builds hardcode the **prod** API unless `--dart-define=API_BASE_URL` is passed — build scripts inject it, but a hand-run `flutter build` without it silently ships prod. If the API host changes, update `_productionApiBaseUrl` (desktop/mobile) AND rebuild web (root rule 6).
- API base URL MUST end with a trailing slash or `Uri.resolve` drops the `/v1` prefix (auth/login → wrong path).
- macOS DEBUG stores master key + tokens in SharedPreferences, not keychain (avoids -34018 hang) — not representative of at-rest security; use `--dart-define=USE_MACOS_KEYCHAIN=true` to test the real path.
- Web has no `dart:io`/hardware keystore: vault falls back to base64-in-SharedPreferences.
- `SessionNotifier.clear()` (logout) wipes the entire encrypted library and master key — every downloaded book becomes permanently unreadable, by design.
- `tryRefresh()` uses connect 15s; shared Dio uses connect 20s / receive 120s (long receive is intentional for large book content).
- Android FLAG_SECURE is NOT implemented (`MainActivity.kt` is an empty `FlutterActivity`) — do not assume screen capture is blocked.
- New strings live in TWO arb files; forgetting `app_am.arb` ships an English string on the Amharic locale.

## Never do

- Never write plaintext book content, the master key, or licenses to disk — always go through `BookCrypto.seal` / `SecureBookStore`.
- Never construct authenticated Dio clients by hand — use `apiDioProvider` so the `AuthInterceptor` applies.
- Never set an API base URL without a trailing slash; never hand-edit the baked URL (use `--dart-define`/build scripts).
- Never put per-platform UI in this subtree — it belongs in `lib/mobile|web|desktop`; `lib/screens/` adapters only branch.
- Never hardcode user-facing strings or add a key to only one `.arb` file.
- Never break the conditional-import stub (web/no-io) side when adding vault or host-resolution logic.
- Never weaken or bypass the offline gate (`hasValidOfflineAccess`) or serve cached content without a this-device, unexpired license.

## Related

- [Root CLAUDE.md](../../CLAUDE.md) — monorepo map, platform table, prod deploy.
- [README-OFFLINE-ENCRYPTION.md](../../README-OFFLINE-ENCRYPTION.md) — vault/DRM design.
- Per-platform UI guides: [`lib/mobile/`](lib/mobile), [`lib/web/`](lib/web), [`lib/desktop/`](lib/desktop).
