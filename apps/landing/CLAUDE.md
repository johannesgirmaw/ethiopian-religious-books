# Marketing landing (`apps/landing/`) — Next.js 14 App Router **static export** for felegemetsahft.com

Home + `/download` marketing pages only. Tailwind dark theme, client-side en/am i18n.
This is a pure static site: **no server runtime, no API routes, no data fetching, no app product logic.**

## Layout

| Path | Purpose |
| --- | --- |
| [`next.config.mjs`](next.config.mjs) | `output:'export'`, `images.unoptimized:true`, `trailingSlash:true`. Emits to `out/`. |
| [`src/app/layout.tsx`](src/app/layout.tsx) | Root: Metadata + OpenGraph, `next/font/google` (Inter=`--font-sans`, Fraunces=`--font-display`, Noto_Sans_Ethiopic=`--font-ethiopic`), JSON-LD, wraps in `<LanguageProvider>`. `html lang="en"` hard-coded (updated client-side by the provider). |
| `src/app/page.tsx` | Home: Header, Hero, Features, Platforms, CTA, Footer. |
| `src/app/download/page.tsx` | `/download`: server component w/ Metadata → `<DownloadPageBody>`. |
| `src/app/robots.ts`, `sitemap.ts` | Metadata routes, both `dynamic='force-static'`. Sitemap lists `/` and `/download/` only. |
| `src/app/globals.css` | Tailwind + shared classes: `.container-px .glass .btn/.btn-primary/.btn-ghost .eyebrow .gold-text`. Dark-only (`color-scheme:dark`, `bg-ink-900`). |
| [`src/config/site.ts`](src/config/site.ts) | **Single source of truth** for `site` URLs + exported `platforms[]`. Edit download links here. |
| `src/i18n/translations.ts` | `Dict` type + `dict` Record<'en'\|'am'>. **All copy lives here.** |
| `src/i18n/LanguageProvider.tsx` | `'use client'` context; `useLang()` → `{lang,setLang,toggle,t}`; persists to localStorage `fm-lang`; also exports `fill()` for `{token}` interpolation. |
| `src/components/*` | Interactive UI, each `'use client'`. `icons.tsx` is a plain (non-client) SVG module (`Logo`, `platformIcon` map…). |
| `src/components/PrimaryDownload.tsx` | Client UA-sniff `detect()` picks hero download platform; iOS→`macos`; falls back to `/download`. |

## Conventions

- **Static-render everything**: no `getServerSideProps`, no route handlers, no server components that fetch, no runtime env reads. Metadata routes set `dynamic='force-static'`.
- Import alias `@/*` → `./src/*` ([tsconfig.json](tsconfig.json)). Use `@/config/site`, `@/i18n/...`, `@/components/...`.
- Every interactive component starts with `'use client'` — whole site is client-rendered under a static shell. `useLang()` must be called inside `<LanguageProvider>` or it throws.
- Never hard-code copy in components: pull from `t` (`useLang`) and add matching `en` + `am` entries in `translations.ts`, extending the `Dict` type first. OS names (Android/macOS/Windows/Linux) stay untranslated.
- Colors from Tailwind theme in [`tailwind.config.ts`](tailwind.config.ts) mirroring Flutter tokens: `brand.*` (cyan, `brand-400` #29b6e0), `gold.*` (orange, `gold-500` #f5a623), `ink.*` (dark ramp). Use these + shared globals.css classes, never raw hex.
- Fonts are CSS vars on `<html>`; reference via Tailwind `font-sans`/`font-display` (both fall back to the Ethiopic var).
- Centralize download URLs + platform metadata in `config/site.ts` `platforms[]` — env-overridable via `NEXT_PUBLIC_*_URL`. Filenames must match uploads: `felege-metsahft.apk`, `felege-metsahft-setup.exe`, `felege-metsahft-macos.dmg`, `felege-metsahft-linux-x64.tar.gz`.
- Login/register are plain `<a href={site.login}>` to Flutter web hash routes — keep the `/#/` prefix.

## Commands

| Command | Note |
| --- | --- |
| `npm run dev` | Local dev server (`next dev`). |
| `npm run build` | `next build` → static export into `out/` (git-ignored). |
| `npm run lint` | `next lint`. |
| `scripts/deploy-prod.sh landing` | From repo root: `npm install` + build + rsync `out/` (`--delete`) → VPS + 200 health check. Only way to ship. |

## Gotchas

- Build output is `out/` (not `.next`) because of `output:'export'`; deploy rsyncs `out/` with `--delete`. Never point Nginx/deploy at `.next`.
- `trailingSlash:true` → emitted/canonical paths carry the slash (`/download/`). Internal `<Link href='/download'>` still works.
- `images.unoptimized:true` is mandatory — no `next/image` optimization or remote loaders.
- Language is client-only: exported HTML is always `en`; `am` applies after hydration from localStorage/navigator. Do not rely on server-side locale.
- `PrimaryDownload` maps iOS UA → `macos` intentionally (no iOS build yet).
- Installer files are uploaded separately via `scripts/deploy-prod.sh downloads` (no `--delete`) BEFORE landing deploy; the Windows `.exe` builds in GitHub Actions (see root CLAUDE.md). Landing only references filenames.

## Never do

- Never add server-side features (route handlers, server actions, SSR data fetching, middleware, runtime env vars) — `output:'export'` fails the build or drops them silently.
- Never hand-run rsync/ssh or deploy `out/` manually — use `scripts/deploy-prod.sh landing`.
- Never remove the `/#/` hash prefix from `site.login`/`register` or change the app origin without confirming Flutter web hash routing.
- Never hard-code copy or new hex colors in components — add to `translations.ts` (both en+am) and use `brand`/`gold`/`ink` tokens + globals.css classes.
- Never rename an installer link in `config/site.ts` without matching the actual uploaded filename, or the button 404s.
- Never re-document VPS/Nginx/API/CORS/Windows-build mechanics here — the root CLAUDE.md owns them.

## Related

- [Root CLAUDE.md](../../CLAUDE.md) — monorepo map, production deploy safety, platform map, Windows build flow.
