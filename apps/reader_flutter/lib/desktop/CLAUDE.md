# Reader desktop UI (macOS + Linux + Windows) — one shared Flutter UI codebase for native desktop targets.

Activated ONLY by `useDesktopShell(context)` (never `kIsWeb`). Holds the sidebar shell, catalog, split-screen auth, and per-page bodies. Must NOT contain web sidebars/browser chrome, mobile bottom-tabs/FABs, cross-imports from `lib/web` or `lib/mobile`, or native-runner config (that lives in `macos/ linux/ windows/`). See root [../../../../CLAUDE.md](../../../../CLAUDE.md) for the monorepo map and platform rules.

## Layout
```
design/desktop_tokens.dart        DesktopTokens (all layout numbers: minWindow 900x600, sidebarWidth 220,
                                  contentMaxWidth 1400, titleBarHeight 48, toolbarHeight 52) + DesktopLayoutTier
                                  enum (compact/medium/expanded @ 900/1200) + panel/sidebar decoration + text styles
layout/desktop_layout_scope.dart  DesktopLayoutScope InheritedWidget + DesktopLayoutScopeBuilder; DesktopLayoutScope.tierOf(context)
layout/desktop_content_frame.dart DesktopContentFrame — caps width at contentMaxWidth, top-center on ultrawide
widgets/shell/                     desktop_app_shell (Row: sidebar + Expanded col + _TitleBar breadcrumb),
                                  desktop_sidebar (rail + DesktopSidebarItem + defaultDesktopSidebarItems()/
                                  desktopSidebarItemsFor(ref,l10n) + DesktopNavShortcuts), desktop_shell_scaffold
                                  (go_router shell wrapper), desktop_page_scaffold({required body}),
                                  desktop_overlay_scaffold (sidebar + title bar for detail pages),
                                  desktop_auth_shell + desktop_auth_layout (split login/register)
screens/*_body.dart                Page bodies DesktopXxxScreenBody: home, book_detail, downloads, settings,
                                  profile, about, admin_books. Inserted into scaffolds by lib/screens/ adapters.
widgets/catalog/                   book_tile_hover, desktop_book_card, desktop_featured_card/_carousel,
                                  desktop_continue_reading_strip, catalog_browse_panel, catalog_grid_delegate
widgets/common/                    desktop_page_header, desktop_section, desktop_metric_row, desktop_scroll_body
```
No `widgets/reader/` folder yet — desktop reading is still served by shared `lib/screens/reader_screen.dart`.

## Conventions
- Activate desktop UI with `useDesktopShell(context)` / `isDesktopPlatform` from `lib/common/platform/platform_shell.dart`. Never gate on `kIsWeb`.
- Route adapters live in `lib/screens/*.dart` and branch web → desktop → mobile: `if (useWebShell(context)) return WebPageScaffold(...); if (useDesktopShell(context)) return DesktopPageScaffold(body: DesktopXxxScreenBody()); return const MobileXxxScreen();`.
- Page bodies are named `DesktopXxxScreenBody` and are wrapped by `DesktopPageScaffold`/`DesktopOverlayScaffold` at the adapter — bodies build no Scaffold/sidebar of their own.
- Put every layout magic number in `DesktopTokens`; pull brand colors/gradients from `lib/design/app_tokens.dart` (`AppColors`, `AppGradients`). Never hardcode brand colors here.
- Navigate with go_router (`context.go(route)`); sidebar selection is prefix-matched (`currentLocation.startsWith(route)`).
- Keyboard shortcuts use `Shortcuts`/`Actions` + `LogicalKeySet(meta, digitN)` in `DesktopNavShortcuts`; sidebar hint strings use ⌘ glyphs (⌘1..⌘5).
- Hover/interactivity idioms: `MouseRegion(cursor: SystemMouseCursors.click)`, `DesktopTokens.panelDecoration(hover: true)`, `AnimatedContainer` hover states (`book_tile_hover.dart`); admin-row context actions use `PopupMenuButton` (`admin_books_screen_body.dart`).
- Cover-image upload on desktop MUST use `FilePicker.platform.pickFiles(type: FileType.image, withData: true)` (guarded by `isDesktopPlatform` in `lib/screens/admin/admin_book_edit_screen.dart` `_pickCoverImage`) — not `image_picker`.
- Sidebar items are session-aware: admin/author entries only appear when `user.isPlatformAdmin` / `user.canManageBooks` — fetch via `desktopSidebarItemsFor(ref, l10n)`.
- All user-facing strings via `AppLocalizations.of(context)!`; the three runners share this one UI (full feature parity).

## Commands
- `make reader-run-macos` — run desktop app on macOS (runner in `macos/`).
- `make reader-run-linux` — run on Linux (binary `ethiopian_reader`).
- `make reader-run-windows` — run on Windows (local dev only; release `.exe` is CI-built).
- Actions → "Build apps (all platforms)" — builds macOS `.dmg`, Linux `.tar.gz`, Windows `felege-metsahft-setup.exe`.
- Windows `.exe` is packaged by Inno Setup ([windows/packaging/felege_metsahft.iss](../../windows/packaging/felege_metsahft.iss)) in the CI windows job only.

## Gotchas
- No `widgets/reader/` exists — desktop reader is the shared `lib/screens/reader_screen.dart` (~3371 lines) branching on `useDesktopShell`/`_supportsContinuousChapterPaging` and reusing `lib/web` + `lib/widgets` reader widgets. If you add a desktop reader, create `widgets/reader/` in the mirrored shape.
- Native binary/product name across all three runners is `ethiopian_reader` (not "felege"); the `.iss` sets `MyAppExeName=ethiopian_reader.exe`, installer output `felege-metsahft-setup.exe`, install dir `{autopf}\FelegeMetsahft`.
- `DesktopNavShortcuts` only wires Cmd+1..4 (/home /downloads /settings /profile). Sidebar shows a ⌘5 hint for admin/author but there is NO ⌘5 keybinding — map and hints are out of sync.
- `DesktopLayoutScope.tierOf`/`widthOf` return safe defaults (medium / 0) with no scope ancestor; only `DesktopAppShell` (via `DesktopLayoutScopeBuilder`) provides the scope, so bodies rendered outside the shell get no real tier data.
- `useWideAuthSplit(context)` triggers the split auth layout — always true on desktop but ALSO true for expanded-tier web, so it is shared logic, not desktop-only.
- The `.iss` AppId GUID `{{8F3A1C2E-...}}` is marked "Do not change" — changing it breaks upgrade/uninstall tracking.
- Windows `.exe` CANNOT be built on macOS — only in the GitHub Actions windows job.

## Never do
- Never gate desktop UI on `kIsWeb` — use `useDesktopShell(context)`/`isDesktopPlatform`.
- Never import from `lib/web/` or `lib/mobile/` inside `lib/desktop/`; brand tokens, logic, providers, and l10n come from root `lib/` only.
- Never add a WebSidebar, browser chrome, mobile bottom nav bar, or a phone FAB to desktop screens.
- Never inline brand colors or layout constants — use `AppColors`/`AppGradients` and `DesktopTokens`.
- Never use `image_picker` for desktop uploads (no Windows/Linux impl) — use `file_picker`.
- Never put native-runner config (window size, icons, entitlements, CMake, Inno Setup `.iss`) in `lib/desktop` — it belongs in `macos/`, `linux/`, `windows/`.
- Never rename the `ethiopian_reader` binary or change the `.iss` AppId GUID.

## Related
- Root guide: [../../../../CLAUDE.md](../../../../CLAUDE.md)
- Cursor rule: [../../../../.cursor/rules/reader-flutter-desktop-ui.mdc](../../../../.cursor/rules/reader-flutter-desktop-ui.mdc)
- Platform helpers: [../common/platform/platform_shell.dart](../common/platform/platform_shell.dart)
- Windows installer: [../../windows/packaging/felege_metsahft.iss](../../windows/packaging/felege_metsahft.iss)
- CI build: [../../../../.github/workflows/build-apps.yml](../../../../.github/workflows/build-apps.yml)
