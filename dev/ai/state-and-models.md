# FinanzGecko — Data flow, models & AppState

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

```
AppStore (persistence, encryption, write queue)
   │  reads/writes
   ▼
AppSchema (in-memory schema, JSON serialization)
   │  wrapped by
   ▼
AppState extends ChangeNotifier (CRUD facade + computed values)
   │  via provider (ChangeNotifierProvider.value)
   ▼
UI (views/widgets) — context.watch<AppState>() / context.read<AppState>()
```

Principle: **every mutating action in `AppState` calls `store.xyz()`, then reloads everything via `_reload()` and
calls `notifyListeners()`** — no manual per-route re-fetch like in a classic SPA. All views react automatically
via `Provider`.

## Data models (`lib/models/`)

| Model | Fields | Note |
|---|---|---|
| `Account` | `id, name, bank, tag, currency, color, archived, createdAt` | `tag` = Kontotyp (see `kTags`); `color` is a hex string (no `Color` object, lossless round-trip); archiving is a soft delete |
| `Balance` | `id, accountId, period ("YYYY-MM"), amountOriginal, currencyOriginal, rate, amountBase, note, enteredAt` | One entry per Konto+month (upsert); `amountBase` = converted to Basiswährung, `rate` frozen at the time it was recorded |
| `Asset` | `id, name, value, createdAt, lastEvaluatedAt` | Vermögenswerte without a time series; `lastEvaluatedAt` gets set to "now" on every value change (drives the 6-month reminder logic) |
| `Subscription` | `id, name, interval, amountOriginal, currencyOriginal, rate, amountBase, createdAt` | Fixposten; the sign of `amountOriginal`/`amountBase` encodes income(+)/expense(−); `interval` ∈ `kSubscriptionIntervals` |
| `WindowPrefs` | `width, height, maximized` | Just size + maximized state, deliberately **no screen position** (otherwise the window ends up off-screen after a monitor change) |

## `AppState` (`lib/state/app_state.dart`)

Central facade for the UI. Two categories of methods:
1. **CRUD** (`addAccount`, `upsertBalance`, `addAsset`, `addSubscription`, …) — delegate to `store`, reload, notify.
2. **Computed values for the UI**, derived from raw data (not persisted):
   - `getBackupReminder()` — never overdue while the app is completely empty (no Konten/Kontostände/
     Vermögenswerte/Fixposten — nothing recorded means nothing to back up). After that: if never exported,
     overdue `kBackupReminderFirstDays` (182, ~6 months) after the earliest recorded activity; after the first
     export, overdue `kBackupReminderRepeatDays` (90, ~3 months) since `lastExportAt`
   - `getAssetReminder()` — list of overdue Vermögenswerte (> `kAssetReevaluationDays` = 182 days since `lastEvaluatedAt`)
   - `getUpdateReminder()` — nudge if the most recently recorded month is older than the current one
   - `computeSubscriptionTotals()` — income/expenses/net, all Fixposten normalized to a monthly equivalent
   - `previousBalance()` / `latestBalanceForAccount()` / `allPeriodsSorted()` / `balancesInPeriod()`

`_checkReminderNotifications()` (called after `init()` and after every mutation via `_reloadAndNotify()`)
additionally checks the backup and Vermögenswerte reminders and, if warranted, fires a native OS notification via
`NotificationService` — **episode-based** (once per newly-entered overdue state, not on every check), see [ui-conventions.md](ui-conventions.md)
"Desktop notifications" and `gherkin/notifications.feature`. It returns immediately unless
`store.notificationsEnabled`, so an installation that never opted in never reaches the plugin at all. The two
message kinds carry distinct notification ids (`kBackupNotificationId`/`kAssetNotificationId`): the platforms
replace an existing notification when a new one reuses its id, which would drop the backup message the moment
the Vermögenswerte message fires in the same cycle. Deliberately no `Timer.periodic` fallback for a
days-long, continuously open, unused app session — that would be speculative behavior for an edge case nobody
asked for, and a periodic timer that's never cancelled violates `flutter_test`'s "no timer may outlive the test"
invariant in widget tests. The check instead runs on every mutation/reload that already happens anyway, plus on
the next app start.
