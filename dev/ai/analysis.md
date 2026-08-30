# FinanzGecko — Pure analysis functions

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

Deliberately kept **UI-free and deterministic**, so they're unit-testable without the Flutter binding (`test/analysis_test.dart`):
- `monthsBetweenPeriods`, `monthsToYearEnd`, `addMonthsToPeriod` — period arithmetic on `"YYYY-MM"` strings
- `olsTrend` — general OLS fit (slope + intercept) over arbitrary (x, y) pairs, x doesn't need to be gap-free (a
  gap just counts as a bigger step) — used e.g. by `AppLineChart`, whose x-axis treats gaps (missing months) as
  real gaps rather than compressing them. `trendSlopePerMonth` is the special case with x = 0..n-1.
- `trendSlopePerMonth` — OLS slope of a time series (the statistical trend for the dashboard)
- `projectionRate` — blends the trend (primary) with the Fixposten net as a prior, whose weight goes to 0 as
  history grows (`trendPoints`) (`priorStrength = 3`). **Not** additive — both are estimators of the same monthly rate.
- `contributionMarketSplit` — splits a net-worth change into "contributed" (Fixposten net × month gap) vs. "market/other"
- `isBalanceAnomaly` — flags a 10× jump (a typical typo pattern: one digit too many/too few)
- `computeNetWorthStats` — best/worst month, average change, months in the black, high point, total change since start
- `periodsForRange` / `availableRanges` / `defaultRange` — the dashboard-wide **Zeitraum filter** as pure logic
  (`enum HistoryRange { ytd, twelveMonths, lastYear, all }`, `now` injectable for tests). `availableRanges` hides
  a preset whenever it would yield the same set as "Alle" (dedup); `defaultRange` = "Dieses Jahr", otherwise "Alle".

Pure CSV export lives in `lib/utils/csv_export.dart` — **one table per domain** instead of one wide file:
`buildAccountsCsv`, `buildBalancesCsv`, `buildSubscriptionsCsv`, `buildAssetsCsv`, bundled by `buildCsvExports`,
which returns the four contents together with fixed file names (`finanzgecko-<domain>-<YYYY-MM-DD>.csv`). Why
separate: a Konto's master data (bank, Kontotyp) belongs to the Konto, not to the month — in one file it would
repeat on every month row and make the table unpivotable. **`Konto-ID`** is the join column between the accounts
and balances tables; it still works when two Konten share a name.

Deliberately narrow: **every amount appears exactly once, in the currency it was recorded in** — no rate, no
second converted amount, no monthly equivalent, no date columns. Anything a spreadsheet can compute itself stays
out; the Fixposten amount applies per interval (the "Intervall" column sits next to it). Conversion is therefore
the evaluating spreadsheet's job — the export delivers the recorded values, not their evaluation. Throughout:
`;`-separated, decimal comma, RFC 4180 quoting, signed amounts — lossy and **without re-import** (the JSON backup
path is the only lossless round trip). The files are written into a user-chosen **folder**
(`getDirectoryPath`, `backup_actions.dart`), with a single overwrite prompt for the whole set — unlike the save
dialog, the folder dialog doesn't ask on its own. Tested in `test/csv_export_test.dart`.

On any change to these formulas: update `test/analysis_test.dart` **and** the matching Gherkin feature.

## CSV formula-injection guard

A leading `=`, `+`, `-` or `@` in an exported cell is prefixed with `'`, because Excel and LibreOffice read such a
cell as a formula (and, historically, as a DDE command) when the file is opened. It is applied **only** to the
free-text columns — Konto name, Bank, Fixposten and Vermögenswert names — and deliberately **not** to
app-generated numeric or enum columns, so a negative amount stays a number and `SUM()` keeps working.
