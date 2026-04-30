# QA Gates

This checklist is the release quality contract for the reader app.

## 1) Accessibility Gates

- [ ] Light and dark themes satisfy text contrast requirements for body and primary CTA.
- [ ] All primary controls have semantic labels and are reachable by screen reader.
- [ ] Font size controls in reader update content without layout breakage.
- [ ] Reader can be used without gesture precision (buttons remain tappable at >=44dp).

## 2) Performance Gates

- [ ] Warm start reaches interactive home in target budget (<2s on reference device).
- [ ] Home/library scroll remains smooth during list/rail interactions.
- [ ] Reader scroll remains smooth with chrome hidden and visible.
- [ ] Search/filter operations complete without visible UI jank on normal catalog size.

## 3) Reliability Gates

- [ ] Cached catalog loads when network is unavailable.
- [ ] Catalog ETag flow handles 304 and 200 updates without crashes.
- [ ] Download failure stores failed status and surfaces actionable message.
- [ ] Reader progress/bookmarks persist after app restart.

## 4) Automated Verification

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Django critical endpoint smoke checks pass (`/v1/books`, `/v1/sync/catalog`).

## 5) Manual Test Matrix (Core Flows)

- [ ] Register -> Login -> Home -> Book detail -> Reader -> Resume.
- [ ] Offline launch with pre-cached catalog.
- [ ] Download success and failed download retry scenario.
- [ ] Reader settings change (font/theme) persists per book.
