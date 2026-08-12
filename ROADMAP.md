# Roadmap

What's planned for FinanzGecko. No dates, no promises.

## Publishing

Downloads are currently unsigned, so macOS and Windows show a security warning on first start.

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
- [ ] Update the website once a signed release is out — the install FAQ and the download page still say the app is unsigned, which stays true until then (and stays true for Windows longer)

## Next

- [ ] Assisted update — "Nach Updates suchen" downloads the right file for your system, checks it against the
      published checksum and hands it over ready to install. Still only when you ask for it; the app never checks
      in the background
- [ ] Optional: run the app sandboxed on macOS — extra protection, but it moves where the data file lives, so it needs its own migration step
- [ ] Drawdown from peak — how far below the all-time high
- [ ] Currency exposure — EUR vs. foreign share
- [ ] English UI

Ideas and feedback: [open an issue](https://github.com/kreativ-anders/finanzgecko/issues).
