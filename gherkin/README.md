# Gherkin specification — FinanzGecko

This folder contains the app's functional requirements as Gherkin `.feature` files. Together with
[`../AI_MASTER.md`](../AI_MASTER.md) (architecture, folder structure, conventions, AI rules), it forms the
complete specification from which the app can be **regenerated nearly identically** or extended consistently.

## Conventions

- **Language:** all feature/scenario text is written in English, describing an app whose UI is German — the
  binding German domain terms (see the glossary in `AI_MASTER.md` Section 7) stay untranslated inline, exactly
  like in the rest of the repo's English docs. Step keywords (`Feature`, `Scenario`, `Given`/`Angenommen`,
  `When`/`Wenn`, `Then`/`Dann`, `And`/`Und`, `But`/`Aber`) are written in **English**, so standard Cucumber
  tooling works without language configuration; the rest of the text is English too, aside from the domain terms
  and literally-quoted German UI strings.
- **One file per functional domain**, not per view — e.g. exchange-rate fallbacks affect both Einträge and
  Fixposten, but live bundled in `currency_exchange.feature`.
- **Tags:** every feature carries a `@domain`-style tag (e.g. `@accounts`, `@dashboard`) for traceability to
  `AI_MASTER.md` Section 8 (tests ↔ Gherkin mapping) and to the corresponding source files (comment
  `# Source: lib/...` at the top of every feature).
- **No UI-framework detail** (widget names, pixel values) in the scenarios — they describe *behavior*, not
  implementation. Exception: where a concrete number is a deliberate functional decision (e.g. "182 days"), it's
  named explicitly, since it's relevant to regeneration.
- **These files are not executable tests** (no Cucumber/Gherkin runner is wired into this project) — they're the
  human- and AI-readable requirement spec. The actual automated check runs via the Dart tests in `test/` (mapping:
  see `AI_MASTER.md` Section 8).

## Files

| File | Domain |
|---|---|
| `accounts.feature` | Create/edit/archive/restore Konten |
| `balances_entries.feature` | Record/correct/delete monthly Kontostände |
| `dashboard.feature` | Overview: time filter, Verlauf+projection, Verteilung, Kennzahlen, reminder banners |
| `assets.feature` | Manage Vermögenswerte (Sachwerte) |
| `subscriptions.feature` | Manage Fixposten (recurring income/expenses) |
| `currency_exchange.feature` | Exchange-rate fetching, cache, manual fallback |
| `settings.feature` | Basiswährung, security info, reset |
| `backup_restore.feature` | Export/import of backups |
| `data_security.feature` | Encryption, file integrity, migration |
| `window.feature` | Window behavior (size/maximized), default/minimum size, splash |
| `navigation.feature` | Top navigation, banner jumps, in-app Datei menu, keyboard shortcuts, text selection |
| `executable/account_color.feature` | (executable) Derive the Konto accent color from the bank |
| `executable/net_worth_projection.feature` | (executable) Trend/projection/Kennzahlen/anomaly |

## Required on every change

See `AI_MASTER.md` → "Rules for AI Agents": every behavior change in the code requires, in the same step, an
update to the matching feature file here (a new scenario, a changed scenario, or — with justification — the
removal of an obsolete scenario).
