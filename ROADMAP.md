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
- [ ] Linux — checksums for the AppImage, maybe Flathub
- [ ] Windows — signed installer
- [ ] Update the website once a signed release is out — the install FAQ and the download page still say the app is unsigned, which stays true until then (and stays true for Windows longer)

## Next

- [ ] Automatic updates (needs signing first)
- [ ] Optional: run the app sandboxed on macOS — extra protection, but it moves where the data file lives, so it needs its own migration step
- [ ] Drawdown from peak — how far below the all-time high
- [ ] Currency exposure — EUR vs. foreign share
- [ ] English UI

Ideas and feedback: [open an issue](https://github.com/kreativ-anders/finanzgecko/issues).
