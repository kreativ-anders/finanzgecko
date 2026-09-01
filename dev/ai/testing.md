# FinanzGecko — Tests ↔ Gherkin mapping

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

## Feature overview (navigation index)

Every behavior specification at a glance — an entry point for an AI to jump from behavior to source (every
feature file names its `# Source:`). `test/gherkin_sync_test.dart` enforces that every file shows up in this table — the test reads
`dev/ai/testing.md` by path, so moving or renaming this file means updating it.

| Feature | Short | Status |
|---|---|---|
| `gherkin/dashboard.feature` | Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung, Kennzahlen, banners, Konto cards, Zeitraum filter | Unit (`analysis_test`, `app_state_test`) |
| `gherkin/balances_entries.feature` | Month-by-month Kontostand recording/correction, orphaned balances, in-field calculation | Unit (`entries_view_orphan_test`, `entries_view_calculation_test`, `app_state_test`, `formatting_test`) |
| `gherkin/accounts.feature` | Create/edit/archive Konten; bank→color; Enter submits the form | Unit (`account_color_test`, `app_store_ops_test`, `accounts_view_test`) |
| `gherkin/subscriptions.feature` | Fixposten CRUD, monthly equivalent, list ordering, Enter submits the form | Unit (`app_state_test`, `app_store_ops_test`, `subscriptions_view_test`) |
| `gherkin/assets.feature` | Vermögenswerte CRUD, 6-month reminder, list ordering, Enter submits the form | Unit (`app_store_ops_test`, `assets_view_test`) |
| `gherkin/settings.feature` | Basiswährung, security, backup export/import, CSV export, help (version/system info/support), reset | Unit (`csv_export_test`) |
| `gherkin/notifications.feature` | OS notifications for backup/asset reminders, episode-based, opt-in + denied authorization, distinct ids | Unit (`app_state_test`, `app_store_ops_test`) |
| `gherkin/backup_restore.feature` | Export/import (JSON), schema check, bank→color on import, fault tolerance | Unit (`app_store_ops_test`, `backup_hardening_test`) |
| `gherkin/data_security.feature` | AES-256-GCM, OS keychain, quarantine, schema parsing, macOS channel switch (one data file per delivery channel) | Unit (`app_schema_test`, `app_store_encryption_test`, `app_store_key_identity_test`) |
| `gherkin/currency_exchange.feature` | Opt-in for rate fetching (`RateFetchConsent`), exchange rates (frankfurter.dev), cache, offline fallback, manual rate | `test/rate_consent_test.dart` (only the gate + cache path, no network); the HTTP call itself stays UI/integration |
| `gherkin/window.feature` | Window size/maximized state, default/minimum size, splash | UI/integration only (no unit test) |
| `gherkin/navigation.feature` | Top navigation (6 views), banner jumps, in-app Datei menu, keyboard shortcuts, text selection | UI/integration only (no unit test) |
| `gherkin/executable/account_color.feature` | resolveAccountColor rules | **executable** (`test/bdd/account_color_bdd_test.dart`) |
| `gherkin/executable/net_worth_projection.feature` | Trend/projection/Kennzahlen/anomaly | **executable** (`test/bdd/analysis_bdd_test.dart`) |
| `gherkin/executable/update_assets.feature` | Release asset per platform, SHA256SUMS parsing, digest comparison | **executable** (`test/bdd/update_assets_bdd_test.dart`) |

## Regenerating a feature (1 feature → 1 primary file)

Every feature file names two path headers up top:
- **`# Implementation:`** — the **one** file that primarily implements the feature and is the **regeneration
  target** (a view's `*_view.dart`, the facade file for infrastructure features, or the pure module for
  executable features).
- **`# Source:`** — **all** touched files: the primary file **plus** shared infrastructure.

**Recipe "regenerate feature X":** delete/rewrite the `# Implementation:` file; the contract is the feature
file's scenarios **and** its test (via the table below, or `grep "// Gherkin: <feature>"`). The other
`# Source:` files are **fixed, shared context** — read them and extend them at most for the feature's slice, don't
regenerate them wholesale.

**Why not strictly 1:1 for everything:** the `app_state.dart` (state) and `app_store.dart` (persistence) facades
are deliberately shared by ~6 features each (layered architecture, [state-and-models.md](state-and-models.md) — a single encrypted JSON file, no
per-feature duplication); they're never the sole output file of one feature. **True 1:1** exists for the
**executable** features (`analysis.dart`, `resolveAccountColor` in `constants.dart`): there, behavior is fully
pinned down by the feature + step defs — the primary file can be deleted and regenerated purely from spec + BDD
tests. New purely-functional behavior should therefore preferably live there.

Where two features would otherwise claim the same primary file, they're deliberately split: the pure backup flow
(file dialogs, confirmation prompt, snackbars) lives in `backup_actions.dart` (primary for `backup_restore`),
while `navigation_shell.dart` is now just the navigation shell (primary for `navigation`) and only forwards
shortcuts/menu entries to `backup_actions`. The actual persistence/schema check stays in `app_store.dart` (shared
`# Source:` context, see above).

`test/gherkin_sync_test.dart` (invariant 5) enforces: every feature file has a `# Implementation:` that exists and
is listed in `# Source:`.

## Test files

| Test file | Covers | Related feature |
|---|---|---|
| `test/analysis_test.dart` | Pure computations (trend, projection, anomaly, Kennzahlen) | `gherkin/dashboard.feature` |
| `test/app_schema_test.dart` | Schema parsing, fault tolerance, export shape | `gherkin/data_security.feature` |
| `test/app_state_test.dart` | AppState CRUD & derived values (reminders, totals) | several features |
| `test/app_store_encryption_test.dart` | Envelope encryption, quarantine of unreadable files | `gherkin/data_security.feature` |
| `test/app_store_key_identity_test.dart` | Key fingerprint (`keyId`), foreign file left untouched, and the macOS channel switch: own file per channel, adoption of an own-key file, import/empty start via `ignoreForeignData` | `gherkin/data_security.feature` |
| `test/app_store_ops_test.dart` | Store CRUD, export/import, schema version check, import bank→color rule | `gherkin/backup_restore.feature` |
| `test/account_color_test.dart` | `resolveAccountColor` (known bank → brand color, empty → Kontotyp, unknown → error) | `gherkin/accounts.feature`, `gherkin/backup_restore.feature` |
| `test/accounts_view_test.dart` | Enter in the "Neues Konto" form submits it | `gherkin/accounts.feature` |
| `test/subscriptions_view_test.dart` | List ordering (income/expense, monthly amount descending), Enter submits the "Neuer Fixposten" form | `gherkin/subscriptions.feature` |
| `test/assets_view_test.dart` | List ordering (value descending), Enter submits the "Neuer Vermögenswert" form | `gherkin/assets.feature` |
| `test/backup_hardening_test.dart` | Backup export→import round trip & fault tolerance (AppSchema level) | `gherkin/backup_restore.feature` |
| `test/csv_export_test.dart` | CSV export per domain (columns, separator, decimal comma, sorting, quoting, formula guard, file names) | `gherkin/settings.feature` |
| `test/update_service_test.dart` | Manual update check against a mocked GitHub releases API: newer/same/older version, HTTP errors, network errors, unexpected response shape — never an exception escaping | `gherkin/settings.feature` |
| `test/tooling_test.dart` | **Regenerates** the demo data (`buildDemoBackup` → `demo/…json`) and the Linux Hicolor icons (`generateLinuxIcons`) on test run and validates them (schema, references, domain values, icon sizes) | Dev tooling (no feature) |
| `test/entries_view_orphan_test.dart` | Orphaned balances of archived Konten | `gherkin/balances_entries.feature` |
| `test/entries_view_calculation_test.dart` | In-field `+`/`-`/`*`/`/` calculation on save, invalid-input toast | `gherkin/balances_entries.feature` |
| `test/formatting_test.dart` | Number/money formatting, parsing | cross-cutting across all features (non-functional) |
| `test/docs_consistency_test.dart` | **Checks the prose against the code**: disclosed network hosts, asset suffixes, documented data path, banned signing jargon, once-false claims (incl. "no auto-updater", "plaintext JSON"), macOS without a warning, jargon-free landing copy, Kennzahlen and settings parity between the app and `docs/documentation.html`, and that the App Store export-compliance declaration in `macos/Runner/Info.plist` still has the native crypto paths behind it | Meta (README, `docs/`, `macos/Runner/Info.plist`) |
| `test/gherkin_sync_test.dart` | **Wires Gherkin ↔ code/tests** (see below): `# Source:` paths exist, `// Gherkin:` markers point at real features, coverage allow-list | all `gherkin/**/*.feature` (meta) |
| `test/bdd/account_color_bdd_test.dart` | **Runs** `gherkin/executable/account_color.feature` (via the runner) against `resolveAccountColor` | `gherkin/executable/account_color.feature` |
| `test/bdd/analysis_bdd_test.dart` | **Runs** `gherkin/executable/net_worth_projection.feature` against `analysis.dart` | `gherkin/executable/net_worth_projection.feature` |
| `test/bdd/update_assets_bdd_test.dart` | **Runs** `gherkin/executable/update_assets.feature` against `update_assets.dart` | `gherkin/executable/update_assets.feature` |

**Rule:** when a Gherkin scenario is added that describes new behavior, a corresponding Dart test should ideally
follow (or at least a TODO comment referencing the scenario), so spec and automated check don't drift apart.

**Gherkin ↔ tests wiring (enforced, not just convention):** `test/gherkin_sync_test.dart` runs inside normal
`flutter test` (and thus in release.yml's `gate` job) and **fails** the pipeline as soon as spec, code, and tests
drift apart:
1. Every `gherkin/*.feature` needs a `# Source:` header whose source paths all exist.
2. A test links the feature(s) it covers with a header line `// Gherkin: gherkin/<x>.feature` (comma-separated
   for several). Every marker must point at an existing feature file.
3. Exactly the allow-list stored in the test (`featuresWithoutUnitTest`, currently `window` + `navigation`) may be
   without a unit test — any deviation (a newly uncovered feature, or one that's now covered) fails the test run
   and forces either a test marker or a deliberate edit of the allow-list. This keeps `gherkin/` from living an
   isolated documentation life apart from the test run.
4. Every feature file is indexed in `dev/ai/testing.md` (feature overview above).
5. Every feature file has a `# Implementation:` (regeneration target) that exists and is listed in `# Source:`
   (see "Regenerating a feature" above).

## Two kinds of features — declarative vs. executable

- **Declarative features** (`gherkin/*.feature`): describe UI/integration behavior in prose. They're backed by
  ordinary Dart tests + the sync guard above, but not executed line by line.
- **Executable features** (`gherkin/executable/*.feature`, tag `@executable`): are **actually executed step by
  step** by a tiny, dependency-free runner (`test/support/gherkin_runner.dart`). Every executable feature has a
  BDD test file in `test/bdd/` that calls `runFeature(path, (s) { s.step(regex, body); … })`; the step bodies call
  real `lib/` code. That makes the chain **scenario → step def → source function** tangible and greppable (every
  BDD file names its `// Source:`).

**How to add an executable scenario** (deliberately terse, so an AI can edit precisely): (1) add the scenario to
`gherkin/executable/<x>.feature`; (2) if a step is missing, register an `s.step(regex, body)` in
`test/bdd/<x>_bdd_test.dart` with a thin call into the `lib/` function. The runner deliberately only supports
Feature/Background/Rule/Scenario + Given/When/Then/And/But (no Scenario Outline / tables) — write cases out as
individual scenarios.

**Deliberate decision — no `flutter_gherkin`:** the runner is deliberately a self-written ~90-line parser instead
of the `flutter_gherkin` package. Rationale: zero extra dependency, runs natively inside normal `flutter test`
(and thus in the release gate), easy for an AI to read/extend. `flutter_gherkin` targets UI/e2e integration tests
(`integration_test`) and would be overhead for pure domain logic. **Don't replace it with the package without
discussing it first** (cf. Rule 5 below).

## Why `AppStore` has an in-memory mode

`persistToDisk: false` does no `dart:io` at all, and `_inFlutterTest` (via the `FLUTTER_TEST` env var) skips the
`chmod`/`icacls` hardening. Both exist for the same reason: widget tests run under a fake-async clock that never
pumps the real event loop, so real file I/O and `Process.run` never complete and the test hangs. Persistence
itself is covered by plain `test()`-based store tests instead — and hardening a throwaway temp directory would
prove nothing anyway.
