# Reader Flutter Design System

## Token Source

- `lib/design/app_tokens.dart`

This file defines reusable visual tokens:
- `AppColors`
- `AppSpace`
- `AppRadius`
- `AppMotion`

## Theme Mapping

Theme is mapped in:
- `lib/app.dart`

Mapped areas:
- Color roles (`background`, `surface*`, `outlineVariant`, `primary`)
- Component themes (`NavigationBar`, `Card`, `Chip`, `InputDecoration`)
- Typography defaults (`TextTheme` body/title styles)

## Shared Components

- `lib/widgets/app_section_card.dart`
  - Standard section container for hero/profile/dashboard blocks
  - Uses tokenized background, border, radius, and spacing

## UI Consistency Rules

- Main screen background stays white.
- Secondary surfaces use the light-blue token family.
- All new spacing should use `AppSpace`.
- All rounded corners should use `AppRadius`.
- New animations should use `AppMotion` durations.
