# FinanzGecko — Repo Instructions

[AI_MASTER.md](AI_MASTER.md) is the source of truth for architecture, tech stack, data flow, UI conventions, and
domain language. [gherkin/](gherkin/) holds the behavioral spec as Gherkin features. Read both before making any
non-trivial change, and follow the "Regeln für KI-Agenten" section at the bottom of AI_MASTER.md — in particular:
keep AI_MASTER.md and the relevant `gherkin/*.feature` in sync with any change to folder structure, architecture,
data models, or view behavior; never translate the German domain terms (Konto, Fixposten, Vermögenswerte, …); don't
revert a documented architecture decision (e.g. macOS keychain/sandbox settings, unencrypted rates cache) without
discussing it first.

@AI_MASTER.md
