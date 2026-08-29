# FinanzGecko — AI Master Spec

**Purpose of this document:** This is the central reference so that an AI (this model or another one) can
**rebuild the FinanzGecko app nearly identically, or extend it consistently** — without knowing the prior chat
history. Together with the functional specifications in [`gherkin/`](gherkin/), this is the "source of truth" for
architecture, conventions, domain language, and app behavior.

> **Mandatory for any AI working on this repo:** see the ["Rules for AI Agents"](#rules-for-ai-agents-mandatory-reading)
> section at the very bottom — in particular the obligation to keep this document and `gherkin/` in sync with every change.

**AI_MASTER.md is the coordinator for several tool-specific instruction files**, not the only one. Every common
AI coding tool looks for repo instructions at its own fixed path; to keep every tool interchangeable, there is one
slim pointer file per tool that repeats only the non-negotiable rules and points everywhere else back here and to
`gherkin/` — details and the full list are in [Section 3](#3-folder-structure). If one of these rules changes,
**all** pointer files must be updated in the same step (see "Rules for AI Agents" #1).

---

## 1. Elevator Pitch

FinanzGecko is a **native desktop net-worth tracker** (Flutter, Linux/macOS/Windows). No server, no cloud, no
account. Users create Konten (Girokonto, Depot, Krypto, …) and Vermögenswerte (physical assets), record monthly
Kontostände, maintain recurring income/expenses ("Fixposten"), and in return get a dashboard with net-worth
history, projection, distribution by Kontotyp, and Kennzahlen. All data is stored AES-256-GCM-encrypted in a
single JSON file in the OS data directory; the key lives in the OS credential store.

The entire UI is **in German** — that's a core feature, not an accident, and must be preserved on every
regeneration/extension (see the [glossary](#7-domain-glossary-binding)).

**License:** source code public on GitHub (`kreativ-anders/finanzgecko`), licensed under **GPL-3.0 with a
"Commons Clause" addendum** (see [`LICENSE`](LICENSE)): copyleft like GPL — source freely viewable, modifiable,
and redistributable, derivatives must stay under the same terms — but the Commons Clause additionally prohibits
any **commercial** use (selling the software, or a product/service whose value derives predominantly from its
functionality). This is deliberately **not** OSI-approved "Open Source" in the strict sense (the Open Source
Definition forbids restrictions based on field of use) — on the website (`docs/index.html`) it's therefore
communicated as "quelloffen" plus its own FAQ answer with license details, not claimed uncommented as "Open
Source". The app itself stays free for end users (GitHub Releases); further development is instead funded through
voluntary "pay what you want" support via Stripe on the website (section "Entwicklung unterstützen").

## 2. Tech Stack

| Area | Choice | Version (see `pubspec.yaml`) |
|---|---|---|
| Framework | Flutter (desktop targets only: Linux/macOS/Windows, no mobile/web) | SDK ^3.12.2 |
| State management | `provider` (`ChangeNotifier` + `ChangeNotifierProvider`) | ^6.1.5 |
| Persistence | own JSON file, no SQLite/Hive/Isar (deliberate decision, see [dev/architecture.md](dev/architecture.md)) | — |
| Encryption | `cryptography` (AES-256-GCM) + `flutter_secure_storage` (key in OS keychain) | ^2.7.0 / ^10.3.1 |
| Charts | `fl_chart` (line, donut, stacked area — own wrappers in `lib/ui/widgets/`) | ^1.2.0 |
| Exchange rates | `http` against the free Frankfurter.app API (ECB reference rates) | ^1.6.0 |
| OS notifications | `local_notifier` (native desktop notifications Linux/macOS/Windows) | ^0.1.6 |
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
2. GitHub via "Nach Updates suchen" (Einstellungen → Hilfe) on click (`UpdateService`, Section 6) — no background
   check, no startup check. That's two stages: first the releases API (`api.github.com`) for the latest tag; and
   **only if the dialog's "Herunterladen" is then chosen**, the release asset itself plus the `SHA256SUMS` file.
   The latter runs over GitHub's download URLs, which redirect to their asset server
   (`objects.githubusercontent.com`) — when enumerating the contacted hosts, don't forget that `api.github.com`
   alone has been incomplete ever since.

The exchange-rate API's reachability indicator in Einstellungen → Hilfe doesn't ping anything when the view is
built either: it shows the stored state and only checks on a click on "Jetzt prüfen". A consent dialog just from
opening settings would be unintelligible to users — so it's **never** asked there.

## 3. Folder Structure

```
finanzgecko/
├── AI_MASTER.md                  # ← this document; coordinator of the AI instruction files below (details: paragraph after the header)
├── CLAUDE.md                     # Detailed day-to-day working guide (repo navigation, feature regeneration,
│                                 #   website pitfalls) — despite the name, tool-neutral, imports AI_MASTER.md
│                                 #   at the end (`@AI_MASTER.md`, Claude-Code-specific syntax). Read by Claude Code.
├── AGENTS.md                     # Slim pointer file (agents.md convention): repeats only the non-negotiable
│                                 #   rules from CLAUDE.md and points everywhere else back here + to CLAUDE.md/
│                                 #   gherkin/. Read by OpenAI Codex CLI and other tools that support this convention.
├── GEMINI.md                     # The same pointer file for Gemini CLI (Google).
├── .github/copilot-instructions.md # The same pointer file for GitHub Copilot (path dictated by Copilot itself,
│                                 #   hence under .github/ instead of the root — see the .github/workflows/ entry below).
│                                 #   **All four files above keep identical "Non-negotiable rules" sections** —
│                                 #   if a core rule changes (e.g. a new architecture decision requiring
│                                 #   discussion first), all of them must be updated in the same step (see
│                                 #   "Rules for AI Agents" #1). New tool with its own convention? Add the same
│                                 #   kind of pointer file, list it here, keep the CLAUDE.md "Other AI tools" paragraph in sync.
├── CORPORATE_DESIGN.md           # Color palette, brand-color rules, typography, app icon — deliberately compact
│                                 #   and code-free for design/marketing/external design work; the technical
│                                 #   implementation (getters, contrast fallbacks) lives instead in §5 "Color
│                                 #   tokens — technical implementation". Update both places on any change to
│                                 #   lib/ui/theme.dart/constants.dart design tokens (see "Rules for AI Agents" #1/#4)
├── CHANGELOG.md                  # generated by the release job in release.yml (commits since the last tag, prepended) — not maintained by hand
├── ROADMAP.md                    # Short, public list (English), organized into "Currently working on" / "On hold" /
│                                 #   "Planned" (with quarters) / "Done". Deliberately without detail — rationale
│                                 #   and decisions belong here (AI_MASTER), behavior per gherkin/
├── LICENSE                       # GPL-3.0 + "Commons Clause" addendum (copyleft, but no commercial use) — see "License" below
├── gherkin/                      # ← functional specification as Gherkin features (declarative)
│   └── executable/               # ← executable features (@executable), run via test/support/gherkin_runner.dart
├── templates/                    # ← import template (import-template.json) + field docs for data migration from third-party tools
├── README.md                     # Slim entry point (English, like the code — see note below): pitch, license, quick start, architecture table, links onward
├── CONTRIBUTING.md               # Contribution workflow (English), links to dev/
├── dev/                          # Developer reference (English), split out of README (detail instead of prose in the short doc)
│   ├── setup.md                  #   Platform toolchain setup (Linux/macOS/Windows)
│   ├── building.md               #   Dev run, release builds, packaging, CI/release process, icon pipeline
│   ├── architecture.md           #   Architecture decisions: no DB engine, encryption, window/menu
│   └── troubleshooting.md        #   Troubleshooting, known limitations, migration from old versions
├── pubspec.yaml                  # Package name, version, dependencies, flutter_launcher_icons config
├── analysis_options.yaml         # Lint rules (flutter_lints)
├── lib/
│   ├── main.dart                 # Entry point: window_manager setup, store init, runApp()
│   ├── constants.dart            # Domain constants: tags/Kontotypen, colors, bank list, currencies, thresholds
│   ├── data/
│   │   ├── app_store.dart        # Persistence layer: encryption, atomic writes, write queue, export/import
│   │   ├── app_schema.dart       # In-memory schema of the JSON file (class AppSchema: schemaVersion, lists, meta, window)
│   │   ├── secure_key_store.dart # AES key in the OS keychain (flutter_secure_storage)
│   │   └── backup_crypto.dart    # Password-protected backups (PBKDF2 → AES-GCM) — own format, device-independent,
│   │                             #   password optional; without a password it stays the previous plaintext JSON
│   ├── models/                   # Data classes with fromJson/toJson: Account, Balance, Asset, Subscription
│   ├── services/
│   │   ├── currency_service.dart # Frankfurter.app integration incl. cache fallback
│   │   ├── notification_service.dart # Thin `local_notifier` wrapper for native OS notifications
│   │   └── update_service.dart   # Manual update check against the GitHub releases API (no auto-updater)
│   ├── state/
│   │   └── app_state.dart        # Central ChangeNotifier: CRUD facade + computed values (reminders, totals) for the UI
│   ├── utils/
│   │   ├── analysis.dart         # Pure, UI-free computations (trend, projection, anomaly check, Kennzahlen, Zeitraum filter) — unit-testable
│   │   ├── csv_export.dart       # Pure CSV builders, one table per domain (Konten, Kontostände, Fixposten,
│   │   │                             #   Vermögenswerte) + file names (lossy, no re-import)
│   │   ├── formatting.dart       # Money/percent/date formatting, number parsing, period helpers, hex→Color
│   │   └── update_assets.dart    # Pure update logic: pick the release asset per platform, parse SHA256SUMS,
│   │                             #   compare digests — network- and filesystem-free, hence specified as executable
│   └── ui/
│       ├── navigation_shell.dart # Navigation shell: top nav, in-app "Datei" menu, keyboard-shortcut wiring (→ backup_actions)
│       ├── backup_actions.dart   # Backup flow: export/import file dialogs, CSV folder dialog, confirmation prompt, snackbars
│       ├── app_view.dart         # enum AppView (the six views) + German labels
│       ├── splash_screen.dart    # Splash on startup
│       ├── theme.dart            # Color constants (light/dark/system via `ThemeScope`), ThemeData, `noSelect()` helper
│       ├── views/                # One file per main view (see table below)
│       └── widgets/               # Reusable building blocks (charts, dialogs, banners, form elements)
│                                  #   rate_consent_dialog.dart: opt-in dialog + `resolveRate()` — the ONE rate
│                                  #   path for Einträge and Fixposten (consent → fetch/cache → manual rate)
├── test/                         # Dart unit/widget tests, mirrored to the Gherkin scenarios (see Section 8)
│   ├── support/gherkin_runner.dart # tiny, dependency-free Gherkin runner (runs @executable features)
│   └── bdd/                        # BDD test files: call runFeature(...) + register step defs against lib/

├── tool/generate_icons.dart       # Icon pipeline (one master PNG → every platform icon format)
├── tool/generate_demo_data.dart   # buildDemoBackup() → demo/finanzgecko-demo.json (anchored to "today"); also invoked by flutter test
├── tool/capture_screenshots.sh    # macOS helper: takes the 7 website screenshots per theme at native Retina resolution
│                                  #   (`screencapture -l <windowid>`, app window only) → build/screenshots/<theme>/
├── tool/generate_corporate_design_pdf.sh # CORPORATE_DESIGN.md → CORPORATE_DESIGN.pdf (pandoc → HTML → headless Chrome
│                                  #   print; not LaTeX, which chokes on 🦎/→). Output is an artifact (.gitignore), not committed.
│                                  #   Stylesheet in tool/corporate_design_pdf.css.
├── demo/finanzgecko-demo.json     # importable demo data for screenshots (generated, .gitignore) — via "Backup importieren…"
├── packaging/linux/               # .desktop file + install.sh for the Linux start menu, build_appimage.sh → FinanzGecko-<version>-x86_64.AppImage
├── packaging/windows/             # finanzgecko.iss (Inno Setup) → FinanzGecko-<version>-Setup.exe
│                                  # winget/: manifest templates + render.sh for the FIRST submission to
│                                  #   microsoft/winget-pkgs; after that, the "winget" job in
│                                  #   release.yml updates it automatically. ProductCode there = AppId from the .iss + "_is1"
├── packaging/macos/               # build_dmg.sh: sign (Developer ID, Hardened Runtime) + notarize + build DMG
│                                  #   → FinanzGecko-<version>-mac.dmg; unsigned instead of aborting if no credentials
│                                  # build_appstore.sh: sandboxed App Store build (--dart-define=FINANZGECKO_MAS=true,
│                                  #   AppStore.entitlements, 3rd-Party-Mac-Developer certificates) → .pkg for
│                                  #   App Store Connect; aborts HARD on a missing signature, unlike build_dmg.sh
├── linux/ macos/ windows/         # Native Flutter desktop runners (boilerplate, generally not edited by hand)
├── docs/                          # Static website (GitHub Pages, no build step, plain HTML/CSS)
│   ├── CNAME                      # Custom domain: finanzgecko.app — **every** absolute URL (canonical, og:url,
│   │                               #   og:image, twitter:image, sitemap.xml, robots.txt, llms.txt, README.md, and
│   │                               #   `_downloadPageUrl` in lib/ui/views/settings_view.dart) points at this domain,
│   │                               #   never at kreativ-anders.github.io/finanzgecko
│   ├── index.html                 # Landing page: hero, testimonial, screenshots, features, trust strip, download/support, FAQ
│   ├── download.html              # Download page: one direct link per OS (Windows/macOS/Linux), see below,
│   │                               #   below that the `.download-info` section with explanatory copy
│   │                               #   (platform choice, data handling, updates) — SEO minimum, no
│   │                               #   install instructions (those stay solely in `#faq-install`)
│   ├── documentation.html         # Short guide for end users (no relation to AI_MASTER/gherkin)
│   ├── datenschutz.html           # Privacy policy, split into two parts that are kept strictly apart:
│   │                               #   **Teil A** the website (hosting, Pirsch, GitHub API, Stripe, external links;
│   │                               #   anchors `a1`…`a5`) and **Teil B** the app (what data, where it lives, what
│   │                               #   leaves the device, what the user controls; anchors `b1`…`b4`). Teil B is
│   │                               #   deliberately NON-TECHNICAL — "AES-verschlüsselt" and nothing beyond it: no
│   │                               #   cipher modes, KDF iterations, credential-store names, file paths or
│   │                               #   permission bits. Manuel's call, 2026-08-29. Linked in every page's footer;
│   │                               #   update Teil A on every new third-party integration and Teil B on every
│   │                               #   change to what the app does. Target of `PrivacyUrl` in the de-DE winget
│   │                               #   manifest — the path sits inside a published manifest
│   ├── privacy.html               # Full English equivalent of `datenschutz.html` — same Part A / Part B split,
│   │                               #   same anchors, not a summary. The one page under docs/ that is deliberately
│   │                               #   English: it addresses package reviewers and non-German users, and winget's
│   │                               #   policy review (Policies 1.5.1/1.5.5) requires a readable privacy policy for
│   │                               #   an app holding financial data. Target of `PrivacyUrl` in the en-US manifest
│   ├── danke.html                 # Confirmation page after Stripe checkout ("Entwicklung unterstützen"), `noindex`,
│   │                               #   to be set as the "after payment" redirect in the Stripe payment link —
│   │                               #   exactly https://finanzgecko.app/danke.html (the redirect URL lives in Stripe,
│   │                               #   not in the repo, and isn't caught by any test: update it **manually**
│   │                               #   on a domain/path change)
│   ├── 404.html                    # GitHub Pages serves this page for any unknown path, `noindex`.
│   │                               #   The only page using **root-absolute** paths (`/assets/…`, `/index.html`),
│   │                               #   since it's rendered at arbitrarily deep URLs — relative paths would break there.
│   │                               #   Reports the requested path to Pirsch via `window.pirschNotFound()`
│   └── assets/                    # style.css (shares color tokens with lib/ui/theme.dart; light/dark via
│                                   #   prefers-color-scheme, dark stays the default), icons, screenshots
│       └── screenshots/           # four files per view: `{light,dark}-<name>.{png,webp}`. The pages serve
│                                   #   both themes via `<picture>` + `media="(prefers-color-scheme: light)"`;
│                                   #   dark is the default and `<img>` fallback. Recapture with: tool/capture_screenshots.sh
└── .github/
    ├── copilot-instructions.md    # ← the GitHub Copilot pointer file from the list above, here because the path is
    │                               #   dictated by Copilot itself, not freely chosen
    └── workflows/
        └── release.yml         # the only workflow. Tag push (v*.*.*) OR manual (workflow_dispatch): first the
                                   #   `gate` job (analyze + test + icon pipeline), then 3 native build jobs
                                   #   (ubuntu/macos/windows, `needs: gate`) → release assets, then the `release` job
                                   #   (additionally updates CHANGELOG.md, see below). No separate
                                   #   push/PR CI workflow — `flutter analyze`/`flutter test`/`dart format` run
                                   #   locally before commit, not automated on every push.
```

**Doc language:** Code, comments, `README.md`, `CONTRIBUTING.md`, `dev/`, `CORPORATE_DESIGN.md`, and this document
are in English. `gherkin/` is now English prose too (as of the translation described in §4.6 "Language").
Left German everywhere, including in this document and in English prose generally: the binding domain terms from
§7 (Konto, Fixposten, Vermögenswerte, …) — **never translated, in English running text either** — see §7 and
"Rules for AI Agents" #3. Only `docs/` (the website) stays German prose end to end, since it addresses the
German-speaking end users of a German-UI app — with one deliberate exception, `docs/privacy.html`, whose
audience is package reviewers and non-German users (see §3 file tree).

### The six views (`lib/ui/views/`)

| File | AppView | German label | Core purpose |
|---|---|---|---|
| `dashboard_view.dart` | `dashboard` | Dashboard | Overview: Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung über Zeit, Kennzahlen, Fixposten/Vermögenswerte summary, Konto cards — all driven by the Zeitraum filter |
| `entries_view.dart` | `entries` | Einträge | Month-based recording/correction of Kontostände for all Konten at once |
| `accounts_view.dart` | `accounts` | Konten | Create/edit/archive/restore Konten |
| `subscriptions_view.dart` | `subscriptions` | Fixposten | Create/edit/delete recurring income/expenses |
| `assets_view.dart` | `assets` | Vermögenswerte | Physical assets (no time series) create/inline-edit/delete |
| `settings_view.dart` | `settings` | Einstellungen | Basiswährung, security info, backup export/import, CSV export (4 tables), help (version/system info/support), reset |

Navigation is **not a router** but a simple `enum` switch in `navigation_shell.dart` (`_content()`), driven by
`ValueChanged<AppView> onNavigate`, which every view passes up (e.g. for "Jetzt erfassen" buttons in banners that
jump to another view).

`onNavigate` deliberately carries **no payload**. For the one jump that needs a target *inside* the destination
view — clicking a Dashboard Konto card → "Einträge", positioned on exactly that Konto — there is therefore a
second, narrow callback `onOpenAccountEntry` (`ValueChanged<int>`, `DashboardView` only), which sets
`_focusAccountId` in the shell; `EntriesView` takes that as an optional `focusAccountId` (auto-focus on that row
instead of the first one, plus `Scrollable.ensureVisible`). Every ordinary navigation via `_navigate` clears
`_focusAccountId` again, so a later return via the nav bar doesn't re-focus. This split is deliberate: extending
`ValueChanged<AppView>` with an optional parameter would touch all six views and `backup_actions.dart`, for
exactly one caller.

## 4. Architecture & Data Flow

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

### 4.1 Persistence (`lib/data/app_store.dart`)

- **One file per installation**, no DB server: `finanzgecko-data.json` in the OS data directory (`AppStore.resolveDataDirectory()`).
  - Linux: `~/.local/share/de.finanzgecko.app/` (or `$XDG_DATA_HOME`)
  - macOS: `~/Library/Containers/de.finanzgecko.app/Data/Library/Application Support/FinanzGecko/`
    (sandbox container from v1.8 on; before that `~/Library/Application Support/de.finanzgecko.app/` — the
    migration in §4.1 copies over once). **The folder is deliberately named `FinanzGecko` on macOS, not the
    application ID**: a folder name ending in `.app` reads to Finder as an app bundle (generic icon, kind
    "Programm", double-click reports "beschädigt oder unvollständig"). Linux and Windows keep
    `de.finanzgecko.app`, where the suffix is meaningless and reverse-DNS is conventional.
  - Windows: `%APPDATA%\de.finanzgecko.app\`
- **The storage location is deliberately NOT selectable.** A folder picker was designed, built, and removed
  again: the only reason to want one is "then my file sits in a folder my cloud backs up" — and that's exactly
  what it doesn't deliver. The key is device-bound in the OS keychain; after a disk failure or on a new machine,
  even the nicest cloud copy is no longer openable (exception: a full system restore that brings the keychain
  along). Such a dialog would therefore promise a safety it doesn't have. Recoverable backups run exclusively
  through **export** (see below). The rationale is additionally documented as a doc comment on
  `resolveDataDirectory()` and in plain language under Einstellungen → Sicherheit.
- **Encryption:** AES-256-GCM "envelope" (`{v, keyId, nonce, cipherText, mac}`, `_envelopeVersion = 1`). The key
  comes from `SecureKeyStore` (OS keychain), generated once per installation on first start.
- **`keyId` detects foreign files** (8-byte SHA-256 of the key, plaintext, `AppStore.keyFingerprint`). Without
  this field, "file belongs to a different machine" can't be distinguished from "file is corrupt" — both fail at
  decryption — and the intact foreign file would run into quarantine + a blank start. If `keyId` doesn't match,
  the store throws `ForeignKeyDataException`; it **must** bypass the `catch (_)` in `ensureInitialized()`
  (`on ForeignKeyDataException { rethrow; }`), otherwise exactly the safety net that would be fatal here kicks in.
  `main()` then shows `_ForeignDataApp` — nothing gets moved and **nothing gets written**.
  **`v` stays at 1**: `keyId` is additive, `_isEnvelope` only checks the four known fields, so older app versions
  keep reading new files. A version bump would have broken that. Files without `keyId` (written before the
  feature existed) unchangedly take the previous path.
- **Export is the only device-independent path**, deliberately separate from the data file's envelope
  (`lib/data/backup_crypto.dart`): its key is derived via PBKDF2-HMAC-SHA256 from a **password**, not from the OS
  keychain — that's what lets it be read back in on any machine. The password is **optional**: without one, the
  export still writes exactly the previous plaintext JSON, so existing backups stay valid. Import tells the two
  forms apart by structure (`isEncryptedBackup`), not by extension or filename, and only prompts for protected
  files. The KDF parameters (method, salt, iterations) live **in the file**, so they can be raised later without
  breaking old backups. In the export dialog, "without a password" is its own button rather than "leave the field
  empty" — a dismissed dialog must never produce an unprotected export (`null` = cancelled vs. `''` = deliberately none).
- **The exchange-rate cache deliberately lives OUTSIDE the encrypted file**, in its own plaintext file
  `finanzgecko-rates.json` next to it — public ECB reference rates aren't a secret, and this way a newly cached
  rate never triggers a full re-encrypt of the whole DB. Migration: old stores with `ratesCache` in the DB get it
  moved into the standalone file automatically on first load.
- **Atomic writes:** always write a temp file → delete the old file → rename the temp file (shared helper
  `_atomicWrite`, used by `_persistNow` and `_persistRatesNow`). Prevents a half-written file on a crash mid-write.
- **Rollback on a failed write:** every mutating `AppStore` method holds onto the previous value before mutating
  and restores it if `_persist()`/`_persistRates()` throws — memory and disk never silently drift apart this way.
  `resetAll()` and `importAllData()` additionally write an encrypted snapshot of the previous state **beforehand**
  (`pre-reset-backup-<timestamp>.json` resp. `pre-import-backup-<timestamp>.json`, shared helper
  `_writeSnapshotBackup`) — the app's only two one-way actions (see `gherkin/settings.feature` "Zurücksetzen" and
  `gherkin/backup_restore.feature` "Import").
- **Errors from `AppStore` carry no German UI text:** slim exception types (`RecordNotFoundException`,
  `UnsupportedBackupVersionException`, `AccountImportRejectedException`) transport only structured data: which
  record is missing, which schema version was imported, which bank was unknown. The German user-facing wording
  happens exclusively in `describeError()` (`ui/widgets/app_snackbar.dart`) — keeps the persistence layer
  language-neutral without changing the messages actually shown.
- **Startup safety net:** if initialization in `main()` fails (e.g. no OS keychain/secret service available), the
  app shows a minimal error screen (`_StartupErrorApp`) instead of a silent crash before the first frame —
  deliberately without `AppState`/`AppStore`, exactly what might just have failed.
- **Serialized write queue** (`_writeQueue`/`_enqueueWrite`): prevents two parallel saves from colliding on the
  same temp file. A failed write doesn't poison the queue for later.
- **Unreadable/foreign files are never silently overwritten** — they're first backed up under
  `*.unreadable-<timestamp>` (`_quarantineFile(file, 'unreadable')`), only then does the app start with defaults.
- **Schema-version guard on the load path (not just on import):** on startup, `ensureInitialized()` checks the
  decrypted data file's `schemaVersion` against `currentSchemaVersion`:
  - *Newer than this build* (downgrade) → the file is NOT read leniently (that would drop unknown fields and then
    lossily overwrite the only copy of the user's data); instead it's preserved unchanged under
    `*.newer-version-<timestamp>` (`_quarantineFile(file, 'newer-version')`); the app starts with defaults. An app
    update makes the data readable again. Mirrors the import check
    (`UnsupportedBackupVersionException`) for the everyday load path, which previously had no version guard at all.
  - *Older than this build* (forward migration) → first a byte-exact copy of the (already-encrypted) file as
    `pre-migrate-backup-<timestamp>.json` (`_writePreMigrationBackup`), then the in-memory schema is stamped to
    `currentSchemaVersion` and written back immediately, so the file and the backup don't drift apart across
    restarts. A botched migration stays recoverable this way.
- **Import enforces the bank→color rule:** in `importAllData`, `account.color` gets reset via
  `resolveAccountColor(bank, tag)` (`constants.dart`) — a known bank → its brand color, an empty bank
  (cash/crypto) → the Kontotyp color. An unknown, non-empty bank **aborts the whole import** (no silent injection
  of an arbitrary color). This exactly mirrors the Konto form's rule
  (`bankColorHex(bank) ?? tagColorHex(tag)` + known-bank validator).
- **`kBanks` is a hand-maintained list** (`constants.dart`), organized into branch banks (Sparkassen,
  Volks-/Raiffeisenbanken, big banks, development banks), direct/neobanks, auto banks, brokers & crypto,
  credit-card/niche banks, plus the internationally common payment services PayPal, Wise, and Revolut —
  **not** an automatically generated or complete list (currently ~43 entries, also documented on the website
  under `docs/index.html` FAQ "Welche Banken werden unterstützt?" — kept in sync there **manually**, since the
  static page doesn't read `kBanks` at build time). Every `colorHex` is the bank's **official brand color** (from
  its logo/corporate design/brand kit), hand-researched, not algorithmically derived — for banks without a
  verifiable official source there's deliberately **no** entry rather than a guessed hex value. A missing bank
  gets suggested through the channels linked in the Konto form (GitHub issue or email, see
  `gherkin/accounts.feature`) and then manually added as another `Bank(name, colorHex)` entry (also update the
  FAQ list on the website then).
- **File permissions as defense in depth:** `chmod 700`/`600` (Linux/macOS), `icacls` current-user-only (Windows)
  — in addition to encryption, not as a substitute for it.
- **macOS specifics (important, don't revert by accident):**

  Since App Store preparation there are **two macOS delivery forms**, distinguished by the compile-time constant
  `kIsMacAppStore` (`lib/constants.dart`, `bool.fromEnvironment('FINANZGECKO_MAS')`, **default `false`**).
  Everything below applies to the default case — the DMG build every existing user has installed. The App Store
  build's deviations are noted underneath each point and are **only** reachable via
  `packaging/macos/build_appstore.sh`.

  - `SecureKeyStore` uses `MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore)`.
    - **DMG build (`false`):** the classic keychain. The data-protection variant binds the key to a
      team-ID-derived access group and requires a `keychain-access-groups` entitlement; a build without it —
      including every locally ad-hoc-signed `.app` — fails with `-34018`. That a Developer ID now exists changes
      **nothing** about that: switching would make the key look elsewhere and render every existing user's data
      file unreadable. Don't switch.
    - **App Store build (`true`):** the data-protection variant is mandatory, because a sandboxed app has no
      access to the classic keychain. Works there because `AppStore.entitlements` brings the matching access
      group; those users are fresh installs without a legacy key.
  - **App sandbox has been active in ALL macOS builds since v1.8** (`com.apple.security.app-sandbox = true` in
    `Release.entitlements`, `DebugProfile.entitlements`, and `AppStore.entitlements`). This is a **deliberate
    reversal** of the decision documented through v1.7; the old rationale ("otherwise macOS virtualizes `$HOME`
    and `resolveDataDirectory()` writes past the documented path") was correct, but is now resolved through a
    one-time migration instead of avoidance. The goal is exactly **one** macOS behavior instead of two.
    - `resolveDataDirectory()` needs **no** case distinction: under the sandbox, `$HOME` already points at
      `~/Library/Containers/de.finanzgecko.app/Data`, and the same relative path results again there. The
      documented path is the container path from v1.8 on.
    - **`lib/data/sandbox_migration.dart` is the price of this reversal.** On a sandboxed build's first start, an
      existing installation's data file still sits under the real home. The migration **copies** it into the
      container — it doesn't move it and deletes nothing. Two rules that are non-negotiable: never overwrite (the
      container always wins) and never delete the original (the only fallback if the copy was subtly wrong).
      Runs in `ensureInitialized()` **before** the file is first read.
    - Read access to the old path comes from the entitlement
      `com.apple.security.temporary-exception.files.home-relative-path.read-write`, scoped tightly to
      `/Library/Application Support/de.finanzgecko.app/`. It's **transitional**: once the old path is no longer
      read, it comes out (ROADMAP). Deliberately absent in the App Store build.
    - The `chmod` hardening is skipped in the App Store build (`_chmod` bails immediately when `kIsMacAppStore`).
    - **Keychain question: settled empirically on 2026-08-13 — yes, it works.** A sandboxed build signed with the
      Developer ID reads the existing legacy keychain entry unchanged. Keychain ACLs hang off the code-signing
      identity, and the sandbox doesn't change that (same Developer ID, same bundle ID). That's why
      `SandboxMigration` deliberately migrates **files only, never a key**.
      Tested against a real existing installation: file hash in the container identical to the old path, the app
      showed all data without an import. **Not verifiable in CI** — on a change of signing identity (e.g. the
      App Store build, which Apple re-signs), this result explicitly does **not** hold and needs re-checking.
  - The in-app update path (`UpdateService`, *Nach Updates suchen*) is entirely absent from the App Store build:
    App Review Guideline 2.4.5 forbids a second update channel, and the App Store updates itself. Because
    `kIsMacAppStore` is `const`, the tree shaker strips the path from the binary. The privacy paragraph in the
    help section correspondingly loses its sentence about the GitHub releases API there (see
    `gherkin/settings.feature`).

### 4.2 Schema (`lib/data/app_schema.dart`)

`AppSchema` is the complete in-memory image of the JSON file: `schemaVersion`, `baseCurrency`, lists (`accounts`,
`balances`, `assets`, `subscriptions`), `ratesCache` (legacy migration path, see above), auto-increment IDs
(`nextAccountId` etc.), `lastExportAt`, `window` (`WindowPrefs`), plus the reminder-notification tracking
`notificationsEnabled`, `backupOverdueNotified`, `assetOverdueNotifiedIds` (episode-based, see §4.4 and
`gherkin/notifications.feature`), plus `themeMode` (`AppThemeMode`, default `system`, see §5
"Appearance") and `rateFetchConsent` (`RateFetchConsent`, default `unset`, see §2 and
`gherkin/currency_exchange.feature`) — all additive `meta` fields, no `schemaVersion` bump needed.
For `rateFetchConsent` this is explicitly intentional: a missing key (every file written before the feature
existed) yields `unset`, i.e. **no** assumed consent — existing installations are asked once instead of being
silently grandfathered in. `fromDynamic()` is **fault-tolerant per entry**: a broken line in a list gets skipped
instead of making the whole file unreadable. `toExportJson()` is deliberately slimmer than `toJson()` (no
`ratesCache`/`meta`/`window` — internal implementation detail, not part of a backup) **and without
`account.color`** (`Account.toExportJson`): the color is derivable from the bank and gets reset on import via
`resolveAccountColor` — smaller backups, a hardened import.

`currentSchemaVersion = 1` — increment on every incompatible schema change. That affects **two** paths: (1) the
import check in `AppStore.importAllData()` (rejects backups from a *newer* version, with a clear error message)
and (2) the startup load path in `ensureInitialized()` (downgrade guard + automatic `pre-migrate-backup`, see
§4.1). **When incrementing, do NOT** touch the frozen golden-file fixture `test/fixtures/backup_v1.json` —
instead add a new `backup_v<n>.json` + test, so that "a newer app can no longer read old data" shows up in CI
before it ships.

### 4.3 Data models (`lib/models/`)

| Model | Fields | Note |
|---|---|---|
| `Account` | `id, name, bank, tag, currency, color, archived, createdAt` | `tag` = Kontotyp (see `kTags`); `color` is a hex string (no `Color` object, lossless round-trip); archiving is a soft delete |
| `Balance` | `id, accountId, period ("YYYY-MM"), amountOriginal, currencyOriginal, rate, amountBase, note, enteredAt` | One entry per Konto+month (upsert); `amountBase` = converted to Basiswährung, `rate` frozen at the time it was recorded |
| `Asset` | `id, name, value, createdAt, lastEvaluatedAt` | Vermögenswerte without a time series; `lastEvaluatedAt` gets set to "now" on every value change (drives the 6-month reminder logic) |
| `Subscription` | `id, name, interval, amountOriginal, currencyOriginal, rate, amountBase, createdAt` | Fixposten; the sign of `amountOriginal`/`amountBase` encodes income(+)/expense(−); `interval` ∈ `kSubscriptionIntervals` |
| `WindowPrefs` | `width, height, maximized` | Just size + maximized state, deliberately **no screen position** (otherwise the window ends up off-screen after a monitor change) |

### 4.4 `AppState` (`lib/state/app_state.dart`)

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
`NotificationService` — **episode-based** (once per newly-entered overdue state, not on every check), see §5
"Desktop notifications" and `gherkin/notifications.feature`. Deliberately no `Timer.periodic` fallback for a
days-long, continuously open, unused app session — that would be speculative behavior for an edge case nobody
asked for, and a periodic timer that's never cancelled violates `flutter_test`'s "no timer may outlive the test"
invariant in widget tests. The check instead runs on every mutation/reload that already happens anyway, plus on
the next app start.

### 4.5 Pure analysis functions (`lib/utils/analysis.dart`)

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

## 4.6 Comments, code language, and static analysis

### Comment vs. documentation — where the line is

A comment answers **"why is this line the way it is"** for someone who's already reading this function. Anything
that answers **"how is this app built"** belongs in this document, and the comment turns into a one-liner with a
pointer (`See AI_MASTER §4.1.`).

The reason isn't aesthetics: explaining the same decision in two places means maintaining it in two places — and
nothing checks whether both still agree. The comment layer once grew to ~11,000 words, mostly architecture
rationale that already lived here in more detail.

Practical rules:

- A Dartdoc block over **8 lines** needs a reason. Headings (`## Why this exists`) **inside** a comment are the
  signal that it has turned into documentation — move it to AI_MASTER.
- Don't shorten comments that name a concrete failure case, carry a measurement date ("measured on 2026-08-13"),
  or explain why something is **deliberately** not done (e.g. the deliberately *non*-constant-time checksum
  comparison in `utils/update_assets.dart`). Those are the comments whose absence costs someone hours.
- Restatements of what the code obviously does: delete outright.

### Language

Comments and Dartdoc are **English** — matching `README.md`, `ROADMAP.md`, and `CONTRIBUTING.md`. Before this,
the mix was inconsistent, sometimes within the same file (`app_store.dart`, `settings_view.dart`), which kept
switching modes while reading.

**Exempt and staying German:** the domain terms from Section 7 (Konto, Kontostand, Kontotyp, Fixposten,
Vermögenswerte, Basiswährung, Kennzahlen, …) as well as literally-quoted UI text ("Nach Updates suchen", "Noch nie
exportiert"). Translating them breaks regenerability — see Rule 3 below.

The prose in `docs/` stays German — it addresses the app's German-speaking end users directly, unlike this
document and `gherkin/`, which are AI/developer-facing and were translated to English (see the "Doc language"
note in §3 for the full split, and Rule 3 below for why the domain terms inside them still don't translate).

**One exception inside `docs/`: `docs/privacy.html`**, the full English equivalent of `docs/datenschutz.html`.
It exists because the winget policy review (Policies 1.5.1/1.5.5) asks an app that stores financial data for a
privacy policy its reviewers can read, and it is the `PrivacyUrl` of the en-US manifest. Both pages carry the
same Part A / Part B structure and state the same facts; when one changes, the other changes in the same commit.

**Also English: the text of GitHub releases** (`release.yml`, step "Prüfsummen erzeugen"). It sits on github.com
right next to README/ROADMAP/CONTRIBUTING and has the same audience — v1.9.0 still shipped with a German
checksums section. Step names and comments *inside* the workflows stay German; only someone opening the Actions
view sees those.

### `analysis_options.yaml`

The rule list is deliberately longer than the Flutter template: every entry replaces something a human would
otherwise have to notice in review — the same logic as `test/docs_consistency_test.dart` for prose. Deliberately
**not** enabled: `avoid_dynamic_calls` (the JSON paths in `data/` are intentionally dynamic, see
`app_schema.dart`), `require_trailing_commas` (the formatter adds them anyway), and `public_member_api_docs`
(this is an app, not a package).

After a change to this file: `dart fix --apply && dart format . && flutter analyze && flutter test`.

### Register of claims stated in more than one place

These statements appear in more than one place. If one changes, **all** of them need updating. The ones marked ⚙
are checked mechanically by `test/docs_consistency_test.dart`; the rest are manual — and candidates for the next
test, once they drift apart even once.

| Claim | Locations |
|---|---|
| ⚙ Which network connections the app makes at all | `docs/index.html` (feature card), `docs/llms.txt`, `docs/datenschutz.html` (B3), `docs/privacy.html` (B3), here §6, `services/currency_service.dart`, `services/update_service.dart` |
| ⚙ Whether there's an update check in the app and what it does | `docs/index.html` (FAQ + JSON-LD), `docs/download.html`, `README.md`, `ROADMAP.md`, `docs/datenschutz.html` (B3), `docs/privacy.html` (B3), `docs/llms.txt`, `gherkin/settings.feature` |
| ⚙ Backups can be password-protected | `docs/documentation.html`, `docs/datenschutz.html` (B2), `docs/privacy.html` (B2), `ui/backup_actions.dart`, `data/backup_crypto.dart`, §7 glossary |
| ⚙ macOS is signed and notarized — only Windows warns | `README.md`, `ROADMAP.md`, `docs/index.html` (FAQ), `docs/download.html` (cards) |
| ⚙ File-name suffixes of the release assets | `utils/update_assets.dart`, `.github/workflows/release.yml`, `docs/download.html` |
| ⚙ The data file's storage location per OS | `data/app_store.dart`, here §4.1, `dev/setup.md` — deliberately NOT on the privacy pages any more, which only say the data sits on the user's own computer |
| The privacy policy URLs published in the winget manifests | `docs/datenschutz.html` + `docs/privacy.html` (the pages themselves), `packaging/windows/winget/KreativAnders.FinanzGecko.locale.*.yaml` (`PrivacyUrl`), `docs/sitemap.xml`, `docs/llms.txt` — renaming either page breaks a manifest already published in `microsoft/winget-pkgs` |
| ⚙ The list of Kennzahlen | `ui/views/dashboard_view.dart`, `docs/index.html`, `docs/documentation.html`, §7 glossary |
| ⚙ The sections of Einstellungen | `ui/views/settings_view.dart`, `docs/documentation.html`, `gherkin/settings.feature` |
| The page's opening stays free of jargon | `docs/index.html` (`<h1>` + `.pitch`) — `<title>`/meta are deliberately allowed to keep the platform keywords |

## 5. UI Conventions

**Color palette, brand-color rules, typography, app icon — reader-friendly for designers:** see
[`CORPORATE_DESIGN.md`](CORPORATE_DESIGN.md), deliberately kept compact and code-free (audience: design,
marketing, external design work). The technical implementation of these tokens (getter mechanics, contrast
fallbacks, sync obligations with `theme.dart`/`constants.dart`) lives instead in the next subsection here. The
rest of Section 5 covers interaction patterns and behavior (navigation, dialogs, formats, notifications, charts,
splash).

### Color tokens — technical implementation

- **Only four tokens differ per theme:** `kBackground`, `kSurface`, `kBorder`, `kMuted`, plus `kTextPrimary`
  (full-strength reading text on `kBackground`/`kSurface`, e.g. splash screen, chart tooltips, month picker —
  replaces the earlier hardcoded `Colors.white` spots), all in `lib/ui/theme.dart`. Every other color —
  `kPrimary` (`#00C878`), `kDanger` (`#FF6B6B`), `kWarning` (`#E0A030`), `kTrendUp/Down/Neutral` — is
  **deliberately identical across both themes** (brand colors, no reinterpretation). These four dynamic tokens
  (plus `kTextPrimary`) are top-level **getters** (no longer `const`), reading the `Brightness` value most
  recently resolved by `ThemeScope` — `ThemeScope` sits in `main.dart` above `MaterialApp` (inside a
  `Consumer<AppState>` that rebuilds on every `setThemeMode()`) and resolves `AppThemeMode.system` against
  `MediaQuery.platformBrightnessOf(context)`. Any place referencing one of these tokens therefore **must not** be
  `const` (the Dart compiler aborts with "Invalid constant value" if it is — a reliable marker when reviewing).
  These hex values must stay in sync with `kPrimaryHex`/`kDangerHex` in `constants.dart` (string form for the
  on-disk Konto color field vs. `Color` form for the theme). **Still open:** dedicated light/dark variants for the
  taskbar/dock icon (currently one single icon for both themes, see the icon pipeline in §6).
- **`kPrimaryText`/`kDangerText`/`kWarningText`** (`lib/ui/theme.dart`, same getter pattern as above): WCAG-2.1-AA-
  safe variants of `kPrimary`/`kDanger`/`kWarning` for use as **text/icon color** (as opposed to a fill/chart
  line/button background). `kPrimary` & co. deliberately stay theme-identical as a brand/fill color (see above) —
  but as a text color on the light theme, all three fall short of the 4.5:1 minimum contrast requirement
  (~2.0–2.8:1 against `kBackground`/`kSurface` light). The `*Text` getters return exactly the original constant on
  the dark theme (already ≥6.9:1 there) and only on the light theme a darker, same-hue variant
  (`#00814D`/`#BA4E4E`/`#936920`, all ≥4.5:1 against `#F4F7F5`/`#FFFFFF`). Rule: **any spot where one of the three
  brand colors colors a text line, a standalone icon glyph, or a focus/border indicator
  (`InputDecorationTheme.focusedBorder`) uses the `*Text` variant** — fills (button/chip background,
  `AppLineChart` line color, colored badges with dark text on top) stay on the original constant. Exception: the
  brand wordmark "🦎 FinanzGecko" in the header (`navigation_shell.dart`) stays `kPrimary`, since logos/brand
  names are exempt from the contrast requirement under WCAG 1.4.3. **The same rule applies to
  `docs/assets/style.css`**, which mirrors the app's tokens: the bug already happened there once — the
  JS-highlighted download card (`.download-card-primary`) got `border-color: var(--primary)` and was invisible on
  the light theme at 2.2:1 against `--surface`, while the badge above it (`--primary-text`, 4.9:1) rendered
  correctly. A second case, found in the quality audit (§9): `.card.warn` colored its left border indicator with
  `--danger` (2.6:1 against `--bg` light). That's why `style.css` now also has — analogous to the app — a
  `--danger-text` (`#FF6B6B` dark / `#BA4E4E` light, mirroring `kDangerText`); `--danger` stays as the brand color
  but is currently referenced nowhere else. **A third case, same cause, August 2026:** the new `.download-note`
  (backup recommendation on `download.html`) initially got its left border indicator with `--primary` — 2.2:1
  against `--surface` light, while `.card.note` right below it in the same file had long since used
  `--primary-text`. That the rule got violated the same way three times despite being documented is the actual
  finding: **when adding a new border/focus indicator, reach for an existing
  `border-left: 3px solid var(--*-text)` first** rather than the brand color. Fills stay unchanged on
  `--primary`/`--danger`.
- **Bank colors are logo colors, not text colors.** `kBanks` includes among others `#000000` (Trade Republic, C24,
  Mercedes-Benz Bank) and `#ffe600` (comdirect) — fine as a fill or a 10px dot, unreadable as a label on
  `kSurface` (down to 1.06:1 in the worst case). Where a Konto color colors **text** (currently the Kontotyp chip
  on the Dashboard Konto cards), it therefore passes through `readableOn(hex, kSurfaceHex)` in `constants.dart`: a
  pure hex-to-hex function that mixes toward white or black in 2% steps until 4.5:1 is reached, and otherwise
  passes it through unchanged. The chip's **fill** deliberately keeps the unfiltered brand color (15% opacity) —
  backgrounds have no contrast requirement, and it's what makes the chip look like the bank. 51 of 96
  combinations (48 colors × 2 themes) need the correction; that **all** of them converge is guarded by a scenario
  in `gherkin/executable/account_color.feature`.

- **No native menu** on Linux/Windows (Flutter's `PlatformMenuBar` is macOS-only) → an in-app "Datei" area in the
  window header, identical across platforms, plus global keyboard shortcuts (`Strg`/`⌘`+E/I/Q) via `CallbackShortcuts`.
- **Money/number format:** always via `fmtMoney`/`fmtPercent`/`fmtInputNumber`/`parseInputNumber` from
  `formatting.dart` — German format (`de_DE`, comma as the decimal separator), but the parser also accepts the
  old dot notation for backward compatibility.
- **The `noSelect()` helper** (`theme.dart`) excludes button labels/nav chrome from the app-wide `SelectionArea`
  (in `main.dart`) — only content text should be selectable/copyable. **This is also a prerequisite for the
  correct mouse cursor:** the `SelectionArea` places a text cursor over every selectable `Text`, and that sits
  *deeper* in the tree than the click cursor of the enclosing `InkWell`/`TextButton` — on a tie, the deeper one
  wins, so the pointer never turns into a hand. Rule: **every clickable element whose label is a `Text` wraps that
  label in `noSelect(...)`** (buttons, nav entries, clickable cards, `ListTile` suggestions). An explicit
  `mouseCursor` isn't needed then — Material buttons and `InkWell` already request the click cursor themselves.
  Elements without a text child (`IconButton`, `Switch`) are never affected; input fields correctly keep the text
  cursor, and the hover charts (`line_chart.dart`, `stacked_area_chart.dart`) deliberately stay at the default
  cursor, since they don't trigger anything, only show a tooltip.
- **Confirmation dialogs:** simple yes/no (`AlertDialog`) for reversible-ish actions (archive, delete); for the
  **one true "point of no return" action** (resetting the app), a **typed confirmation phrase**
  (`ZURÜCKSETZEN`, `reset_confirm_dialog.dart`) instead of a simple click.
- **Inline edit with debounce** (600 ms, `Timer`) for Vermögenswerte and Fixposten — no explicit "Speichern"
  needed, saves automatically on typing pause/focus loss/Enter.
- **Reminder/banner order on the Dashboard** (`dashboard_view.dart`): update reminder → overspend banner (only if
  the Fixposten net is negative) → backup reminder → asset reminder. This order is deliberate (urgency).
- **Desktop notifications** (Einstellungen → "Benachrichtigungen", on by default): mirror the backup and asset
  reminders additionally as a native OS notification, so they're seen even when the Dashboard isn't currently
  open. Fires **episode-based, exactly once** per newly-entered overdue state (not on every app start) and
  **only while the app is running** — no background service, see §6 and `gherkin/notifications.feature`.
- **Mouse hover on all three Dashboard charts** (`AppLineChart`, `AppDonutChart`, `AppStackedAreaChart`, all in
  `lib/ui/widgets/`): Verlauf and Zusammensetzung über Zeit show a vertical guide line + tooltip (period, per
  series a color dot/name/amount, for the composition chart additionally the share in %), hand-built via
  `MouseRegion`/`setState` instead of fl_chart's own touch system — the latter demonstrably lost the hover state
  unpredictably between adjacent positions with continuous x positions (time series). The distribution donut, by
  contrast, deliberately uses fl_chart's own `PieTouchData`: there, touch resolution is a discrete "which segment"
  hit test without the position interpolation that was the problem for the line chart; the hovered segment grows
  slightly, Kontotyp + share appear in the empty inner circle. Tooltip rows with differently long labels get a
  **fixed, right-aligned column width** for amount/share instead of plain text after an `Expanded` label — the
  latter produces a row-to-row inconsistent (visually restless) gap before the number.
- **Readable line width:** running text in a Dashboard card (e.g. the foreign-currency rounding note) is capped
  at a fixed `maxWidth` (`ConstrainedBox`), instead of running the full, very long card/dashboard width on wide
  windows (up to 1100px, see `navigation_shell.dart`).
- **Splash duration (1100ms hold + 400ms crossfade, `splash_screen.dart`)** is a deliberate branding, not a
  loading, decision: `main()` calls `windowManager.show()` **before** `runApp()`, so the window is already
  visible (empty, in `kBackground`) before the splash even appears — both values add to this init time, so the
  start feels branded for ~1.5s overall. A shorter duration would make the start noticeably snappier; that was
  specifically evaluated (issue #11) and rejected. Don't change the values without discussing it first.

## 6. Platform Specifics (see also [dev/setup.md](dev/setup.md) and [dev/building.md](dev/building.md) for detail)

- **Minimum OS versions follow Flutter, without an extra check of our own.** If a Flutter upgrade raises a
  platform floor (most recently: 3.47 raises macOS from 10.15 to 12), that's adopted rather than weighed against
  our own list. Rationale, worked out once on 2026-08-16: Flutter's floors sit **behind** each vendor's support
  window, not ahead of it — macOS 12 got its last security updates in September 2024, Windows 10 in October 2025,
  Debian 10 (even LTS) in June 2024; all three remain Flutter's minimum. Anyone affected by such a bump has
  therefore been running an unpatched system for years already. For an app whose promise is the security of
  local financial data, carrying such systems along isn't the more generous choice — it's the worse one. Google
  maintains these deadlines against vendor cycles anyway — a second list in the repo would just be one more place
  to go stale.
  **The one exception that needs a real decision:** a bump that excludes an OS version the vendor is *still*
  shipping security updates for. That has never happened so far.
- **Intel Macs are the one thing that needs watching** — hardware, not OS. macOS 26 Tahoe is the last macOS
  version for Intel; Flutter currently demotes x64 macOS to a warning. If that turns into a hard error, the two
  "Apple Silicon & Intel" claims in `docs/download.html` need to be updated in the same commit (a candidate for a
  guard in `test/docs_consistency_test.dart`).

- Cross-platform builds are **not possible** — every platform has to be built on its own OS; all three at once
  only via GitHub Actions (`.github/workflows/release.yml`, on a tag push `v*.*.*` or manually via
  `workflow_dispatch`). A `gate` job (analyze + test + icon pipeline) runs before the build jobs; if it fails, no
  bundle gets built/released. There's deliberately no separate push/PR CI workflow — `flutter analyze`,
  `flutter test`, and `dart format` run locally before commit (see CLAUDE.md "Always verify"), release.yml is the
  only GitHub workflow in the repo.
  **Build jobs' `if:` conditions must start with `!cancelled() &&`** — not cosmetic: `bump-version` is
  deliberately skipped on a tag push and on "bump: none", and GitHub by default skips everything hanging off a
  skipped job via `needs`. This inheritance only turns off once the condition contains a status-check function;
  the also-present `needs.bump-version.result == 'skipped'` is **not** enough on its own, even though it reads as
  if it should be. Without `!cancelled()`, neither ad-hoc test builds nor tag-push releases (path A) ran — only
  the bump-button path (path B) did — and the run was reported fully green regardless, just without a single
  built job. Don't "clean this up".
- **Splash logo per theme** (`assets/logo/`): two files with an identical crop (512×333 each, taken from
  `kreativ-anders/static-assets`). **The names describe the image's color, not the theme** —
  `kreativ-anders-light-512.png` is the *light* logo (white text) and belongs on the **dark** background,
  `kreativ-anders-dark-512.png` the *dark* one (black text) on the **light** one. `splash_screen.dart` picks via
  `kIsDarkTheme` (`theme.dart`). Before this, the light logo ran on both themes and only reached 1.3:1 on
  light — practically invisible; now 13.7:1 resp. 6.4:1. The mapping looks swapped at first glance, but isn't:
  don't "straighten it out".
- Icon pipeline: a single 1024×1024 master (`assets/icon/icon.png`) feeds every platform format via
  `dart run tool/generate_icons.dart` — `flutter_launcher_icons` is only used for macOS now (`pubspec.yaml`,
  `windows.generate: false`); Windows `.ico` and Linux Hicolor icons are built by `tool/generate_icons.dart`
  itself (`generateWindowsIcon`/`generateLinuxIcons`, both pure functions, also run by `flutter test`). Reason:
  `flutter_launcher_icons`' own Windows generator writes only a single 256px size into the `.ico`
  (`icon_size` config), which leaves Explorer/taskbar/start menu without an icon after install instead of
  downscaling — `generateWindowsIcon` instead produces a real multi-size `.ico` (16–256px).
- Release artifacts are **finished packages rather than raw bundle folders** (which confused test users and broke
  the start when individual files were deleted): Windows → Inno Setup installer `FinanzGecko-<version>-Setup.exe`
  (`packaging/windows/finanzgecko.iss`, built with `iscc` in the `windows` job), Linux → a single executable
  AppImage `FinanzGecko-<version>-x86_64.AppImage` (`packaging/linux/build_appimage.sh` via `appimagetool`),
  macOS → a disk image `FinanzGecko-<version>-mac.dmg` (`hdiutil` step in the `macos` job, image =
  `FinanzGecko.app` + a symlink to `/Applications`). The version is read from `pubspec.yaml` in every build job
  (not from the git tag), so even untagged ad-hoc test builds (`workflow_dispatch`, `bump: none`) get a versioned
  file name. `packaging/linux/install.sh` remains as an alternative for the Linux start menu from an unpacked bundle.
- **macOS: DMG instead of a zipped `.app` bundle** (since August 2026). Two reasons, the second is the real one:
  first, "open the image, drag the app onto `Programme`" is the macOS-familiar flow — with the ZIP, the bundle
  landed in the downloads folder and often got launched from there. Second, a DMG can carry the notarization
  ticket (`xcrun stapler staple`), a ZIP can't: its ticket would need Gatekeeper to look it up online at Apple on
  first launch. The switch is therefore a prerequisite for the planned signing/notarization (see
  [ROADMAP.md](ROADMAP.md)) and was deliberately done *beforehand*, so the file name doesn't change twice.
  `hdiutil` instead of `create-dmg`: present on every macOS runner, no extra dependency.
- **Signing/notarizing runs through `packaging/macos/build_dmg.sh`** — one script for local *and* CI (like
  `packaging/linux/build_appimage.sh`), so the hand-tested build and the CI build never diverge. It signs
  inside-out (first embedded `.dylib`s, then every framework, the bundle last; deliberately **no** `--deep`,
  which Apple doesn't intend for distribution), with Hardened Runtime (`--options runtime`, required for
  notarization) and `--timestamp`. Only the outer bundle gets entitlements.
  **Notarized twice**: once a ZIP of the app, to staple the ticket *into the app* via `stapler`, and once the
  finished DMG. Stapling only the DMG isn't enough — the app pulled out of it would then carry no ticket of its
  own, and Gatekeeper would have to check online on first launch, exactly what the DMG path is meant to avoid.
  If identity or credentials are missing, the script builds an **unsigned** DMG and warns instead of aborting:
  forks and ad-hoc test builds have no secrets, and a hard failure would block the atomic release chain there.
  `SIGN_IDENTITY` is deliberately just the substring `Developer ID Application` (codesign resolves it as long as
  exactly one identity matches) — no name and no team ID in the repo.
  Every `codesign` call runs through a `retry` function (5 attempts, growing pause). This is **not** precautionary
  decoration: `--timestamp` is a network call per signature to Apple's timestamp service, which occasionally
  doesn't answer; codesign reports that as `errSecInternalComponent` and aborts, the same call goes through
  unchanged seconds later (exactly what happened on the first local signing run). Don't remove it.
- **Checksums:** the `release` job additionally drops a `SHA256SUMS` over the three platform packages as a
  release asset and writes the same hashes into the release text (`body_path`). That's the one allowed exception
  to the rule below — not a binary duplicate, but a text file in `sha256sum -c`'s standard format.
  `sha256sum FinanzGecko-*` instead of `sha256sum *`: the shell creates the target file via the redirect *before*
  the command runs, so a `*` would hash the still-empty `SHA256SUMS` against itself. For `docs/download.html` the
  file is uncritical: asset resolution matches via `data-asset-suffix`, and `SHA256SUMS` carries none of those.
  The release text itself is **English** (§4.6 "Language") and claims integrity, not authenticity —
  `SHA256SUMS` is unsigned.
- **No unversioned alias assets:** every release carries exactly **one** binary per platform (the versioned
  name). An earlier approach additionally uploaded a byte-identical unversioned copy
  (`cp`/`Copy-Item` before the respective `upload-artifact` step), so `docs/download.html` could link firmly to
  `.../releases/latest/download/<fixed name>` — but that doubled the upload and the asset list per release for
  pure duplicates. Stays abolished.
- **`docs/download.html` resolves the concrete asset client-side** (progressive enhancement, since August 2026).
  Three equal cards ship, whose `href` statically points at `.../releases/latest` — exactly the state that stays
  correct without JavaScript, without network, and under an API rate limit. A script at the end of the page adds
  two independent improvements:
  1. **OS detection** (`navigator.userAgentData.platform`, falling back to `navigator.platform`/user agent): the
     matching card moves to the front via `grid.insertBefore` and gets `.download-card-primary` + a "Für dein
     System erkannt" badge. The other two stay **equally sized and visible** — a misdetection must never cut
     anyone off from the right download. That's why there's deliberately *no* single big button. Mobile UAs
     (iOS/Android) are deliberately not detected: there's no mobile version, so all three cards stay equal there.
  2. **Asset resolution** via `api.github.com/repos/.../releases/latest`: per card, the asset is matched via
     `data-asset-suffix` (`-Setup.exe`, `-mac.dmg`, `-x86_64.AppImage`), the button's target is set to its
     `browser_download_url`, and version + file size appear in `.download-meta`. If no matching asset is found
     (e.g. because a platform build failed in that release), that **one** card keeps the fallback link.

  Reason for the reversal against the earlier "no JS/GitHub-API calls on the static page" rule: all three buttons
  used to end up on the same release page, where users had to pick the right one out of five assets (three
  binaries + two source archives) — the single biggest hurdle on the whole page for this audience. The rule was
  already broken anyway, since `docs/index.html` queries the same API for the star counter.
  **The suffixes are coupled to the artifact names in `release.yml`** — if a file name changes there, the
  `data-asset-suffix` attributes must be updated too, otherwise the page silently falls back to the release page
  (no visible error, easy to miss). Every new network call the website makes additionally belongs in
  `docs/datenschutz.html`.
- **Website under its own domain `finanzgecko.app`** (GitHub Pages + `docs/CNAME`). Absolute URLs consistently
  belong on this domain — `kreativ-anders.github.io/finanzgecko` must appear nowhere anymore (GitHub does
  redirect, but a `canonical`/`og:url` on the old host splits SEO and analytics signals across two hostnames).
- **Reach measurement with Pirsch Analytics** (`<script defer src="https://api.pirsch.io/pa.js" id="pianjs"
  data-code="…">` in the `<head>` of **every** page under `docs/`, don't forget it on new pages). Deliberately
  chosen because it's cookie-free, doesn't store IPs, and is hosted in Germany: so no cookie banner and no
  consent under § 25 TDDDG are needed, matching the product's privacy promise. That applies **only to the
  website** — the app itself still sends **no** telemetry; keep that separation clean in `docs/index.html`,
  `docs/llms.txt`, and `docs/datenschutz.html`. Every additional third-party integration must be added to
  `docs/datenschutz.html`.
- **No automatic/silent auto-updater — but a checked download on click** (changed in August 2026; the earlier
  version excluded the download too, the rationale being the missing signing certificate. That no longer holds
  for macOS, still does for Windows — see [ROADMAP.md](ROADMAP.md)). What stays unchanged is the crucial part:
  **every** network call happens because of a click. No startup check, no periodic check, no background download.
  Flow via `UpdateService` (`lib/services/update_service.dart`):
  1. Einstellungen → Hilfe → "Nach Updates suchen" fetches the latest release tag
     (`api.github.com/repos/kreativ-anders/finanzgecko/releases/latest`) and compares it against `PackageInfo`.
     **Already current** and **failed** (offline, GitHub down, rate limit) stay snackbars, the latter with a
     generic "please try again later" instead of an error dialog. **New version available** is deliberately an
     `AlertDialog` (actionable, must not disappear on its own), with "Später" and "Herunterladen".
  2. Only on "Herunterladen": a save-location dialog (`getSaveLocation`) — **no** silently dropping it in
     `~/Downloads`, which triggers its own TCC prompt on macOS ("Zugriff auf den Ordner Downloads") that would be
     especially out of place for this app. The asset for the current platform is suggested
     (`selectAssetName`, `lib/utils/update_assets.dart`).
  3. Download, then a comparison against `SHA256SUMS` from the same release. **Only written after the check
     passes** — an unverified file must never sit in the target folder looking installable.
  4. Then a dialog with the platform-dependent next step and "Im Ordner zeigen".
     The app **doesn't execute the file** and doesn't replace itself: on Windows that would mean "start the
     installer" — launching a freshly downloaded executable file. The hint to **quit** FinanzGecko first appears
     once for all platforms in the dialog (previously worded per platform — and forgotten under Linux), mirrored
     in the update FAQ on `docs/index.html` including its JSON-LD copy.
  What the checksum proves and what it doesn't: `SHA256SUMS` arrives over HTTPS but is **not signed**. A match
  shows the file arrived unchanged and belongs to this release — it is **not** proof of authenticity. That comes,
  on macOS, from notarization, which the OS checks on launch anyway. UI text is worded accordingly as "geprüft",
  not "verifiziert/echt". If the release is missing the file for this platform or `SHA256SUMS` (older releases),
  **nothing is guessed** — `docs/download.html` opens instead.
- **`CHANGELOG.md`** is maintained exclusively by the `release` job in `release.yml`: on every actual release
  (tag push or version-bump dispatch, not on a plain test build with `bump: none`), a section with the commit
  messages since the previous tag gets prepended and pushed straight to `main`. Deliberately **no** separate
  push/PR workflow for this — that would water down the "single workflow" decision above.

## 7. Domain Glossary (Binding)

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

## 8. Tests ↔ Gherkin Mapping

### Feature overview (navigation index)

Every behavior specification at a glance — an entry point for an AI to jump from behavior to source (every
feature file names its `# Source:`). `test/gherkin_sync_test.dart` enforces that every file shows up here.

| Feature | Short | Status |
|---|---|---|
| `gherkin/dashboard.feature` | Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung, Kennzahlen, banners, Konto cards, Zeitraum filter | Unit (`analysis_test`, `app_state_test`) |
| `gherkin/balances_entries.feature` | Month-by-month Kontostand recording/correction, orphaned balances | Unit (`entries_view_orphan_test`, `app_state_test`) |
| `gherkin/accounts.feature` | Create/edit/archive Konten; bank→color | Unit (`account_color_test`, `app_store_ops_test`) |
| `gherkin/subscriptions.feature` | Fixposten CRUD, monthly equivalent | Unit (`app_state_test`, `app_store_ops_test`) |
| `gherkin/assets.feature` | Vermögenswerte CRUD, 6-month reminder | Unit (`app_store_ops_test`) |
| `gherkin/settings.feature` | Basiswährung, security, backup export/import, CSV export, help (version/system info/support), reset | Unit (`csv_export_test`) |
| `gherkin/notifications.feature` | OS notifications for backup/asset reminders, episode-based, on/off | Unit (`app_state_test`, `app_store_ops_test`) |
| `gherkin/backup_restore.feature` | Export/import (JSON), schema check, bank→color on import, fault tolerance | Unit (`app_store_ops_test`, `backup_hardening_test`) |
| `gherkin/data_security.feature` | AES-256-GCM, OS keychain, quarantine, schema parsing | Unit (`app_schema_test`, `app_store_encryption_test`) |
| `gherkin/currency_exchange.feature` | Opt-in for rate fetching (`RateFetchConsent`), exchange rates (frankfurter.dev), cache, offline fallback, manual rate | `test/rate_consent_test.dart` (only the gate + cache path, no network); the HTTP call itself stays UI/integration |
| `gherkin/window.feature` | Window size/maximized state, default/minimum size, splash | UI/integration only (no unit test) |
| `gherkin/navigation.feature` | Top navigation (6 views), banner jumps, in-app Datei menu, keyboard shortcuts, text selection | UI/integration only (no unit test) |
| `gherkin/executable/account_color.feature` | resolveAccountColor rules | **executable** (`test/bdd/account_color_bdd_test.dart`) |
| `gherkin/executable/net_worth_projection.feature` | Trend/projection/Kennzahlen/anomaly | **executable** (`test/bdd/analysis_bdd_test.dart`) |
| `gherkin/executable/update_assets.feature` | Release asset per platform, SHA256SUMS parsing, digest comparison | **executable** (`test/bdd/update_assets_bdd_test.dart`) |

### Regenerating a feature (1 feature → 1 primary file)

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
are deliberately shared by ~6 features each (layered architecture, Section 4 — a single encrypted JSON file, no
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

### Test files

| Test file | Covers | Related feature |
|---|---|---|
| `test/analysis_test.dart` | Pure computations (trend, projection, anomaly, Kennzahlen) | `gherkin/dashboard.feature` |
| `test/app_schema_test.dart` | Schema parsing, fault tolerance, export shape | `gherkin/data_security.feature` |
| `test/app_state_test.dart` | AppState CRUD & derived values (reminders, totals) | several features |
| `test/app_store_encryption_test.dart` | Envelope encryption, quarantine of unreadable files | `gherkin/data_security.feature` |
| `test/app_store_ops_test.dart` | Store CRUD, export/import, schema version check, import bank→color rule | `gherkin/backup_restore.feature` |
| `test/account_color_test.dart` | `resolveAccountColor` (known bank → brand color, empty → Kontotyp, unknown → error) | `gherkin/accounts.feature`, `gherkin/backup_restore.feature` |
| `test/backup_hardening_test.dart` | Backup export→import round trip & fault tolerance (AppSchema level) | `gherkin/backup_restore.feature` |
| `test/csv_export_test.dart` | CSV export per domain (columns, separator, decimal comma, sorting, quoting, formula guard, file names) | `gherkin/settings.feature` |
| `test/update_service_test.dart` | Manual update check against a mocked GitHub releases API: newer/same/older version, HTTP errors, network errors, unexpected response shape — never an exception escaping | `gherkin/settings.feature` |
| `test/tooling_test.dart` | **Regenerates** the demo data (`buildDemoBackup` → `demo/…json`) and the Linux Hicolor icons (`generateLinuxIcons`) on test run and validates them (schema, references, domain values, icon sizes) | Dev tooling (no feature) |
| `test/entries_view_orphan_test.dart` | Orphaned balances of archived Konten | `gherkin/balances_entries.feature` |
| `test/formatting_test.dart` | Number/money formatting, parsing | cross-cutting across all features (non-functional) |
| `test/docs_consistency_test.dart` | **Checks the prose against the code**: disclosed network hosts, asset suffixes, documented data path, banned signing jargon, once-false claims (incl. "no auto-updater", "plaintext JSON"), macOS without a warning, jargon-free landing copy, Kennzahlen and settings parity between the app and `docs/documentation.html` | Meta (README, `docs/`) |
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
4. Every feature file is indexed in AI_MASTER.md (feature overview).
5. Every feature file has a `# Implementation:` (regeneration target) that exists and is listed in `# Source:`
   (see "Regenerating a feature" above).

### Two kinds of features — declarative vs. executable

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

## 9. Quality Audit (recurring task)

There's deliberately **no** automated CI step for this (no push/PR workflow, see Section 6) — this audit is a
**manually/on-demand triggered** task for an AI, useful e.g. before a bigger release or whenever it hasn't run in
a while. The goal is a **findings report**, not automatic breaking changes — implementing concrete fixes is a
separate step, agreed with the human afterward.

Three sub-areas, each with a clear scope:

1. **Usability & accessibility of the UI** — both the Flutter desktop app (`lib/ui/views/`, `lib/ui/widgets/`,
   `lib/ui/theme.dart`) and the landing page (`docs/index.html`, `docs/download.html`,
   `docs/documentation.html`, `docs/danke.html`, `docs/assets/style.css`). Checkpoints include: contrast (see the
   `kPrimaryText`/`kDangerText`/`kWarningText` rule in §5 "Color tokens — technical implementation" — WCAG 2.1 AA,
   4.5:1), keyboard operability, focus order/visibility, screen-reader semantics (`Semantics` widgets, `alt`
   text, landmark tags/`aria-*` on the static page), readability (line width, font sizes), consistency of
   interaction patterns (confirmation dialogs, inline-edit debounce, hover/tooltip behavior, see Section 5).
2. **SEO analysis of the website** (`docs/`) — meta tags/title/description, structured data, `docs/sitemap.xml` +
   `docs/robots.txt` + `docs/llms.txt` (present, check for currency/completeness), Open Graph/Twitter Card tags
   (`docs/assets/og-image.png`), heading hierarchy, internal linking, load-time-relevant factors (asset sizes
   under `docs/assets/`, blocking resources), plus marketing/conversion aspects of the static page: calls to
   action (download, "Entwicklung unterstützen"), trust signals, above-the-fold clarity of the pitch.
3. **Code optimization without breaking changes** — lean patterns, performance, stability/robustness in `lib/`:
   unnecessary rebuilds/`setState`, missing `const` constructors (exception: the four dynamic theme tokens, see
   `CORPORATE_DESIGN.md`), duplication, dead code, potential null-pointer/edge cases in `lib/utils/analysis.dart`
   and the persistence paths (Section 4.1), missing error handling at system boundaries (file I/O, network).
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
  artifact, no new file just for the report — this document (§9) is the only lasting trace of the audit process,
  not of its individual findings.

If the audit surfaces a need for doc/Gherkin changes (e.g. a new a11y criterion), Rule 1 below applies as usual.

---

## Rules for AI Agents (MANDATORY READING)

These rules apply to **any AI** working on this repository — whether extending the existing app or regenerating a
new instance from these documents.

1. **This document, `CORPORATE_DESIGN.md`, and `gherkin/` are a mandatory part of every change, not optional.**
   If a task changes the folder structure, the architecture, a data model, a constant with functional meaning
   (e.g. `kBackupReminderFirstDays`), or a view's behavior → **in the same work step**:
   - Update Section 3 (folder structure) if files/folders were added/removed.
   - Update Section 4/5 (architecture/UI conventions) if data flow, schema, or conventions change.
   - Update `CORPORATE_DESIGN.md` if a color, a color token, or the typography changes.
   - Add or correct the new/changed scenario in the matching `.feature` file under `gherkin/`.
   - On a new German domain term: extend Section 7 (glossary).
   - If one of the **non-negotiable rules** changes (currently: German domain language, not reverting architecture
     decisions without discussion first, doc-sync obligation, `flutter analyze`/`flutter test` after every
     change) → update the same "Non-negotiable rules" section in **all** AI pointer files (currently
     `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md` — see Section 3 for the list). Added a new tool
     with its own convention? Add the same kind of pointer file, list it in Section 3.
   A change to production code **without** an accompanying doc update counts as incomplete.

2. **No silent dropping of requirements.** If a change invalidates an existing Gherkin rule, explicitly
   adjust/remove the scenario and explain why (e.g. in the commit/PR) — don't just leave it lying around while
   the code already does something else.

3. **German domain language is binding**, not cosmetic (see the glossary). A regenerating model must **not**
   replace terms like "Fixposten", "Kontotyp", or "Vermögenswerte" with a convenient English or more generic
   German alternative — that would break the "nearly identical" regeneration that's the purpose of this document.

4. **Adopt design tokens (colors, spacing, thresholds) exactly**, don't reinterpret them — they live in
   `constants.dart`/`theme.dart` and are documented in `CORPORATE_DESIGN.md` (colors) resp. here in Section 5/7
   (other tokens). Example: `kConcentrationRiskThreshold = 0.65`, `kAssetReevaluationDays = 182`,
   `kBackupReminderFirstDays = 182`, `kBackupReminderRepeatDays = 90` are functional decisions, not arbitrary defaults.

5. **Don't revert architecture decisions with a documented rationale without discussing it first**, including:
   - The exchange-rate cache in its own unencrypted file (not in the DB) — Section 4.1.
   - `usesDataProtectionKeychain: false` on macOS — Section 4.1.
   - Minimum OS versions are adopted from Flutter, without an own EOL list — Section 6.
   - App sandbox disabled on macOS — Section 4.1.
   - Window position is deliberately not saved — Section 4.3.
   - Splash duration 1100ms + 400ms crossfade — Section 5.
   - **No selectable storage location for the data file** — Section 4.1. Was built once and deliberately removed
     again; anyone proposing it again should read there first why it doesn't solve the use case.
   - Export password is optional, staying plaintext JSON without one — Section 4.1.
   - **No automatic backup.** Was worked through and rejected: it would need a per-session key derivation, a
     stored password, version retention, health monitoring, *and* a rework of the existing reminder ranking — and
     its typical failure mode (silently failed) only gets noticed when the backup is actually needed. Instead,
     the existing backup reminder leads to a manual export and explains the two things that matter: keep it
     outside this machine, and only the backup is portable (`AppState.getBackupReminder`).
   - No DB engine, a single JSON file — Section 2.
   - Schema-version guard on the startup load path (downgrade guard + `pre-migrate-backup` + golden-file fixture)
     — Section 4.1/4.2. The data file is the single source of truth; no new build may render existing data
     unreadable or lossily overwrite it.
   - Own Gherkin runner instead of `flutter_gherkin` — Section 8.
   These points typically also show up as a comment in the code; whoever removes the comment must also update the
   matching paragraph here (or vice versa).

6. **Formulate new functional requirements as a Gherkin scenario first**, then implement (spec-first), where
   practical — but at the very latest **in the same step as the implementation**, never "sometime later" after it.

7. **Order for a complete regeneration** (e.g. with a different AI model from scratch): data models
   (`lib/models/`) → `AppSchema`/`AppStore` (persistence+encryption) → `CurrencyService` → `AppState` →
   `theme.dart`/`constants.dart` → widgets (`lib/ui/widgets/`) → views (`lib/ui/views/`) → `navigation_shell.dart`
   → `main.dart`. Verify each stage against its `gherkin/*.feature` before starting the next.

8. **Never forget non-functional requirements**, even when they don't show up explicitly in any single Gherkin
   scenario: fully local (no automatic network beyond the exchange-rate API; the GitHub releases lookup for "Nach
   Updates suchen" is the one exception and runs only on explicit user action), encryption rests on the OS
   keychain, atomic writes, offline fallback for rates, no silent data destruction on broken/foreign files
   (always quarantine instead of overwrite).

9. **When code and docs disagree: ask, or reconcile both — don't guess.** If the current code deviates from this
   document, that's a sign the docs were forgotten on the last change — not that the code is automatically right.
