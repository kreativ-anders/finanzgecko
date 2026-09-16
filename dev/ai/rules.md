# FinanzGecko — Rules for AI agents (mandatory)

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

These rules apply to **any AI** working on this repository — whether extending the existing app or regenerating a
new instance from these documents.

1. **The `dev/ai/` set, `CORPORATE_DESIGN.md`, and `gherkin/` are a mandatory part of every change, not optional.**
   If a task changes the folder structure, the architecture, a data model, a constant with functional meaning
   (e.g. `kBackupReminderFirstDays`), or a view's behavior → **in the same work step**:
   - Update [structure.md](structure.md) (folder structure) if files/folders were added/removed.
   - Update [state-and-models.md](state-and-models.md), [persistence.md](persistence.md) or
     [ui-conventions.md](ui-conventions.md) if data flow, schema, or conventions change.
   - Update `CORPORATE_DESIGN.md` if a color, a color token, or the typography changes.
   - Add or correct the new/changed scenario in the matching `.feature` file under `gherkin/`.
   - On a new German domain term: extend [glossary.md](glossary.md) (glossary).
   - If one of the **non-negotiable rules** changes (currently: German domain language, not reverting
     architecture decisions without discussion first, doc-sync obligation, the security rules in #9,
     `flutter analyze`/`flutter test` after every change) → update the rules block in [`CLAUDE.md`](../../CLAUDE.md). That is the only copy;
     there are deliberately no per-tool pointer files. A new tool gets pointed at `CLAUDE.md`, never a copy
     of the rules.
   A change to production code **without** an accompanying doc update counts as incomplete.

2. **No silent dropping of requirements.** If a change invalidates an existing Gherkin rule, explicitly
   adjust/remove the scenario and explain why (e.g. in the commit/PR) — don't just leave it lying around while
   the code already does something else.

3. **German domain language is binding**, not cosmetic (see the glossary). A regenerating model must **not**
   replace terms like "Fixposten", "Kontotyp", or "Vermögenswerte" with a convenient English or more generic
   German alternative — that would break the "nearly identical" regeneration that's the purpose of these documents.

4. **Adopt design tokens (colors, spacing, thresholds) exactly**, don't reinterpret them — they live in
   `constants.dart`/`theme.dart` and are documented in `CORPORATE_DESIGN.md` (colors) resp. in
   [design-tokens.md](design-tokens.md) and [glossary.md](glossary.md) (other tokens). Example: `kConcentrationRiskThreshold = 0.65`, `kAssetReevaluationDays = 182`,
   `kBackupReminderFirstDays = 182`, `kBackupReminderRepeatDays = 90` are functional decisions, not arbitrary defaults.

5. **Don't revert architecture decisions with a documented rationale without discussing it first**, including:
   - The exchange-rate cache in its own unencrypted file (not in the DB) — [persistence.md](persistence.md).
   - `usesDataProtectionKeychain: kIsMacAppStore` on macOS (classic keychain for the DMG build, data-protection
     keychain only for the App Store build) — [persistence.md](persistence.md).
   - Minimum OS versions are adopted from Flutter, without an own EOL list — [platform.md](platform.md).
   - App sandbox **enabled** in every macOS build since v1.8 (reversing the earlier "disabled" decision; the
     pre-sandbox data is copied once by `SandboxMigration`) — [persistence.md](persistence.md).
   - Window position is deliberately not saved — [state-and-models.md](state-and-models.md).
   - Splash duration 1100ms + 400ms crossfade — [ui-conventions.md](ui-conventions.md).
   - **No selectable storage location for the data file** — [persistence.md](persistence.md). Was built once and deliberately removed
     again; anyone proposing it again should read there first why it doesn't solve the use case.
   - Export password is optional, staying plaintext JSON without one — [persistence.md](persistence.md).
   - **No automatic backup.** Was worked through and rejected: it would need a per-session key derivation, a
     stored password, version retention, health monitoring, *and* a rework of the existing reminder ranking — and
     its typical failure mode (silently failed) only gets noticed when the backup is actually needed. Instead,
     the existing backup reminder leads to a manual export and explains the two things that matter: keep it
     outside this machine, and only the backup is portable (`AppState.getBackupReminder`).
   - No DB engine, a single JSON file — [stack.md](stack.md).
   - Schema-version guard on the startup load path (downgrade guard + `pre-migrate-backup` + golden-file fixture)
     — [persistence.md](persistence.md). The data file is the single source of truth; no new build may render existing data
     unreadable or lossily overwrite it.
   - Own Gherkin runner instead of `flutter_gherkin` — [testing.md](testing.md).
   These points typically also show up as a comment in the code; whoever removes the comment must also update the
   matching paragraph here (or vice versa).

6. **Formulate new functional requirements as a Gherkin scenario first**, then implement (spec-first), where
   practical — but at the very latest **in the same step as the implementation**, never "sometime later" after it.

7. **Order for a complete regeneration** (e.g. with a different AI model from scratch): data models
   (`lib/models/`) → `AppSchema`/`AppStore` (persistence+encryption) → `CurrencyService` → `AppState` →
   `theme.dart`/`constants.dart` → widgets (`lib/ui/widgets/`) → views (`lib/ui/views/`) → `navigation_shell.dart`
   → `main.dart`. Verify each stage against its `gherkin/*.feature` before starting the next.

8. **Never forget non-functional requirements**, even when they don't show up explicitly in any single Gherkin
   scenario: fully local (**no network without an explicit user decision** — the exchange-rate API only after the
   opt-in consent, the GitHub releases lookup only on a click on "Nach Updates suchen"), encryption rests on the
   OS keychain, atomic writes that never delete the data file first, offline fallback for rates, no silent data
   destruction on broken/foreign files (always quarantine instead of overwrite — and if the quarantine copy
   fails, stop instead of overwriting).

9. **Security and robustness rules** — they apply to every change, not just to files that look security-related:
   - **Everything from outside is untrusted input:** backup files (plaintext or encrypted, including their KDF
     parameters), the data file's plaintext envelope fields, HTTP responses. Validate before any state changes,
     bound every number that controls work or memory, and prefer skipping/rejecting to crashing later. Import
     rules: `lib/data/import_validation.dart`.
   - **Never log user data outside `kDebugMode`:** no amounts, names, currency pairs, paths or key material via
     `debugPrint`/`print` — `debugPrint` is not stripped from release builds and reaches the OS log.
   - **A new key, a delete, or an overwrite is the last step, never the first:** store a generated key only once
     nothing existing depends on the old one; copy before overwrite and abort if the copy fails; never delete a
     file before its replacement is in place.
   - **CI:** third-party GitHub Actions are pinned to a full commit SHA (with the tag as a comment); secrets are
     passed to the individual step that needs them, never at job level; `permissions` default to `contents: read`
     and are raised per job; `${{ inputs.* }}` never goes straight into a `run:` script — through `env:` instead.
   - **A documented security property needs a test** (or a Gherkin scenario backed by one). A property that only
     lives in prose will be "simplified" away by the next regeneration.

10. **When code and docs disagree: ask, or reconcile both — don't guess.** If the current code deviates from this
   document, that's a sign the docs were forgotten on the last change — not that the code is automatically right.
