# FinanzGecko — Tech stack

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

| Area | Choice | Version (see `pubspec.yaml`) |
|---|---|---|
| Framework | Flutter (desktop targets only: Linux/macOS/Windows, no mobile/web) | SDK ^3.12.2 |
| State management | `provider` (`ChangeNotifier` + `ChangeNotifierProvider`) | ^6.1.5 |
| Persistence | own JSON file, no SQLite/Hive/Isar (deliberate decision, see [dev/architecture.md](../architecture.md)) | — |
| Encryption | `cryptography` (AES-256-GCM) + `flutter_secure_storage` (key in OS keychain) | ^2.7.0 / ^10.3.1 |
| Charts | `fl_chart` (line, donut, stacked area — own wrappers in `lib/ui/widgets/`) | ^1.2.0 |
| Exchange rates | `http` against the free Frankfurter.app API (ECB reference rates) | ^1.6.0 |
| OS notifications | `flutter_local_notifications` (native desktop notifications Linux/macOS/Windows; on macOS `UNUserNotificationCenter`, which requires user authorization — hence the opt-in toggle, see [ui-conventions.md](ui-conventions.md)) | ^22.3.0 |
| App metadata | `package_info_plus` (reads version/build number from the installation at runtime, for Einstellungen → "Hilfe") | ^10.2.1 |
| Window | `window_manager` (remembers size/maximized state) | ^0.5.2 |
| File dialogs | `file_selector` (native save/open, no browser download) | ^1.1.0 |
| Links | `url_launcher` (external URLs, mailto:, opening the file explorer) | ^6.3.2 |
| Formatting | `intl` (`NumberFormat`, German number format `de_DE`) | ^0.20.3 |
| Lint | `flutter_lints` | ^6.0.0 |

There are **no** backend services, no REST API for this app itself, no database engine, no auth system. The app
**never opens a network connection on its own**; there are exactly two **occasions**, and both require an explicit
user decision. Deliberately "occasions" rather than "calls": behind the second one, since the checked download
shipped, sit several HTTP calls (releases API, asset, `SHA256SUMS`) — the number of occasions is the claim that
has to hold, not the number of requests.
1. `api.frankfurter.dev` for exchange rates — **opt-in** (`RateFetchConsent`, default `unset` = not allowed).
   Asked exactly once, at the moment a real rate is first needed, never when a view merely opens; the gate sits
   inside `CurrencyService.getExchangeRate` itself, not just at the call sites. Without consent, the local cache
   and the manual rate dialog remain — the app stays fully usable. Reversible under Einstellungen → Wechselkurse.
2. GitHub via "Nach Updates suchen" (Einstellungen → Hilfe) on click (`UpdateService`, [platform.md](platform.md)) — no background
   check, no startup check. That's two stages: first the releases API (`api.github.com`) for the latest tag; and
   **only if the dialog's "Herunterladen" is then chosen**, the release asset itself plus the `SHA256SUMS` file.
   The latter runs over GitHub's download URLs, which redirect to their asset server
   (`objects.githubusercontent.com`) — when enumerating the contacted hosts, don't forget that `api.github.com`
   alone has been incomplete ever since.

The exchange-rate API's reachability indicator in Einstellungen → Hilfe doesn't ping anything when the view is
built either: it shows the stored state and only checks on a click on "Jetzt prüfen". A consent dialog just from
opening settings would be unintelligible to users — so it's **never** asked there.
