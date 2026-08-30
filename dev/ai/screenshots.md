# FinanzGecko — Regenerating the website screenshots

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

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
7. **Sync [structure.md](structure.md)** (`docs/assets/screenshots/` entry) if the naming scheme or the set of shots changes.
