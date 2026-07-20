# Contributing

## Before you start

[AI_MASTER.md](AI_MASTER.md) is the source of truth for architecture, data models, conventions, and domain
language; [gherkin/](gherkin/) is the behavioral spec. Both are in German (see AI_MASTER §3 "Sprache der Doku") —
read both before making any non-trivial change, especially the "Regeln für KI-Agenten" section at the end of
AI_MASTER.md, which applies to human contributions too:

- German domain terms (Konto, Fixposten, Vermögenswerte, …) are mandatory, not cosmetic — never translate them,
  including in English prose.
- Documented architecture decisions (e.g. macOS keychain/sandbox settings, unencrypted rates cache) don't get
  reverted without discussion first — see [dev/architecture.md](dev/architecture.md).
- Any change to folder structure, architecture, data models, or view behavior updates AI_MASTER.md and the
  relevant `gherkin/*.feature` **in the same step**.

## Set up a dev environment

Platform setup (toolchain, Flutter SDK): [dev/setup.md](dev/setup.md).

```bash
flutter pub get
flutter run -d linux   # or -d macos / -d windows
```

## Workflow

1. **Spec-first:** write a Gherkin scenario for new behavior before or alongside the implementation. Navigate:
   AI_MASTER §8 Feature-Übersicht → feature file → its `# Implementierung:` file.
2. Implement, touching only the files that feature actually owns (see AI_MASTER "Regenerierung eines Features").
3. For new pure logic: add a `Scenario` in `gherkin/executable/*.feature` + an `s.step(...)` in `test/bdd/`.

## Checks before every commit

```bash
flutter analyze
flutter test
```

Both must pass — that's exactly what the `gate` job in `.github/workflows/release.yml` checks before every release.
`test/gherkin_sync_test.dart` fails fast and points at exactly which spec/code/test link broke, if docs and code
drift apart.

## Pull requests

- Small, focused changes.
- Explain the *why*, not just the *what* — commit messages get folded into `CHANGELOG.md` automatically.
- If the PR changes behavior, the updated `gherkin/*.feature` (and `AI_MASTER.md` where relevant) is part of the
  diff, not a follow-up.

## License

Contributions fall under the same license as the project: [GPL-3.0 with the Commons Clause addition](LICENSE).
