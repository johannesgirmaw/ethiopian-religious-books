# Reader Mobile UI (iOS + Android)

Touch UI for the reader: Scaffold/SafeArea + floating bottom nav, no sidebar. **UI widgets only** — all logic/providers/models/l10n/storage/design tokens stay in root `lib/` and must never be reimplemented here. Never import `lib/web/` or `lib/desktop/`. See [root CLAUDE.md](../../../../CLAUDE.md) for the monorepo map, platform rules, and deploy safety.

## Layout

| Path | What |
| --- | --- |
| `screens/mobile_home_screen.dart` | The ONLY migrated screen. `MobileHomeScreen` (ConsumerStatefulWidget): SafeArea+Scaffold, 220ms-debounced search flipping browse mode (FeaturedCarousel, GenreChipRow, ContinueReadingCard, 2-col poster grid) ↔ search mode (CatalogFilterTabs + grid); filter/sort via `showModalBottomSheet`. **Copy this for new mobile screens.** |
| `widgets/catalog/` | Migrated tiles: `mobile_book_card.dart`, `book_cover_poster.dart` (`BookCoverPoster` — gradient + category icon, re-exports cover badges), `featured_carousel.dart`, `featured_book_card.dart`, `genre_chip_row.dart` (`GenreChipRow` + `genreOptionLabel(context, g)`), `catalog_filter_tabs.dart`, `continue_reading_card.dart`, `mobile_home_header.dart` (`MobileHomeTopBar` + `MobileSearchBar`) |
| `design/ layout/ screens/gitkeep widgets/shell/ widgets/reader/` | EMPTY (`.gitkeep` only). Skeleton from the cursor rule; shell/reader still live in legacy `lib/widgets/`. New shell/reader work lands **here**, not in `lib/widgets/`. |

Legacy deps imported via `../../widgets/...`: [`liquid_glass_nav_bar.dart`](../widgets/liquid_glass_nav_bar.dart) (`LiquidGlassNavBar` — statics `barHeight=80`, `bottomInset=110`), [`primitives/shell_primitives.dart`](../widgets/primitives/shell_primitives.dart) (`AppPanel`, `AppGreetingCard`, `AppSectionHeader`, …), [`primitives/auth_screen_layout.dart`](../widgets/primitives/auth_screen_layout.dart) (mobile auth chrome). Route adapters that pick this UI: [`screens/home_screen.dart`](../screens/home_screen.dart), [`screens/main_shell_screen.dart`](../screens/main_shell_screen.dart) (both branch web → desktop → mobile).

## Conventions

- Touch-first only: Scaffold + SafeArea + RefreshIndicator + LiquidGlassNavBar. No sidebar/hover/web-grid.
- Design tokens from common `lib/design/`: `app_tokens.dart` (`AppColors`, `AppLayout.pageHorizontal`, `AppRadius`, `AppMotion`, `AppGradients`, `AppShadows`), `app_decorations.dart` (`AppDecorations`), `app_typography.dart`. Never hardcode colors/radii/gradients.
- Naming split (same underlying colors): catalog widgets use `AppColors.primary`/`.accent` (cyan/orange); the reference-styled primitives use `AppColors.referencePrimary` (`primary` is just an alias of it). Match the surrounding file, don't mix aliases.
- Horizontal page padding is always `AppLayout.pageHorizontal` (22).
- Scroll lists: `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` in a `RefreshIndicator(color: AppColors.primary)` that `ref.invalidate()`s providers; pad bottom by `LiquidGlassNavBar.bottomInset` so content clears the floating bar.
- Strings via `AppLocalizations.of(context)` — non-nullable, no `!` needed (some web files still write `...!`). Keys like `l10n.navHome`, `l10n.homeSearchHint`, `l10n.sortTitleAz`.
- Data from Riverpod providers in common `lib/providers/` (`catalogProvider`, `genresProvider`, `featuredBooksProvider`, `lastOpenedBookProvider`, `sessionNotifierProvider`, `unreadNotificationCountProvider`, `catalogBookMetaProvider`). Widgets are Consumer*; they `ref.watch`/`ref.invalidate`, never fetch.
- Nav via go_router: `context.push('/book/${id}')`, shell tabs `context.go(tabs[index])`.
- No cover art exists — always render `BookCoverPoster` with a **stable index into the full list** so gradient assignment (`catalogBookGradient(index)`) survives filtering.
- Genre filter is dynamic via `genresProvider`; `null` = All; labels via `genreOptionLabel(context, g)` (honors Amharic `labelAm`).

## Commands

- `make reader-run-android` — run the reader on Android (repo root)
- `make reader-run-ios` — run the reader on iOS (repo root)

## Gotchas

- The cursor rule `reader-flutter-mobile-ui.mdc` is ASPIRATIONAL: it claims full shell/catalog/reader trees and Home/Settings/Profile tabs. Reality: only catalog/ + one screen migrated, shell/reader are empty, and real tabs are Home/Purchases/Profile. **Trust the code, not the rule.**
- Nav bar, `ShellPageScaffold`, auth layout, and all primitives STILL live in legacy `lib/widgets/` and are imported via `../../widgets/...`. Migrate into `lib/mobile/` when you touch them.
- Shell tabs are dynamic (in `main_shell_screen.dart`): `/home`, `/purchases`, `/profile`, plus `/admin/books` only when `user.canManageBooks` (icon/label switch on `user.isPlatformAdmin`). `_indexFor` maps `/downloads`→Home and `/settings`→Profile.
- Shell uses `extendBody: true` with nav `Positioned` at `bottom: LiquidGlassNavBar.bottomInset` — forget the bottom padding and content hides behind the bar.
- Auth chrome is chosen by `AdaptiveAuthLayout` (`web/widgets/shell/adaptive_auth_layout.dart`, mobile→`AuthScreenLayout`); login/register screens live in `lib/screens/` (legacy), not here.

## Never do

- Never import `lib/web/` or `lib/desktop/` into mobile UI. (Cross-platform branching happens only in `lib/screens/` route adapters, never in mobile widgets.)
- Never reimplement logic/models/providers/storage/l10n/shared tokens in mobile widgets — e.g. `validateEmail` lives in `lib/utils/auth_validators.dart`, not in a screen.
- Never hardcode strings, colors, radii, or gradients — use `AppLocalizations` and `lib/design/` tokens.
- Never add a second `AppGreetingCard` to a shell screen (one per screen max).
- Never render placeholder cover-image widgets expecting real artwork — use `BookCoverPoster` gradients.
- Never build a sidebar, hover card, or multi-column web grid — keep it touch-first (bottom nav, ≥48dp targets, bottom sheets).
- Never add brand-new UI to legacy `lib/widgets/`; new mobile UI goes in `lib/mobile/`.

## Related

- [Root CLAUDE.md](../../../../CLAUDE.md)
- [reader-flutter-mobile-ui.mdc](../../../../.cursor/rules/reader-flutter-mobile-ui.mdc) (aspirational — see Gotchas)
- [reader-flutter-common.mdc](../../../../.cursor/rules/reader-flutter-common.mdc)
