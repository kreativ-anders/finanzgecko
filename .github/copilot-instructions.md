# FinanzGecko — Repo Instructions (for GitHub Copilot)

This file is a **thin pointer**, not a separate spec: [AI_MASTER.md](../AI_MASTER.md) is the source of truth for
architecture, tech stack, data flow, UI conventions, and domain language; [CORPORATE_DESIGN.md](../CORPORATE_DESIGN.md)
mirrors its visual-identity tokens for a design/marketing audience; [gherkin/](../gherkin/) holds the behavioral
spec. Read all three before making any non-trivial change. [CLAUDE.md](../CLAUDE.md) carries the full day-to-day
working instructions (navigation shortcuts, regeneration recipes, website traps) — despite the name it isn't
Claude-specific; read it too.

## Non-negotiable rules

- **Never translate the German domain terms** (Konto, Fixposten, Vermögenswerte, …) — see AI_MASTER §7.
- **Don't revert a documented architecture decision** (e.g. macOS keychain/sandbox settings, unencrypted rates
  cache, no selectable data-file location) without discussing it first — see AI_MASTER "Regeln für KI-Agenten" #5.
- **Keep AI_MASTER.md, CORPORATE_DESIGN.md, and the relevant `gherkin/*.feature` in sync** with any change to
  folder structure, architecture, data models, view behavior, or design tokens.
- **Run `flutter analyze` and `flutter test` after every change.**

## Keeping this file in sync

This file only restates the rules above; everything else lives once in CLAUDE.md. If those rules change, update
the matching section here and in the other sibling AI-instruction files — see AI_MASTER §3 for the current list and
"Regeln für KI-Agenten" #1.
