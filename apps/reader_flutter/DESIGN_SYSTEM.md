# Ethiopian Reader — Design System

Visual system aligned with the v2 mobile kit in `Mobileapp ui design/ui_kits/mobile/components-v2.jsx`, using Ethiopian brand tokens.

## Token source

| File | Purpose |
| --- | --- |
| `lib/design/app_tokens.dart` | Colors, spacing, radius, motion, shadows |
| `lib/design/app_decorations.dart` | Card recipes (`panel`, `listRow`, `greeting`) |
| `lib/design/app_typography.dart` | DM Sans (UI chrome) via `google_fonts` |
| `lib/design/reader_typography.dart` | Noto Serif Ethiopic (reader body) |
| `lib/design/app_theme.dart` | `ThemeData` in `lib/app.dart` |

## Primitives (`lib/widgets/primitives/`)

| Widget | Use |
| --- | --- |
| `shell_primitives.dart` | Greeting, metrics, stats, action rail, panels, segmented control, library header |
| `shared_widgets.dart` | Detail rows, errors, logo tile, text fields, list rows, sub-page scaffold |
| `auth_screen_layout.dart` | Login / register |
| `menu_button.dart` | Drawer menu button |

## UI modes

1. **Shell / catalog** — parchment `#FAF7F2`, white cards, one inset `AppGreetingCard` per screen max.
2. **Reader** — immersive chrome; Noto Ethiopic body; light / dark / sepia unchanged functionally.

## Rules

- Use `AppSpace` / `AppRadius` for new UI.
- Prefer `AppPanel`, `AppListRow`, `AppStatTile` over ad-hoc `BoxDecoration`.
- No full-bleed `AppGradients.hero` on list/hub surfaces (splash + auth greeting only).
- Book placeholders: `AppBookCover`.
- All strings via `lib/l10n/`.

## Removed legacy widgets

`HomeHeroHeader`, `PageHeaderBox`, `SummaryHubCard` — replaced by primitives above.
