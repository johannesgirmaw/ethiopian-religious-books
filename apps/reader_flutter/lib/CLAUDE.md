# Reader lib — common layer & multi-platform contract

Cross-platform logic/tokens/routing live in root folders; `lib/screens/` route adapters branch **web → desktop → mobile**. NO platform-specific widgets, layouts, scaffolds, breakpoints, or hardcoded strings may live in root `lib/` or cross-import between `mobile/`/`web/`/`desktop/`. Platform/deploy map is in [../../../CLAUDE.md](../../../CLAUDE.md).

## Layout
| Path | Role |
| --- | --- |
| `config/` | COMMON. API base URL/env/host resolution (`app_config.dart`). |
| `design/` | COMMON brand tokens: `app_tokens.dart` (AppColors, AppSpace, AppRadius, AppLayout, AppGradients), `app_theme.dart` (AppTheme.light — the only theme), `app_typography.dart`, `reader_typography.dart`, `app_decorations.dart`, `reference_assets.dart`. |
| `l10n/` | COMMON. `app_en.arb` + `app_am.arb` + generated `app_localizations*.dart`. ALL user copy lives here. |
| `models/` | COMMON DTOs/domain models (`book_models.dart`, `download_job.dart`). |
| `providers/` | COMMON Riverpod state (api_client, session_notifier, auth_api, catalog/payment/bible providers, `app_locale_provider`). One impl per feature. |
| `router/` | COMMON go_router: `app_router.dart` (goRouterProvider), `app_navigation.dart`. Hash routing on web. |
| `storage/` | COMMON secure storage, caches, prefs. |
| `security/` | COMMON crypto/identity: `book_crypto.dart`, `device_identity.dart`, `secure_key_value.dart`. |
| `utils/` | COMMON pure helpers — no BuildContext, no platform UI. |
| `common/platform/platform_shell.dart` | Shell guards: `useWebShell`, `useDesktopShell`, `useMobileShell`, `useWideAuthSplit` + getters `isMobilePlatform`/`isDesktopPlatform`. |
| `screens/` | Route adapters ONLY — `ConsumerWidget`s that wire providers/l10n and branch to platform bodies. |
| `mobile/` | iOS + Android UI ONLY (`design/ layout/ screens/ widgets/{shell,catalog,reader}`). |
| `web/` | Web UI ONLY. `design/web_tokens.dart` (WebTokens), `layout/app_layout_scope.dart` (AppLayoutScope tiers), `widgets/shell/` (WebPageScaffold, WebOverlayScaffold). |
| `desktop/` | macOS + Linux + Windows UI ONLY (one codebase, three runners). `design/desktop_tokens.dart` (DesktopTokens), `widgets/shell/` (DesktopPageScaffold, DesktopOverlayScaffold). |
| `widgets/` | LEGACY root-level mobile widgets (`app_state_view`, `premium_gate`, `skeleton_loader`, `primitives/`, `reference/`). Migrate to `mobile/widgets/` when you touch a file. |
| `app.dart` | `EthiopianReaderApp`: MaterialApp.router → goRouterProvider + appLocaleProvider, theme AppTheme.light, AppLocalizations delegates. |
| `main.dart` | Entrypoint (ProviderScope + EthiopianReaderApp). |

## Conventions
- Route-adapter branch order is EXACTLY: `if (useWebShell(context)) return Web…Scaffold(...); if (useDesktopShell(context)) return Desktop…Scaffold(...); return Mobile…` — mobile is the unguarded fallthrough (see `screens/home_screen.dart`, `screens/book_detail_screen.dart`).
- `screens/` is the ONLY place allowed to import all three of `mobile/`/`web/`/`desktop/`.
- `useMobileShell` = native iOS/Android OR web narrower than the compact breakpoint; `useDesktopShell` is never true on web. So narrow web renders the mobile body.
- Consume brand tokens by class name: `AppColors.primary`, `AppSpace.md`, `AppRadius.cardV2`, `AppLayout.page`. Platform folders EXTEND them via WebTokens / DesktopTokens — do not fork the shared values.
- All copy via `final l10n = AppLocalizations.of(context)!;` then `l10n.<key>`; add every new key to BOTH `app_en.arb` and `app_am.arb`.
- Name platform bodies to avoid collisions: web `HomeScreenBody` vs `DesktopHomeScreenBody`; import same-named bodies under distinct symbols.
- Feature parity across all six targets unless explicitly scoped: logic once in common, UI implemented three times.

## Commands
- `make reader-run-android` — run reader on Android
- `make reader-run-ios` — run reader on iOS
- `make reader-run-web` — run reader as Flutter web app
- `make reader-run-macos` — run reader on macOS
- `make reader-run-linux` — run reader on Linux
- `make reader-run-windows` — run reader on Windows

## Gotchas
- `security/` is common-layer but is missing from the cursor `common.mdc` glob — still treat it as shared, never platform-specific.
- `widgets/` is legacy mobile-only, NOT a common folder — don't treat root `widgets/` as shared UI.
- No `MobileTokens` class exists (only WebTokens / DesktopTokens); mobile UI mostly consumes root AppColors/AppSpace/AppRadius directly.
- Single theme `AppTheme.light` wired in `app.dart` — no dark theme, no theme-switching.
- Web uses hash routing and AppLayoutScope tiers (`web/layout/app_layout_scope.dart`) drive breakpoint decisions like `useWideAuthSplit`.
- Some `screens/*.dart` still carry an inline legacy mobile Scaffold (e.g. `book_detail_screen.dart`) — migrate that branch into `mobile/` when editing.

## Never do
- Never put platform widgets/layouts/scaffolds/breakpoint UI in root `config/design/l10n/models/providers/router/storage/security/utils` — those are logic/tokens only.
- Never import `mobile/`, `web/`, or `desktop/` from common code, nor import one platform folder from another (only `screens/` imports all three).
- Never hardcode user-visible strings — add to `app_en.arb` AND `app_am.arb`, read via AppLocalizations.
- Never reorder the branch away from web → desktop → mobile, and never leave mobile guarded (it must be the fallthrough).
- Never duplicate feature logic per platform — data/auth/sync/business rules live once in providers/models/storage/security.
- Never copy platform widget trees between platforms to "share" them — share tokens/patterns, re-implement the UI.

## Related
- [../../../CLAUDE.md](../../../CLAUDE.md) — repo root (monorepo map, platform table, prod deploy safety)
- [../../../.cursor/rules/reader-flutter-common.mdc](../../../.cursor/rules/reader-flutter-common.mdc)
- [../../../.cursor/rules/reader-flutter-multiplatform.mdc](../../../.cursor/rules/reader-flutter-multiplatform.mdc)
- [../DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md)
