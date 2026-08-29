# FinanzGecko — Product & scope

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

FinanzGecko is a **native desktop net-worth tracker** (Flutter, Linux/macOS/Windows). No server, no cloud, no
account. Users create Konten (Girokonto, Depot, Krypto, …) and Vermögenswerte (physical assets), record monthly
Kontostände, maintain recurring income/expenses ("Fixposten"), and in return get a dashboard with net-worth
history, projection, distribution by Kontotyp, and Kennzahlen. All data is stored AES-256-GCM-encrypted in a
single JSON file in the OS data directory; the key lives in the OS credential store.

The entire UI is **in German** — that's a core feature, not an accident, and must be preserved on every
regeneration/extension (see the [glossary](glossary.md)).

**License:** source code public on GitHub (`kreativ-anders/finanzgecko`), licensed under **GPL-3.0 with a
"Commons Clause" addendum** (see [`LICENSE`](../../LICENSE)): copyleft like GPL — source freely viewable, modifiable,
and redistributable, derivatives must stay under the same terms — but the Commons Clause additionally prohibits
any **commercial** use (selling the software, or a product/service whose value derives predominantly from its
functionality). This is deliberately **not** OSI-approved "Open Source" in the strict sense (the Open Source
Definition forbids restrictions based on field of use) — on the website (`docs/index.html`) it's therefore
communicated as "quelloffen" plus its own FAQ answer with license details, not claimed uncommented as "Open
Source". The app itself stays free for end users (GitHub Releases); further development is instead funded through
voluntary "pay what you want" support via Stripe on the website (section "Entwicklung unterstützen").
