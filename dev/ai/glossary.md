# FinanzGecko — Domain glossary (binding)

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

These German terms are **part of the specification**, not just UI text — use them exactly like this on
regeneration/extension (including in variable names where it makes sense, see e.g. `kTags`, "Fixposten" in a code comment):

| German term | Meaning in code |
|---|---|
| Konto / Konten | `Account` |
| Kontotyp | `Account.tag` (Girokonto, Tagesgeld, Depot, Bargeld, Krypto — `kTags`) |
| Kontostand | `Balance` (one entry per Konto+month) |
| Einträge (view) | Recording/correcting Kontostände for one month, all Konten at once |
| Vermögenswerte / Sachwerte | `Asset` (electronics, furniture, vehicles — no time series) |
| Fixposten | `Subscription` (recurring income/expense: salary, rent, subscriptions, dividends) |
| Basiswährung | `AppState.baseCurrency` — target currency of every Dashboard total |
| Gesamtvermögen | Sum of all Kontostände (optionally incl. Vermögenswerte) in the most recently recorded month |
| Verlauf | Time-series chart of Gesamtvermögen over time, incl. projection |
| Zusammensetzung über Zeit | Stacked area chart: net worth by Kontotyp over all months |
| Verteilung nach Kontotyp | Donut chart for a single month |
| Kennzahlen | Total change, best/worst month, average change, months in the black, high point |
| Zeitraum(-Filter) | Dashboard-wide time-window filter ("Dieses Jahr" / "12 Monate" / "Letztes Jahr" / "Alle"), drives every time-based card |
| Backup exportieren/importieren | JSON export/import via native file dialogs (lossless round trip); optionally password-encrypted (`data/backup_crypto.dart`), plaintext without a password |
| CSV-Export | Lossy table export into four files — Konten, Kontostände, Fixposten, Vermögenswerte (no re-import) |
