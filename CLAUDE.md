# FinanzGecko — Repo Instructions

[AI_MASTER.md](AI_MASTER.md) is the source of truth for architecture, tech stack, data flow, UI conventions, and
domain language. [gherkin/](gherkin/) holds the behavioral spec as Gherkin features. Read both before making any
non-trivial change, and follow the "Regeln für KI-Agenten" section at the bottom of AI_MASTER.md — in particular:
keep AI_MASTER.md and the relevant `gherkin/*.feature` in sync with any change to folder structure, architecture,
data models, or view behavior; never translate the German domain terms (Konto, Fixposten, Vermögenswerte, …); don't
revert a documented architecture decision (e.g. macOS keychain/sandbox settings, unencrypted rates cache) without
discussing it first.

## Working efficiently in this repo (for AI agents)

**Navigate, don't scan.** To change a behavior: find it in AI_MASTER **§8 Feature-Übersicht** → open that feature's
`# Quelle:` files → find its test via the §8 table or `grep "// Gherkin: <feature>"`. Edit only that narrow set.

**Keep the layering.** Pure, testable logic lives in `lib/utils/analysis.dart` and `lib/constants.dart`; views stay
thin. For new pure behavior, add a `Scenario` in `gherkin/executable/*.feature` + one `s.step(...)` in `test/bdd/`.

**Always verify:** run `flutter analyze` and `flutter test` after every change (the release gate runs the same, plus
the icon pipeline). The guard `test/gherkin_sync_test.dart` fails fast and points at exactly which spec/code/test link
broke — read its message before hunting.

**Keep docs in sync** (AI_MASTER.md + `gherkin/`) with every change, and don't revert a documented decision (see
AI_MASTER "Regeln für KI-Agenten") without asking.

@AI_MASTER.md
