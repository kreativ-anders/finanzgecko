# FinanzGecko — Comments, code language & static analysis

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

## Comment vs. documentation — where the line is

A comment answers **"why is this line the way it is"** for someone who's already reading this function. Anything
that answers **"how is this app built"** belongs in `dev/ai/`, and the comment turns into a one-liner with a
pointer (`See dev/ai/persistence.md.`).

The reason isn't aesthetics: explaining the same decision in two places means maintaining it in two places — and
nothing checks whether both still agree. The comment layer once grew to ~11,000 words, mostly architecture
rationale that already lived here in more detail.

## The four tags

Every comment that survives a trim is either **tagged** or a **single line** stating why that line is the way it
is. There is no third category: a multi-line untagged paragraph in the code is the thing this rule exists to
prevent (the comment layer once grew to ~11,000 words).

| Tag | Means | Example |
|---|---|---|
| `// WARNING:` | Touching this breaks something concrete, elsewhere, silently. Names the failure. | `// WARNING: order matters — notifyListeners() before the await drops the pending edit.` |
| `// TODO:` | Future work, with the condition that makes it due. | `// TODO: drop once the macOS 12 floor lands (see dev/ai/platform.md).` |
| `// INFO:` | A non-obvious fact or a deliberate decision, including pointers into `dev/ai/`. | `// INFO: rate frozen at entry time on purpose — see dev/ai/persistence.md.` |
| `// DEBUG:` | Diagnostics, temporary instrumentation, debug-only branches. | `// DEBUG: kDebugMode only — never reached in a release build.` |

Rules for the tags:

- **Uppercase, colon, then the point in one sentence.** No tag stacking, no `TODO(name)` owners — git blame has
  the owner.
- A `TODO` without a condition ("someday nicer") is not a TODO; delete it.
- `WARNING` is for a failure someone can actually cause. If nothing breaks, it is `INFO` or nothing at all.
- Dartdoc (`///`) stays what it is — a one-line summary of a public member. If it needs a warning, the warning is
  its own `// WARNING:` line above the member, not a paragraph inside the doc block.
- Tags are for code. `dev/ai/` never uses them: prose there is documentation, not a flag.

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

**One exception inside `docs/`: `docs/privacy.html`**, the full English equivalent of `docs/datenschutz.html`.
It exists because the winget policy review (Policies 1.5.1/1.5.5) asks an app that stores financial data for a
privacy policy its reviewers can read, and it is the `PrivacyUrl` of the en-US manifest. Both pages carry the
same Part A / Part B structure and state the same facts; when one changes, the other changes in the same commit.

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
| ⚙ Which network connections the app makes at all | `docs/index.html` (feature card), `docs/llms.txt`, `docs/datenschutz.html` (B3), `docs/privacy.html` (B3), [platform.md](platform.md), `services/currency_service.dart`, `services/update_service.dart` |
| ⚙ Whether there's an update check in the app and what it does | `docs/index.html` (FAQ + JSON-LD), `docs/download.html`, `README.md`, `ROADMAP.md`, `docs/datenschutz.html` (B3), `docs/privacy.html` (B3), `docs/llms.txt`, `gherkin/settings.feature` |
| ⚙ Backups can be password-protected | `docs/documentation.html`, `docs/datenschutz.html` (B2), `docs/privacy.html` (B2), `ui/backup_actions.dart`, `data/backup_crypto.dart`, [glossary.md](glossary.md) |
| ⚙ macOS is signed and notarized — only Windows warns | `README.md`, `ROADMAP.md`, `docs/index.html` (FAQ), `docs/download.html` (cards) |
| ⚙ File-name suffixes of the release assets | `utils/update_assets.dart`, `.github/workflows/release.yml`, `docs/download.html` |
| ⚙ The data file's storage location per OS | `data/app_store.dart`, [persistence.md](persistence.md), `dev/setup.md` — deliberately NOT on the privacy pages any more, which only say the data sits on the user's own computer |
| The privacy policy URLs published in the winget manifests | `docs/datenschutz.html` + `docs/privacy.html` (the pages themselves), `packaging/windows/winget/KreativAnders.FinanzGecko.locale.*.yaml` (`PrivacyUrl`), `docs/sitemap.xml`, `docs/llms.txt` — renaming either page breaks a manifest already published in `microsoft/winget-pkgs` |
| Which crypto implementation the app uses, and the export-compliance answer that rests on it | `macos/Runner/Info.plist`, [persistence.md](persistence.md), `dev/app-store.md` §4, `dev/native-libraries.md`, `data/crypto_platform.dart`, `data/apple_pbkdf2.dart`, `gherkin/data_security.feature` |
| ⚙ The list of Kennzahlen | `ui/views/dashboard_view.dart`, `docs/index.html`, `docs/documentation.html`, [glossary.md](glossary.md) |
| ⚙ The sections of Einstellungen | `ui/views/settings_view.dart`, `docs/documentation.html`, `gherkin/settings.feature` |
| Desktop notifications are opt-in (off by default) and macOS asks for authorization exactly once, when the toggle is switched on | `ui/views/settings_view.dart`, `state/app_state.dart`, `services/notification_service.dart`, `data/app_schema.dart`, [persistence.md](persistence.md) + [ui-conventions.md](ui-conventions.md), `docs/documentation.html`, `gherkin/settings.feature`, `gherkin/notifications.feature` |
| The page's opening stays free of jargon | `docs/index.html` (`<h1>` + `.pitch`) — `<title>`/meta are deliberately allowed to keep the platform keywords |
