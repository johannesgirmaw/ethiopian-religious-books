# Reader Web UI (Flutter Web) — `lib/web/`

Flutter Web-only UI: shell/catalog/reader/auth widgets + `*_body` screen content rendered by `lib/screens/` adapters when `useWebShell(context)` is true. UI + local state ONLY — no providers, models, API clients, storage, or l10n here (import those from root `lib/`). See root [../../../../CLAUDE.md](../../../../CLAUDE.md) for the monorepo/platform map and deploy safety.

## Layout

```
lib/web/
  design/web_tokens.dart          # WebTokens: maxContentWidth 1200, readerColumnWidth 720,
                                   #   sidebarWidth 260, breakpoints 720/1100, colors + decoration helpers
  layout/
    app_layout_scope.dart         # AppLayoutTier{compact,medium,expanded}, tierForWidth, useWebShell,
                                   #   AppLayoutScope (Inherited) + AppLayoutScopeBuilder (LayoutBuilder)
    web_content_frame.dart        # WebContentFrame: clamp to maxContentWidth, top-center
  screens/                        # *_body page content (no scaffold): home, book_detail, profile,
                                   #   settings, about, downloads, admin_books
  widgets/
    shell/    # web_shell_scaffold, web_app_shell, web_sidebar, web_page_scaffold,
              #   web_overlay_scaffold, web_top_nav_bar, adaptive_auth_layout, web_auth_shell/layout
    catalog/  # catalog_grid_delegate, web_book_card, book_tile_hover (WebBookTileHover),
              #   web_featured_carousel/card, web_continue_reading_strip, home_resume_banner,
              #   catalog_browse_header/panel
    reader/   # web_reader_layout (webConstrainReaderContent/…), web_reader_chapter_grid
    common/   # web_page_header, web_section, web_metric_row
```
Entry points live OUTSIDE this folder: adapters in `lib/screens/*.dart`; shell selectors in `lib/common/platform/platform_shell.dart` (which re-uses `useWebShell` from `layout/app_layout_scope.dart`); runner in `apps/reader_flutter/web/`.

## Conventions

- **`useWebShell(context)` is the ONLY gate** for web UI: true when `kIsWeb` AND resolved tier != compact (width >= 720). It lives in `layout/app_layout_scope.dart`, not `platform_shell.dart`.
- **Adapters branch web → desktop → mobile** in fixed order: `if (useWebShell(context)) return WebPageScaffold(body: XBody()); if (useDesktopShell(context)) …; return const MobileXScreen();`
- **Read tiers via `AppLayoutScope.tierOf(context)`** (compact<720 / medium 720–1099 / expanded>=1100) for column counts, padding, auth split (`useWideAuthSplit` = expanded) — never re-derive from MediaQuery width inside web widgets.
- **Wrap `AppLayoutScopeBuilder` above** anything reading `tierOf`/`widthOf`/`useWebShell`. Shell + auth routes get it via `WebAppShell`/`web_auth_*`; standalone adapters (`book_detail_screen`, `payment_screen`) wrap it themselves.
- **Name content classes `<Name>ScreenBody`/`<Name>Body`** — pure content, local state only (controllers, debounce `Timer`s, filters). Data comes from imported root providers via Riverpod `ref`.
- **Web-only interaction lives here**: `WebBookTileHover` (FocusableActionDetector, Enter/Space → ActivateIntent → `context.push`), multi-column SliverGrid via `catalogGridDelegate(context)` (2/3/5 cols by tier, aspectRatio 0.56), persistent `WebSidebar`.
- **Style with `WebTokens.*` + helpers** (`panelDecoration`, `sidebarDecoration`, `pagePadding`); brand colors come from `AppColors` in `lib/design/app_tokens.dart`, and WebTokens reuses `AppLayout.pageHorizontal` from there while adding its own web surface colors.
- Shared reader code (`lib/screens/reader_screen.dart`) calls `webConstrainReaderContent`/`webReaderHorizontalPadding`/`webReaderTopInset` inline — those self-guard with `if (!useWebShell(context))`.

## Commands

- `make reader-run-web` — run reader in Chrome (Flutter Web)
- `make reader-build-web` — produce static web build (`app.felegemetsahft.com` bundle)
- `scripts/deploy-prod.sh web` — deploy Flutter web app only (API URL baked at build time)

## Gotchas

- **Narrow web (<720px) renders `lib/mobile/`, NOT `lib/web/`.** Any feature must also exist in mobile UI or it silently vanishes on small browser windows — never assume sidebar/hover/grid exist.
- `useWebShell` reads `AppLayoutScope.width` when a scope is present (>0), else falls back to `MediaQuery.sizeOf(context).width` (full window) — reading tier without a scope above can disagree with the bounded content column.
- `WebPageScaffold` does NOT provide an `AppLayoutScope` (only width-clamping via `WebContentFrame`). New tier-aware `*_body`s need `AppLayoutScopeBuilder` in their route adapter.
- `catalogGridDelegate` hardcodes both cross/main axis spacing to 20 and `childAspectRatio` to 0.56 inline — `WebTokens.gridMainSpacing` (24) is NOT used by the grid.
- `apps/reader_flutter/web/manifest.json` name is branded ("ፈለገ መጻሕፍት"), but `theme_color`/`background_color` are still the Flutter-scaffold default `#0175C2` and description is "A new Flutter project." — not the cyan/orange brand; fix if touching PWA/theming.
- Flutter web uses hash routing (`app.felegemetsahft.com/#/login`); landing login/register links depend on it.
- API base URL is compile-time baked — release builds pass `--dart-define=API_BASE_URL=https://api.felegemetsahft.com/v1/` (deploy script handles it); changing it needs a rebuild, not just redeploy.

## Never do

- Never import from `lib/mobile/` or `lib/desktop/` here (or vice-versa). Adapters in `lib/screens/` are the only place all three meet.
- Never define providers, models, API clients, storage, or l10n in `lib/web/` — import from root `lib/`.
- Never gate web UI on `MediaQuery` width or `kIsWeb` directly — use `useWebShell(context)` + `AppLayoutScope.tierOf(context)`.
- Never assume sidebar/hover/multi-column grid are present — they exist only at medium/expanded tier.
- Never hardcode brand hex or spacing when a `WebTokens` constant/helper or `AppColors` exists.
- Never put mobile scaffolding (app bars, bottom nav) inside a `*_body` — bodies are pure content; chrome is `WebPageScaffold`/`WebShellScaffold`.

## Related

- Root: [../../../../CLAUDE.md](../../../../CLAUDE.md)
- [.cursor/rules/reader-flutter-web-ui.mdc](../../../../.cursor/rules/reader-flutter-web-ui.mdc)
- [.cursor/rules/reader-flutter-multiplatform.mdc](../../../../.cursor/rules/reader-flutter-multiplatform.mdc)
- [.cursor/rules/reader-flutter-common.mdc](../../../../.cursor/rules/reader-flutter-common.mdc)
