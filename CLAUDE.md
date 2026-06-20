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
