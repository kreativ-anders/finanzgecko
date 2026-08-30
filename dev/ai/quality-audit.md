# FinanzGecko — Quality audit (recurring task)

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

There's deliberately **no** automated CI step for this (no push/PR workflow, see [platform.md](platform.md)) — this audit is a
**manually/on-demand triggered** task for an AI, useful e.g. before a bigger release or whenever it hasn't run in
a while. The goal is a **findings report**, not automatic breaking changes — implementing concrete fixes is a
separate step, agreed with the human afterward.

Three sub-areas, each with a clear scope:

1. **Usability & accessibility of the UI** — both the Flutter desktop app (`lib/ui/views/`, `lib/ui/widgets/`,
   `lib/ui/theme.dart`) and the landing page (`docs/index.html`, `docs/download.html`,
   `docs/documentation.html`, `docs/danke.html`, `docs/assets/style.css`). Checkpoints include: contrast (see the
   `kPrimaryText`/`kDangerText`/`kWarningText` rule in [design-tokens.md](design-tokens.md) — WCAG 2.1 AA,
   4.5:1), keyboard operability, focus order/visibility, screen-reader semantics (`Semantics` widgets, `alt`
   text, landmark tags/`aria-*` on the static page), readability (line width, font sizes), consistency of
   interaction patterns (confirmation dialogs, inline-edit debounce, hover/tooltip behavior, see [ui-conventions.md](ui-conventions.md)).
2. **SEO analysis of the website** (`docs/`) — meta tags/title/description, structured data, `docs/sitemap.xml` +
   `docs/robots.txt` + `docs/llms.txt` (present, check for currency/completeness), Open Graph/Twitter Card tags
   (`docs/assets/og-image.png`), heading hierarchy, internal linking, load-time-relevant factors (asset sizes
   under `docs/assets/`, blocking resources), plus marketing/conversion aspects of the static page: calls to
   action (download, "Entwicklung unterstützen"), trust signals, above-the-fold clarity of the pitch.
3. **Code optimization without breaking changes** — lean patterns, performance, stability/robustness in `lib/`:
   unnecessary rebuilds/`setState`, missing `const` constructors (exception: the four dynamic theme tokens, see
   `CORPORATE_DESIGN.md`), duplication, dead code, potential null-pointer/edge cases in `lib/utils/analysis.dart`
   and the persistence paths ([persistence.md](persistence.md)), missing error handling at system boundaries (file I/O, network).
   Every proposed fix must keep the existing tests (`flutter analyze` + `flutter test`, incl.
   `gherkin_sync_test.dart`) green and must **not** touch any of the architecture decisions listed in Rule 5.

**Output — no separate report artifact, fix directly instead of just listing:** findings are **not** written into
a separate report file/artifact, but summarized compactly in the chat. For each finding:
- **No UI/UX behavior change, no breaking changes, no new/missing content needed** (typos, dead links, missing
  meta tags, color/contrast bugs that just consistently apply an already-established fix, pure
  performance/deduplication refactors without behavior change, additive a11y semantics without a visual change)
  → **fix directly**, without asking first. Keep `flutter analyze` + `flutter test` green afterward (mandatory).
- **Changes visible behavior, an interaction pattern, a copy/design decision, or needs content/credentials only
  the human has** (e.g. a real Stripe payment-link URL, a new testimonial, a new light-theme variant of the
  website, a new visual saturation/loading indicator) → **don't decide it yourself**, name it briefly in the chat
  as an open point for the human to decide.
- End with a **short summary in the chat**: what was fixed directly (with file:line), what stays open and why. No
  artifact, no new file just for the report — this file is the only lasting trace of the audit process,
  not of its individual findings.

If the audit surfaces a need for doc/Gherkin changes (e.g. a new a11y criterion), Rule 1 below applies as usual.

---
