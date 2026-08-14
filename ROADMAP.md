# Roadmap

What's planned for FinanzGecko. Quarters are intent, not promises.

## Currently working on

- **Mac App Store** — one-time purchase, updates handled by the store. The free download here stays free; the
  store version buys convenience, not features. Groundwork is in place (`packaging/macos/build_appstore.sh`,
  `AppStore.entitlements`, the sandbox); still missing are the distribution certificate, the provisioning
  profile, the App Store Connect record and the paid-apps agreement.

## On hold

- **Windows — signed installer.** A certificate costs money every year and, unlike on macOS, does not remove the
  warning: it only turns the SmartScreen block into a one-click "run anyway" that fades as downloads accumulate.
  The cheap cloud option (Azure Artifact Signing, ~$10/month) is not open to individual developers outside the
  US and Canada.
- **Linux — Flathub.** Nothing urgent, since Linux shows no security warning in the first place. Flathub no
  longer accepts applications containing AI-assisted code, and FinanzGecko is openly developed with AI
  assistance.

## Planned

**Q4 2026**

- Drawdown from peak — how far below the all-time high.
- Currency exposure — EUR vs. foreign share.

**2027**

- English UI.
- **Q3 2027 — remove the sandbox migration.** Introduced in v1.8 (August 2026) as deliberate, dated technical
  debt: `lib/data/sandbox_migration.dart`, its test and the `temporary-exception` entitlement go together in one
  commit, once pre-sandbox installations have become rare. That entitlement is the only thing letting the app
  read anything outside its own container, so dropping it strictly tightens the sandbox. Deleting anyone's old
  files is a separate, later question — doing it in the release that first copies them would make a bad copy
  unrecoverable.

## Done

- **macOS — signed and checked by Apple.** DMG instead of a zipped bundle (a DMG can carry the ticket),
  Developer ID certificate, Hardened Runtime, stapled in CI. Existing data keeps opening afterwards.
- **macOS — sandboxed** (v1.8). Every build runs in the App Sandbox. Existing data is copied into the container
  once on first launch; the old files stay where they are as a fallback.
- **Checksums** — every release ships a `SHA256SUMS` file and repeats the hashes in the release notes.
- **Assisted update** — "Nach Updates suchen" downloads the right file for your system, verifies it against the
  published checksum and hands it over ready to install. Only when you ask; never in the background.
- **Website** — install instructions and the privacy page match the signed builds.

Ideas and feedback: [open an issue](https://github.com/kreativ-anders/finanzgecko/issues).
