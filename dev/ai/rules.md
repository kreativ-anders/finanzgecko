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
     architecture decisions without discussion first, doc-sync obligation, `flutter analyze`/`flutter test`
     after every change) → update the rules block in [`CLAUDE.md`](../../CLAUDE.md). That is the only copy;
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
   - `usesDataProtectionKeychain: false` on macOS — [persistence.md](persistence.md).
   - Minimum OS versions are adopted from Flutter, without an own EOL list — [platform.md](platform.md).
   - App sandbox disabled on macOS — [persistence.md](persistence.md).
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
   scenario: fully local (no automatic network beyond the exchange-rate API; the GitHub releases lookup for "Nach
   Updates suchen" is the one exception and runs only on explicit user action), encryption rests on the OS
   keychain, atomic writes, offline fallback for rates, no silent data destruction on broken/foreign files
   (always quarantine instead of overwrite).

9. **When code and docs disagree: ask, or reconcile both — don't guess.** If the current code deviates from this
   document, that's a sign the docs were forgotten on the last change — not that the code is automatically right.
