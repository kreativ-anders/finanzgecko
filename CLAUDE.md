# FinanzGecko — Repo Instructions

[AI_MASTER.md](AI_MASTER.md) is the source of truth for architecture, tech stack, data flow, UI conventions, and
domain language. [gherkin/](gherkin/) holds the behavioral spec as Gherkin features. Read both before making any
non-trivial change, and follow the "Regeln für KI-Agenten" section at the bottom of AI_MASTER.md — in particular:
keep AI_MASTER.md and the relevant `gherkin/*.feature` in sync with any change to folder structure, architecture,
data models, or view behavior; never translate the German domain terms (Konto, Fixposten, Vermögenswerte, …); don't
revert a documented architecture decision (e.g. macOS keychain/sandbox settings, unencrypted rates cache) without
discussing it first.

## Working efficiently in this repo (for AI agents)

**Navigate, don't scan.** To change a behavior: find it in AI_MASTER **§8 Feature-Übersicht** → open that feature's
`# Quelle:` files → find its test via the §8 table or `grep "// Gherkin: <feature>"`. Edit only that narrow set.

**Regenerate a feature:** rewrite only its `# Implementierung:` file (the primary target named in the feature header)
against the feature's scenarios + its test; treat the other `# Quelle:` files (shared `app_state`/`app_store` facades)
as fixed context. See AI_MASTER "Regenerierung eines Features". Pure-logic (`@executable`) features are true 1:1.

**Keep the layering.** Pure, testable logic lives in `lib/utils/analysis.dart` and `lib/constants.dart`; views stay
thin. For new pure behavior, add a `Scenario` in `gherkin/executable/*.feature` + one `s.step(...)` in `test/bdd/`.

**Always verify:** run `flutter analyze` and `flutter test` after every change (the release gate runs the same, plus
the icon pipeline). The guard `test/gherkin_sync_test.dart` fails fast and points at exactly which spec/code/test link
broke — read its message before hunting.

**Keep docs in sync** (AI_MASTER.md + `gherkin/`) with every change, and don't revert a documented decision (see
AI_MASTER "Regeln für KI-Agenten") without asking.

## The website (`docs/`) — things no test covers

`docs/` is plain HTML/CSS with no build step and **no test suite**: `flutter test` never touches it, so every rule
here has to be checked by hand or by a throwaway script. The traps, in the order they tend to bite:

- **`docs/download.html` resolves release assets client-side.** The three cards ship with a static
  `.../releases/latest` link (the no-JS fallback) and a script rewrites each `href` to the concrete asset, matched
  by the `data-asset-suffix` attribute. **Those suffixes are coupled to the artifact names in
  `.github/workflows/release.yml`** — rename an artifact there and the page silently falls back to the release
  page with no visible error. Change both together. See AI_MASTER §6 for the full rationale.
- **Install instructions live in exactly one place:** the `#faq-install` entry in `docs/index.html`. The three
  download cards link to it cross-page; a small script on `index.html` force-opens a `<details>` addressed by
  fragment, because browsers don't do that reliably and the link would otherwise land on a collapsed line.
  Don't re-add per-card prose — it drifted out of sync with macOS's actual behaviour once already.
- **Every section follows the same two-level pattern:** `<section class="…">` carries the vertical padding, an
  inner `<div class="wrap">` the horizontal 24px and the 860px max-width. Never put `.wrap` and a section class on
  the *same* element — both set `padding`, the later rule in `style.css` wins, and the horizontal padding silently
  disappears. That bit `download.html` once: the card grid ran edge-to-edge on narrow windows while the hero above
  it was correctly inset. Nothing in CI catches this; check any new section at ~380px width by hand.
- **Every new third-party call or embed must be added to `docs/datenschutz.html`** (currently: Pirsch, GitHub
  Pages, the GitHub API on index + download, Stripe). The page is linked from all footers; a German site that
  loads something undisclosed is the one failure mode here with legal weight.
- **New page? Copy the whole `<head>` contract:** the Pirsch snippet (`api.pirsch.io/pa.js`, `id="pianjs"`), a
  `canonical` on `https://finanzgecko.app/…`, and either an entry in `docs/sitemap.xml` or `noindex`.
- **`docs/404.html` is the one page using root-absolute paths** (`/assets/…`). GitHub Pages serves it at whatever
  depth the bad URL had, so relative paths break it. Don't "fix" them to match the other pages.
- **`docs/CNAME` pins `finanzgecko.app`.** No absolute URL anywhere in the repo may point at
  `kreativ-anders.github.io` — that includes `README.md` and `_downloadPageUrl` in `lib/ui/views/settings_view.dart`.
- **Claims about the app's network access appear in four places** — `docs/index.html` (feature card),
  `docs/llms.txt`, `docs/datenschutz.html`, and AI_MASTER. The app makes exactly two calls: exchange rates
  (`api.frankfurter.dev`) and the manual update check (`api.github.com`). Keep all four in agreement.
- **The Stripe "after payment" redirect lives in Stripe's dashboard, not the repo**, and points at
  `https://finanzgecko.app/danke.html`. Nothing in CI will catch it after a domain or path change.

## Regenerating the website screenshots

`docs/` ships seven app screenshots, each in four files: `docs/assets/screenshots/{light,dark}-<slug>.{png,webp}`.
The pages serve both themes via `<picture>` + `media="(prefers-color-scheme: light)"`; **dark is the default and the
`<img>` fallback**, matching `style.css`, where `:root` holds the dark tokens and a `prefers-color-scheme: light`
block overrides them.

Redo them whenever app UI text, labels, or layout change — a stale screenshot contradicting the copy next to it is
worse than no screenshot. Ask before starting: this needs the user's running app and a few minutes of their machine.

1. **Demo data only.** The shots must show `demo/finanzgecko-demo.json` (74.191,40 €, E-Bike / MacBook Pro / VW Golf),
   imported via "Backup importieren…" — **never the user's real finances.** Confirm before capturing.
2. **Capture per theme.** `tool/capture_screenshots.sh dark`, then `light` (Einstellungen → Erscheinungsbild).
   The user runs it; it grabs the window at native Retina resolution → `build/screenshots/<theme>/`. Only fall back to
   computer-use screenshots if they prefer — those come back ~45% linear and JPEG-compressed, so say so first.
   Put the app fullscreen, move the cursor off the window before each shot (hover states), and restore theme +
   window state afterwards.
3. **The seven slugs** — the first three are one Dashboard scrolled to three positions; reuse identical scroll
   offsets across themes so the crops line up:

   | slug | where |
   | --- | --- |
   | `finanzgecko-gesamtvermoegen-verlauf-prognose` | Dashboard top: Gesamtvermögen + Verlauf/Prognose |
   | `finanzgecko-verteilung-nach-kontotyp-kennzahlen` | Dashboard: card row Verteilung / Fixposten / Vermögenswerte |
   | `finanzgecko-vermoegen-zusammensetzung-ueber-zeit` | Dashboard: Zusammensetzung über Zeit |
   | `finanzgecko-kontostaende-monatlich-erfassen` | Einträge |
   | `finanzgecko-fixposten-einnahmen-ausgaben` | Fixposten |
   | `finanzgecko-vermoegenswerte-sachwerte` | Vermögenswerte |
   | `finanzgecko-konten-uebersicht` | Konten |

4. **Crop to the centered content column** — no window chrome, no menu bar, and never the "Noch nie exportiert"
   banner. Use the *same* crop box for both themes so each pair is pixel-identical in size. Emit PNG + WebP
   (quality ~88).
5. **Update both pages.** `docs/index.html` (hero + 6 story blocks) and `docs/documentation.html` (7) — the `<picture>`
   blocks are structurally identical, so a regex pass over both is safer than hand-editing 14 of them. `width`/
   `height` on the `<img>` must match the new crops or the page reflows on load.
6. **Verify before declaring done:** every referenced asset exists, no orphans, light/dark pairs share dimensions, and
   HTML `width`/`height` equal the real files. Best check is rendering `index.html` + `documentation.html` headless
   under both `color_scheme`s and asserting each `img.currentSrc` starts with the expected theme prefix — that is what
   catches a broken media query, which eyeballing does not.
7. **Sync AI_MASTER.md** (`docs/assets/screenshots/` entry) if the naming scheme or the set of shots changes.

@AI_MASTER.md
