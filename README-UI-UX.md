# Ethiopian Religious Books — UI/UX Requirements

**Document version:** 1.0  
**Companion:** [Functional requirements & data model](README.md) · [Implementation plan](README-IMPLEMENTATION.md) · [Local setup](SETUP.md)  
**Audience:** Product, design, mobile engineering, content publishers  

This document defines **visual design, interaction, accessibility, and content presentation** standards for a **world-class religious book reader**. It is informed by mainstream reading-app patterns, accessibility specifications (including the [DAISY Reading Apps User Requirements](https://daisy.github.io/reading-apps-ux-reqs/requirements/published/FINAL-20251031/)), WCAG-oriented contrast and typography guidance, and product judgment appropriate to **sacred, long-form reading** in **Ethiopic script** and companion languages.

---

## 1. Product experience vision

### 1.1 Experience pillars


| Pillar        | User perception                                            | Design implication                                                |
| ------------- | ---------------------------------------------------------- | ----------------------------------------------------------------- |
| **Reverence** | The app feels calm, dignified, not “gamified” or noisy     | Restrained color, subtle motion, no gratuitous badges or streaks  |
| **Focus**     | Reading is the hero; chrome disappears when not needed     | Immersive reader, minimal persistent UI, generous margins         |
| **Trust**     | Users understand protection rules without feeling punished | Clear, compassionate copy; predictable settings; no dark patterns |
| **Clarity**   | Users always know where they are in a long work            | TOC sync, progress, chapter context, orientation affordances      |
| **Inclusion** | Low vision and older adults can read comfortably           | Type scale, contrast themes, reduced motion, sensible tap targets |


### 1.2 Non-goals (UX)

- Maximizing “daily active” through addictive patterns (streaks, aggressive push).
- Visual trends that sacrifice legibility (ultra-thin weights, low-contrast gray-on-gray).
- Cluttered library chrome that competes with book covers and titles.

---

## 2. Research and standards (what “world class” is anchored to)

Use these as **design inputs**; formal legal compliance is out of scope for this doc.

1. **[DAISY Reading Apps User Requirements](https://daisy.github.io/reading-apps-ux-reqs/requirements/published/FINAL-20251031/)** — MoSCoW-prioritized expectations for navigation (TOC, back/forward, restore last position, know your place), visual adjustments, bookmarks, and reading system behavior. Map applicable **Must-haves** to **REQ-UX** items below where they do not conflict with MVP DRM (e.g. no text selection).
2. **WCAG 2.2 orientation** — Perceivable text: target **≥ 4.5:1** contrast for body copy on default themes; **≥ 3:1** for large text and key UI chrome. Provide a **high-contrast** theme that exceeds defaults.
3. **Mobile typography practice** — Long-form body: **minimum ~16sp** equivalent; many readers prefer **17–20sp**; line height **1.5–1.8×** font size; comfortable line length **~50–75 characters** where layout allows (often achieved via margins + reflow).
4. **E-reader ergonomics** — Users expect **hideable chrome**, **tap edges** or **swipes** for navigation (when paginated), **consistent night mode** (avoid “dazzling” white flashes when opening images or sheets—see KOReader community findings on night mode and image surfaces).

### 2.1 Conflict: accessibility vs. content protection

Functional spec disallows **selection, copy, and share** for book text (**REQ-R-036**). That limits some assistive workflows.

**REQ-UX-A11Y-001 (policy):** Define an explicit **accessibility stance**:

- **MVP default:** Full **VoiceOver / TalkBack** labels for **chrome** (navigation, buttons, TOC rows, book titles). For **book body**, expose **structural** information (chapter title, approximate progress) via announcements where the platform allows **without** selectable text.
- **Post-MVP:** Re-evaluate **controlled** recitation (publisher-approved TTS inside the app) under the same security model as reading.

Document this stance in the in-app **FAQ** and support macros.

---

## 3. Information architecture (reader app)

### 3.1 Primary navigation (suggested MVP structure)

Use **bottom navigation** or a **single home hub** with 3–4 top-level areas:

1. **Library** — catalog, continue reading, downloads.
2. **Search** — metadata search (MVP).
3. **Account** — profile, language, storage, legal, support, logout.

**Deep rule:** Opening a **book** enters the **Reader** shell (full screen / own back stack) so reading is never “just another tab.”

### 3.2 Navigation depth


| Level | Screens                   |
| ----- | ------------------------- |
| 0     | Splash / session restore  |
| 1     | Onboarding → Legal → Auth |
| 2     | Library home              |
| 3     | Book detail               |
| 4     | Reader                    |


**REQ-UX-NAV-001:** From Reader, user reaches Library with **at most one** intentional exit action (back or close) after dismissing transient sheets.

---

## 4. Screen-by-screen UX requirements

### 4.1 Splash and session restore

**REQ-UX-SPL-001:** Cold start shows **branded minimal splash** (< 2s perceived); resume last route when session valid.

**REQ-UX-SPL-002:** If token refresh fails, route to login with **non-alarming** copy (“Please sign in again”) and preserve **local** downloads.

### 4.2 Language selection (first launch)

**REQ-UX-LANG-001:** Show **native script endonyms** + Latin transliteration where helpful (e.g. አማርኛ · Amharic).

**REQ-UX-LANG-002:** Default language: device locale if supported, else English.

### 4.3 Legal acceptance

**REQ-UX-LEG-001:** Single scrollable summary with **links** to full Terms and Privacy (in-app WebView or external browser—pick one consistently).

**REQ-UX-LEG-002:** Primary button **Accept**; secondary **Learn more**; no pre-checked sneaky boxes.

**REQ-UX-LEG-003:** Short **plain-language** bullets: what data you collect, that screenshots may be limited on Android, that another camera can still photograph the screen.

### 4.4 Authentication

**REQ-UX-AUTH-001:** Email field uses appropriate keyboard; show **inline validation** (format) not only on submit.

**REQ-UX-AUTH-002:** Password field: visible **show/hide** toggle; support password managers (Autofill).

**REQ-UX-AUTH-003:** Errors: **specific but safe** (“No account for this email” vs generic—product choice for enumeration).

**REQ-UX-AUTH-004:** Forgot password: frictionless **single-purpose** flow with countdown/expiry messaging.

### 4.5 Library home

**REQ-UX-LIB-001:** **Continue reading** card: cover thumbnail (or placeholder), title, **chapter** + **percent** (or “Near the beginning”), **Resume** CTA.

**REQ-UX-LIB-002:** Book list: **large touch targets** (min **44×44 pt** effective), cover **2:3** aspect, title **2 lines max** with ellipsis, metadata line (author, language).

**REQ-UX-LIB-003:** States: **loading skeletons**, **empty** (“No books yet” + pull to refresh), **offline** banner when catalog stale.

**REQ-UX-LIB-004:** **Update available** badge on book row when `revision` > local; tap explains “New edition from publisher” with **Update** / **Later**.

### 4.6 Book detail

**REQ-UX-DET-001:** Hero: cover, title, author/compiler, language/script chips.

**REQ-UX-DET-002:** Summary: collapsible if long (“Read more”) to avoid endless scroll before actions.

**REQ-UX-DET-003:** **Download** primary when not local; show **size** and **Wi‑Fi only** lock icon when setting enabled.

**REQ-UX-DET-004:** **Delete from device** in overflow menu with **confirm** dialog (destructive styling).

**REQ-UX-DET-005:** If unpublished server-side but still local: show **muted** state and **Open disabled** with explanation (**REQ-R-060**).

### 4.7 Download UX

**REQ-UX-DL-001:** Progress: **determinate** progress bar, **Mbps** optional, **Cancel** (with confirm if mid-write).

**REQ-UX-DL-002:** Retry: **single-tap** retry after failure; show **actionable** reason (network, storage, server).

**REQ-UX-DL-003:** Background download: **system-consistent** notification on Android when applicable.

### 4.8 Reader — layout and chrome

**REQ-UX-RDR-001:** **Immersive default:** hide top/bottom chrome after **2–3s** idle; **tap center** toggles chrome visibility (discoverability: brief first-time hint).

**REQ-UX-RDR-002:** **Top bar:** back, book title (truncated), overflow (TOC, bookmarks, settings for this book).

**REQ-UX-RDR-003:** **Bottom bar (optional):** font size **− / +**, theme cycle, bookmark toggle.

**REQ-UX-RDR-004:** **Safe areas** respected; no critical controls in display cutouts.

**REQ-UX-RDR-005:** **Orientation:** support portrait; landscape **nice-to-have** MVP (if deferred, do not break layout).

### 4.9 Reader — typography and themes

**REQ-UX-TYP-001:** Provide **at least one** high-quality **Ethiopic** family (e.g. **Noto Sans Ethiopic** or equivalent with proper marks); fallbacks tested on Ge’ez/Amharic strings.

**REQ-UX-TYP-002:** **Font size** in **discrete steps** (e.g. 7 steps) from **~15sp** to **~28sp** body equivalent; persist per user globally with optional per-book override (post-MVP if costly).

**REQ-UX-TYP-003:** **Line height** scales with size; never go below **1.45×** for body.

**REQ-UX-TYP-004:** **Themes:** **Light** (warm paper optional), **Dark** (prefer **#121212**–**#1C1C1E** backgrounds, **not pure #000** for large fields of text), **Sepia** (low blue, warm paper).

**REQ-UX-TYP-005:** **Images** in content: in dark theme, **dim surrounding chrome**; avoid flashing white modals over dark reader (KOReader-class issue).

**REQ-UX-TYP-006:** **Hyphenation / justification:** default **ragged right** for complex scripts unless proven safe; if justified, enable hyphenation rules appropriate to language (may be limited for Ethiopic—test).

### 4.10 Reader — navigation inside book

Aligned with DAISY **Must-haves** where applicable:

**REQ-UX-NAV-002:** **TOC** opens as **modal sheet** or full screen; **current chapter** highlighted / scrolled into view.

**REQ-UX-NAV-003:** **Forward/back** within book: if **scroll** mode: preserve **velocity-friendly** scrolling; optional **volume-key** page scroll (Android, user setting, off by default).

**REQ-UX-NAV-004:** **Progress:** always available from chrome: **%** + chapter name (DAISY: user must know place).

**REQ-UX-NAV-005:** After internal jump (footnote target MVP if present), **Back** returns to prior anchor (DAISY “go back”).

### 4.11 Bookmarks (MVP local)

**REQ-UX-BMK-001:** Add bookmark: **haptic light** + **toast** “Saved” (non-intrusive).

**REQ-UX-BMK-002:** Bookmarks list: chapter, **snippet preview** if allowed without exposing selectable text (e.g. fixed non-selectable label generated at save time).

**REQ-UX-BMK-003:** Delete bookmark: swipe or overflow; **undo** snackbar **5s** when feasible.

### 4.12 Search (metadata)

**REQ-UX-SRH-001:** Recent queries (optional); **clear** control.

**REQ-UX-SRH-002:** Empty state suggestions (“Try author name”, “Try language tag”).

**REQ-UX-SRH-003:** Results show **match context** in title/author/tag.

### 4.13 Account, storage, settings

**REQ-UX-SET-001:** **Storage** screen: per-book size, total used, **free space** warning threshold explanation.

**REQ-UX-SET-002:** **Wi‑Fi only downloads** toggle with short rationale.

**REQ-UX-SET-003:** **Security** subsection: explain screenshot limitation, clipboard lock, and **what cannot be prevented** (camera) — matches **REQ-SEC-001**.

### 4.14 FAQ and support

**REQ-UX-SUP-001:** FAQ: **accordion** sections, searchable (post-MVP if needed).

**REQ-UX-SUP-002:** Support CTA always visible from Account.

---

## 5. Interaction design system

### 5.1 Touch targets and spacing

**REQ-UX-INT-001:** Minimum **44×44 dp/pt** for tappable controls; **8dp** between adjacent destructive actions.

**REQ-UX-INT-002:** **Hit slop** on small icons (overflow, bookmark).

### 5.2 Gestures

**REQ-UX-GES-001:** Reader **tap zones** (if paginated later): optional **left/right** third for prev/next page; **center** toggle chrome.

**REQ-UX-GES-002:** **Pull-to-refresh** on library.

**REQ-UX-GES-003:** **System back** on Android: from reader, returns to book detail or library consistent with stack; **confirm** if mid-download cancel is risky.

### 5.3 Motion

**REQ-UX-MOT-001:** Respect **OS “reduce motion”**: replace large parallax with **cross-fade**; no auto-playing decorative motion.

**REQ-UX-MOT-002:** Page/scroll transitions **≤ 200–300ms**, **ease-out**.

### 5.4 Haptics

**REQ-UX-HAP-001:** Light impact for bookmark saved; **no** haptics on every scroll tick.

---

## 6. Visual design tokens (implementation-ready baseline)

Designers should translate these into Figma tokens; engineering into theme resources.

### 6.1 Spacing scale (4dp grid)

4, 8, 12, 16, 20, 24, 32, 40, 48.

### 6.2 Corner radii

- Cards: **12dp**
- Sheets/modals: **16dp** top corners
- Buttons: **10–12dp** (pill optional for primary)

### 6.3 Elevation / borders

- Resting cards: **1dp** shadow or **1dp** hairline border **#00000014** (light) / **#FFFFFF22** (dark)
- Reader chrome: **no** heavy shadow; use **blur / scrim** **40–60%** when overlaying text (if used)

### 6.4 Iconography

**REQ-UX-ICO-001:** **Outlined** icons at **24dp** default; **filled** for active tab.

**REQ-UX-ICO-002:** Prefer **semantic** icons: book, bookmark ribbon, TOC list, download arrow.

### 6.5 Color roles (semantic)

Define tokens: `color.background`, `color.surface`, `color.surfaceElevated`, `color.textPrimary`, `color.textSecondary`, `color.textDisabled`, `color.accent`, `color.accentText`, `color.danger`, `color.success`, `color.divider`.

**REQ-UX-COL-001:** **Accent** use sparingly—religious reading apps benefit from **muted** accents (deep gold, olive, slate blue), not neon.

---

## 7. State design (non-happy paths)

**REQ-UX-ST-001:** **Network:** illustrations optional; always **primary action** (Retry) + **secondary** (Offline help).

**REQ-UX-ST-002:** **Permission:** if any (notifications later), explain **why** before system dialog.

**REQ-UX-ST-003:** **Server maintenance:** banner with **time** if known.

**REQ-UX-ST-004:** **Corrupt local package:** offer **Repair** (re-download) and **diagnostics** code for support.

---

## 8. Content design (microcopy)

**REQ-UX-COPY-001:** **Tone:** calm, respectful, second person (“You can read offline after downloading”).

**REQ-UX-COPY-002:** **Avoid shame** for security features (“Content is protected” not “You are not allowed”).

**REQ-UX-COPY-003:** **Ethiopian names and titles:** preserve **orthography**; do not auto-title-case Ethiopic.

---

## 9. Web admin UI/UX (publisher console)

**REQ-UX-ADM-001:** **Data-dense** but **readable** tables: books, status (`draft` / `published`), last updated, revision.

**REQ-UX-ADM-002:** **Upload wizard** with **steps**: metadata → structure → files → validate → publish.

**REQ-UX-ADM-003:** **Validation errors** reference **manifest paths** and **line numbers** where possible.

**REQ-UX-ADM-004:** **Destructive** actions (unpublish, delete revision) require **typed confirm** or **modal** with consequences.

**REQ-UX-ADM-005:** **Audit log** filters: actor, entity, date range, CSV export (post-MVP optional).

---

## 10. Benchmarks (learn, do not clone)

Use as **pattern references**:

- **Kindle / Apple Books:** library grid density, reading chrome auto-hide, font controls.
- **Google Play Books:** download/offline clarity.
- **Lithium / ReadEra (FOSS):** minimalist reader chrome.

**REQ-UX-BEN-001:** Quarterly **heuristic review** against DAISY Must-haves applicable to your DRM stance.

---

## 11. UX acceptance criteria (MVP)


| ID             | Criterion                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| REQ-UX-ACC-001 | User completes **first read session** (open book → scroll 2 screens → leave → resume) without assistance in usability tests (target **≥85%** success). |
| REQ-UX-ACC-002 | **Font size** change applies instantly without losing position.                                                                                        |
| REQ-UX-ACC-003 | **Theme** change does not reset scroll position.                                                                                                       |
| REQ-UX-ACC-004 | **TOC** opens in **≤2 taps** from reader.                                                                                                              |
| REQ-UX-ACC-005 | **WCAG** contrast met on **Light** and **Dark** for body and primary buttons.                                                                          |
| REQ-UX-ACC-006 | TalkBack/VO can complete **library navigation** and **open downloaded book**; body policy per **REQ-UX-A11Y-001**.                                     |


---

## 12. Deliverables checklist (design team)

1. **Figma** design system: color, type, components, reader states.
2. **Interactive prototype:** onboarding → download → read → TOC → bookmark.
3. **Content guidelines** for publishers (cover aspect ratio, title length, chapter naming).
4. **Accessibility note** for QA: DRM exceptions documented.

---

## 13. Revision history


| Version | Date       | Notes                                            |
| ------- | ---------- | ------------------------------------------------ |
| 1.0     | 2026-03-21 | Initial UI/UX requirements aligned to README MVP |


