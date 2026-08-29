# FinanzGecko — map & rules

Reference docs live in `dev/ai/`, one topic per file. Open only what your task touches; nothing here is
auto-loaded. Prose belongs there, not in this file.

## Where to find what

| Topic | File |
| --- | --- |
| Pitch, scope, license | `dev/ai/product.md` |
| Stack, dependencies, the two network calls | `dev/ai/stack.md` |
| Folder tree, the six views, doc language | `dev/ai/structure.md` |
| Data file, encryption, atomic writes, schema + migration | `dev/ai/persistence.md` |
| Data flow, models, `AppState` | `dev/ai/state-and-models.md` |
| Pure functions (`lib/utils/analysis.dart`) | `dev/ai/analysis.md` |
| Comment rules, English/German, `analysis_options.yaml`, claims register | `dev/ai/code-style.md` |
| Navigation, dialogs, formats, notifications, charts, splash | `dev/ai/ui-conventions.md` |
| Color tokens in code (`theme.dart`/`constants.dart`) | `dev/ai/design-tokens.md` |
| Minimum OS versions, CI, `release.yml`, packaging, signing | `dev/ai/platform.md` |
| German domain terms (binding) | `dev/ai/glossary.md` |
| Feature ↔ test ↔ source map, regenerating a feature | `dev/ai/testing.md` |
| Recurring quality audit | `dev/ai/quality-audit.md` |
| Mandatory agent rules, do-not-revert list, regeneration order | `dev/ai/rules.md` |
| `docs/` website traps | `dev/ai/website.md` |
| Screenshot capture recipe | `dev/ai/screenshots.md` |
| Behavior spec | `gherkin/` |
| Visual identity for designers | `CORPORATE_DESIGN.md` |
| Toolchain, builds, App Store, troubleshooting | `dev/setup.md`, `dev/building.md`, `dev/app-store.md`, `dev/troubleshooting.md` |

## Navigation

- **Change a behavior:** feature table in `dev/ai/testing.md` → that feature's `# Source:` files → its test
  (`grep "// Gherkin: <feature>"`). Edit only that set.
- **Regenerate a feature:** rewrite only its `# Implementation:` file against its scenarios + test; the shared
  `app_state`/`app_store` facades are fixed context. Recipe: `dev/ai/testing.md`.
- **New pure logic:** `lib/utils/analysis.dart` or `lib/constants.dart`, plus a `Scenario` in
  `gherkin/executable/*.feature` and one `s.step(...)` in `test/bdd/`. Views stay thin.

## Rules

- **Never translate the German domain terms** (Konto, Fixposten, Vermögenswerte, …) — `dev/ai/glossary.md`.
- **Never revert a documented decision** (macOS keychain/sandbox settings, unencrypted rates cache, no selectable
  data path, no automatic backup, no DB engine, …) without discussing it first — `dev/ai/rules.md` #5.
- **Docs move with the code, in the same step:** any change to folder structure, architecture, data models, view
  behavior or design tokens updates the matching `dev/ai/` file, plus `CORPORATE_DESIGN.md` (colors/typography)
  and the relevant `gherkin/*.feature` — `dev/ai/rules.md` #1. Code without the doc update is incomplete.
- **New functional behavior is a Gherkin scenario first**, at the latest in the same step — never "later".
- **Comments are English and answer "why this line"**, not "how this app works" — the latter belongs in `dev/ai/`
  and the comment becomes a one-line pointer. Full rules: `dev/ai/code-style.md`.
- **Always verify:** `flutter analyze` and `flutter test` after every change (same as the release gate). After
  touching `analysis_options.yaml`, run `dart fix --apply && dart format .` first.
- `test/gherkin_sync_test.dart` names the broken spec/code/test link in its failure message — read it before hunting.
- A `docs/` rule that bites twice becomes a check in `test/docs_consistency_test.dart`, not just fixed prose.
- This is the only instruction file and the only copy of these rules; point new tools here instead of copying them.
