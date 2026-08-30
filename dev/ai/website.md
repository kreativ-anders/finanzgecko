# FinanzGecko — The website (`docs/`) — traps no test covers

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

`docs/` is plain HTML/CSS with no build step. Most rules here must be checked by hand — but the ones that are
mechanically decidable are now enforced by **`test/docs_consistency_test.dart`**, which runs inside
`flutter test`: the asset-suffix coupling, the disclosed network endpoints, the documented data path, banned
signing jargon in user-facing text, and specific claims that were once false and must not return.

**When a rule below bites again, convert it into a test there instead of only fixing the prose.** That file exists
because the README claimed "unsigned builds trigger Gatekeeper warnings" for weeks after it stopped being true:
prose about behaviour rots like code, but nothing compiles it.

The traps, in the order they tend to bite (⚙ = already enforced by the test):

- ⚙ **`docs/download.html` resolves release assets client-side.** The three cards ship with a static
  `.../releases/latest` link (the no-JS fallback) and a script rewrites each `href` to the concrete asset, matched
  by the `data-asset-suffix` attribute. **Those suffixes are coupled to the artifact names in
  `.github/workflows/release.yml`** — rename an artifact there and the page silently falls back to the release
  page with no visible error. Change both together. See [platform.md](platform.md) for the full rationale.
- **Install instructions live in exactly one place:** the `#faq-install` entry in `docs/index.html`. The three
  download cards link to it cross-page; a small script on `index.html` force-opens a `<details>` addressed by
  fragment, because browsers don't do that reliably and the link would otherwise land on a collapsed line.
  Don't re-add per-card prose — it drifted out of sync with macOS's actual behaviour once already.
- **Every section follows the same two-level pattern:** `<section class="…">` carries the vertical padding, an
  inner `<div class="wrap">` the horizontal 24px and the 860px max-width. Never put `.wrap` and a section class on
  the *same* element — both set `padding`, the later rule in `style.css` wins, and the horizontal padding silently
  disappears. That bit `download.html` once: the card grid ran edge-to-edge on narrow windows while the hero above
  it was correctly inset. Nothing in CI catches this; check any new section at ~380px width by hand.
- **There is exactly one breakpoint, `@media (max-width: 700px)` at the bottom of `style.css`, and all
  mobile-specific rules belong in it.** Scattering per-rule media queries next to their base rules is what let
  every section except `.hero` keep its full desktop vertical padding on phones. A new section with vertical
  padding, a heading size, or a fixed-column grid needs a matching entry there. Desktop paddings are deliberately
  *not* uniform (the hero breathes more than the trust strip); the breakpoint compresses that scale, it doesn't
  flatten it — so use explicit per-section values, not one shared token.
- ⚙ **Every new third-party call or embed must be added to Teil A of `docs/datenschutz.html` and Part A of
  `docs/privacy.html`** (currently: Pirsch, GitHub Pages, the GitHub API on index + download, Stripe). The German
  page is linked from all footers; a site that loads something undisclosed is the one failure mode here with
  legal weight.
- **New page? Copy the whole `<head>` contract:** the Pirsch snippet (`api.pirsch.io/pa.js`, `id="pianjs"`), a
  `canonical` on `https://finanzgecko.app/…`, and either an entry in `docs/sitemap.xml` or `noindex`.
- **`docs/404.html` is the one page using root-absolute paths** (`/assets/…`). GitHub Pages serves it at whatever
  depth the bad URL had, so relative paths break it. Don't "fix" them to match the other pages.
- **`docs/CNAME` pins `finanzgecko.app`.** No absolute URL anywhere in the repo may point at
  `kreativ-anders.github.io` — that includes `README.md` and `_downloadPageUrl` in `lib/ui/views/settings_view.dart`.
- ⚙ **Claims about the app's network access appear in five places** — `docs/index.html` (feature card),
  `docs/llms.txt`, `docs/datenschutz.html`, `docs/privacy.html`, and [stack.md](stack.md). The app makes exactly two
  calls: exchange rates (`api.frankfurter.dev`) and the manual update check (`api.github.com`). Keep all five in
  agreement.
- ⚙ **One privacy policy per language, split into two parts inside the page** — `docs/datenschutz.html` (German)
  and `docs/privacy.html` (its full English equivalent, the only deliberately English page under `docs/`).
  **Teil A / Part A** is the website (hosting, Pirsch, GitHub API, Stripe), **Teil B / Part B** is the app
  (what data, where it lives, what leaves the device, what the user controls); the `A1…A5` / `B1…B4` anchors are
  cross-linked, so don't renumber them casually. **Teil B stays non-technical:** "AES-verschlüsselt" is the whole
  encryption statement — no cipher modes, KDF iterations, credential-store product names, file paths or
  permission bits. That belongs in the code, not in a privacy policy (Manuel, 2026-08-29). Both pages are
  `PrivacyUrl` targets in the winget manifests — the two paths must keep working. A new third-party embed goes
  into Part A of **both**; a change to what the app does goes into Part B of **both**, in the same commit.
- **The Stripe "after payment" redirect lives in Stripe's dashboard, not the repo**, and points at
  `https://finanzgecko.app/danke.html`. Nothing in CI will catch it after a domain or path change.
