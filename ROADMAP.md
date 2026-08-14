# Roadmap

What's planned for FinanzGecko. No dates, no promises.

## Publishing

macOS downloads are signed and notarized — no warning. Windows still shows one on first start.

- [x] macOS — signed & notarized
  - [x] Ship a `.dmg` instead of a zipped app bundle (a `.dmg` can carry the notarization ticket)
  - [x] Developer ID certificate
  - [x] Enable Hardened Runtime — required for notarization. The app stays unsandboxed for now
  - [x] Check that the encryption key in the Keychain still works after signing, so existing data keeps opening
  - [x] Notarize and staple in CI
- [ ] Windows — signed installer. Postponed for now: a certificate costs money every year, and unlike macOS it does
      not remove the warning — it only turns the SmartScreen block into a one-click "run anyway" that fades as
      downloads accumulate. The cheap cloud option (Azure Artifact Signing, ~$10/month) is not open to individual
      developers outside the US and Canada
- [x] Checksums — every release ships a `SHA256SUMS` file and lists the hashes in the release notes
- [ ] Linux — nothing urgent: there is no security warning on Linux. Flathub is postponed, since it no longer
      accepts applications containing AI-assisted code, and FinanzGecko is developed with AI assistance
- [x] Website — install instructions and the privacy page match the signed builds

## Next

- [x] Assisted update — "Nach Updates suchen" downloads the right file for your system, checks it against the
      published checksum and hands it over ready to install. Still only when you ask for it; the app never checks
      in the background
- [ ] Mac App Store — one-time purchase, updates handled by the store. Groundwork is in place
      (`packaging/macos/build_appstore.sh`, sandboxed `AppStore.entitlements`, `kIsMacAppStore`); still missing
      are the App Store distribution certificate, the provisioning profile, the App Store Connect record and the
      paid-apps agreement. The free download here stays free — the store version buys convenience, not features
- [x] Sandbox every macOS build — extra protection, and the precondition for the App Store. Existing data is
      copied into the container once, on first launch; the old files stay where they are as a fallback
- [ ] Remove the migration again (earliest ~2027-08, one year after v1.8) — drop
      `lib/data/sandbox_migration.dart`, its test and the `temporary-exception` entitlement in one commit. That
      entitlement is the only thing letting the app read anything outside its container, so removing it strictly
      tightens the sandbox. Deleting users' old files is a separate, later question — doing it in the release
      that first copies them would make a bad copy unrecoverable
- [ ] Drawdown from peak — how far below the all-time high
- [ ] Currency exposure — EUR vs. foreign share
- [ ] English UI

Ideas and feedback: [open an issue](https://github.com/kreativ-anders/finanzgecko/issues).
