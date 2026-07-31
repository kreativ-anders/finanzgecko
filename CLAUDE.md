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
