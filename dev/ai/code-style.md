# FinanzGecko — Comments, code language & static analysis

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

## Comment vs. documentation — where the line is

A comment answers **"why is this line the way it is"** for someone who's already reading this function. Anything
that answers **"how is this app built"** belongs in `dev/ai/`, and the comment turns into a one-liner with a
pointer (`See dev/ai/persistence.md.`).

The reason isn't aesthetics: explaining the same decision in two places means maintaining it in two places — and
nothing checks whether both still agree. The comment layer once grew to ~11,000 words, mostly architecture
rationale that already lived here in more detail.

Practical rules:

- A Dartdoc block over **8 lines** needs a reason. Headings (`## Why this exists`) **inside** a comment are the
  signal that it has turned into documentation — move it into the matching `dev/ai/` file.
- Don't shorten comments that name a concrete failure case, carry a measurement date ("measured on 2026-08-13"),
  or explain why something is **deliberately** not done (e.g. the deliberately *non*-constant-time checksum
  comparison in `utils/update_assets.dart`). Those are the comments whose absence costs someone hours.
- Restatements of what the code obviously does: delete outright.

## Language

Comments and Dartdoc are **English** — matching `README.md`, `ROADMAP.md`, and `CONTRIBUTING.md`. Before this,
the mix was inconsistent, sometimes within the same file (`app_store.dart`, `settings_view.dart`), which kept
switching modes while reading.

**Exempt and staying German:** the domain terms from [glossary.md](glossary.md) (Konto, Kontostand, Kontotyp, Fixposten,
Vermögenswerte, Basiswährung, Kennzahlen, …) as well as literally-quoted UI text ("Nach Updates suchen", "Noch nie
exportiert"). Translating them breaks regenerability — see Rule 3 below.

The prose in `docs/` stays German — it addresses the app's German-speaking end users directly, unlike this
document and `gherkin/`, which are AI/developer-facing and were translated to English (see the "Doc language"
note in [structure.md](structure.md) for the full split, and Rule 3 below for why the domain terms inside them still don't translate).

**Also English: the text of GitHub releases** (`release.yml`, step "Prüfsummen erzeugen"). It sits on github.com
right next to README/ROADMAP/CONTRIBUTING and has the same audience — v1.9.0 still shipped with a German
checksums section. Step names and comments *inside* the workflows stay German; only someone opening the Actions
view sees those.

## `analysis_options.yaml`

The rule list is deliberately longer than the Flutter template: every entry replaces something a human would
otherwise have to notice in review — the same logic as `test/docs_consistency_test.dart` for prose. Deliberately
**not** enabled: `avoid_dynamic_calls` (the JSON paths in `data/` are intentionally dynamic, see
`app_schema.dart`), `require_trailing_commas` (the formatter adds them anyway), and `public_member_api_docs`
(this is an app, not a package).

After a change to this file: `dart fix --apply && dart format . && flutter analyze && flutter test`.

## Register of claims stated in more than one place

These statements appear in more than one place. If one changes, **all** of them need updating. The ones marked ⚙
are checked mechanically by `test/docs_consistency_test.dart`; the rest are manual — and candidates for the next
test, once they drift apart even once.

| Claim | Locations |
|---|---|
| ⚙ Which network connections the app makes at all | `docs/index.html` (feature card), `docs/llms.txt`, `docs/datenschutz.html`, [platform.md](platform.md), `services/currency_service.dart`, `services/update_service.dart` |
| ⚙ Whether there's an update check in the app and what it does | `docs/index.html` (FAQ + JSON-LD), `docs/download.html`, `README.md`, `ROADMAP.md`, `docs/datenschutz.html`, `docs/llms.txt`, `gherkin/settings.feature` |
| ⚙ Backups can be password-protected | `docs/documentation.html`, `ui/backup_actions.dart`, `data/backup_crypto.dart`, [glossary.md](glossary.md) glossary |
| ⚙ macOS is signed and notarized — only Windows warns | `README.md`, `ROADMAP.md`, `docs/index.html` (FAQ), `docs/download.html` (cards) |
| ⚙ File-name suffixes of the release assets | `utils/update_assets.dart`, `.github/workflows/release.yml`, `docs/download.html` |
| ⚙ The data file's storage location per OS | `data/app_store.dart`, [persistence.md](persistence.md), `dev/setup.md`, `docs/datenschutz.html` |
| Which crypto implementation the app uses, and the export-compliance answer that rests on it | `macos/Runner/Info.plist`, [persistence.md](persistence.md), `dev/app-store.md` [state-and-models.md](state-and-models.md), `dev/native-libraries.md`, `data/crypto_platform.dart`, `data/apple_pbkdf2.dart`, `gherkin/data_security.feature` |
| ⚙ The list of Kennzahlen | `ui/views/dashboard_view.dart`, `docs/index.html`, `docs/documentation.html`, [glossary.md](glossary.md) glossary |
| ⚙ The sections of Einstellungen | `ui/views/settings_view.dart`, `docs/documentation.html`, `gherkin/settings.feature` |
| Desktop notifications are opt-in (off by default) and macOS asks for authorization exactly once, when the toggle is switched on | `ui/views/settings_view.dart`, `state/app_state.dart`, `services/notification_service.dart`, `data/app_schema.dart`, [persistence.md](persistence.md) + [ui-conventions.md](ui-conventions.md), `docs/documentation.html`, `gherkin/settings.feature`, `gherkin/notifications.feature` |
| The page's opening stays free of jargon | `docs/index.html` (`<h1>` + `.pitch`) — `<title>`/meta are deliberately allowed to keep the platform keywords |
