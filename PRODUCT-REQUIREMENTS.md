# Felege metsahft Product Requirements

This document consolidates the product, UX, and implementation requirements into one execution-focused spec for the reader app.

## 1) Product Goal

Deliver a world-class, reading-first mobile experience for Ethiopian religious books that is calm, trustworthy, accessible, and resilient offline.

## 2) Scope

### MVP (in scope now)
- Authentication: register, login, logout, session restore.
- Library discovery: featured rails, categories, search, filtering.
- Book detail: metadata, download action, clear states.
- Reader shell: immersive reading mode, TOC, bookmarks, progress.
- Account: profile dashboard, storage/security context, sign-out.
- Offline-first catalog behavior: ETag-aware fetch with local cache fallback.
- Download reliability baseline: persisted download metadata, resumable-retry foundation.

### Post-MVP (next phases)
- Full Drift local DB + outbox sync engine.
- Controlled text-to-speech accessibility mode.
- Advanced personalization (continue reading across devices, recommendations).
- Rich publisher analytics and audit exports.

## 3) Experience Requirements

- Reverence: clean, non-gamified visual system and respectful copy.
- Focus: reading UI minimizes chrome and distractions.
- Trust: transparent states for offline/download/security constraints.
- Clarity: users always know reading position and how to navigate.
- Inclusion: readable typography and contrast with accessibility support.

## 4) Functional Requirements

### Library and Discovery
- Show category rails and featured books.
- Support metadata search (title, author, subtitle, summary).
- Support language/category filtering.
- Show empty/loading/error/offline states with retry controls.

### Reader
- Dedicated reader route with independent shell.
- Auto-hide chrome after inactivity.
- Top controls: back, title, TOC, bookmark toggle.
- Progress indicator and persisted read position.
- Persist reader settings (theme/font size).

### Download and Offline
- Persist catalog payload and ETag locally for startup/offline usage.
- Use `If-None-Match` when syncing catalog.
- Persist download metadata for visibility/recovery.
- Provide actionable download error messaging.

## 5) Non-Functional Requirements

- UX performance: smooth scrolling and responsive interactions.
- Reliability: downloaded books open offline.
- Accessibility: adequate contrast and semantic labels.
- Consistency: tokenized spacing, radius, colors, typography.

## 6) Acceptance Criteria

- First read journey (open -> read -> leave -> resume) succeeds in usability tests.
- Theme and font changes apply instantly without losing location.
- TOC is reachable within two taps from reader.
- Library remains usable when backend is unreachable and cache exists.
- Core screens pass lint/analyze and basic widget/regression tests.

## 7) Release Gates

- Product sign-off on core journeys.
- Design sign-off on tokenized UI consistency.
- Engineering sign-off on reader, cache, and download resilience.
- QA sign-off on checklist in `QA-GATES.md`.
