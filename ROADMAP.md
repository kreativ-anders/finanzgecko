# Roadmap

What's planned for FinanzGecko. Quarters are intent, not promises.

## Currently working on

- **v1.8 — sandboxed macOS release.** All macOS builds now run in the App Sandbox; existing data is copied into
  the container once on first launch.

## On hold

- **Mac App Store.** Not worth the added complexity right now. Groundwork stays in the repo
  (`packaging/macos/build_appstore.sh`, `AppStore.entitlements`), costs nothing unused.
- **Windows — signed installer.** Certificate costs money yearly and, unlike macOS, doesn't remove the SmartScreen
  warning — just softens it. The cheap option (Azure Artifact Signing, ~$10/mo) isn't open outside US/Canada.
- **Linux — Flathub.** No urgency (Linux shows no warning anyway), and Flathub no longer accepts apps with
  AI-assisted code.

## Planned

**Q4 2026**

- **Replace `local_notifier` with `flutter_local_notifications`.** The current plugin was last published in April
  2024: no Swift Package Manager support, and on macOS it calls `NSUserNotification`, deprecated since macOS 11.
  Flutter still falls back to CocoaPods, but that registry goes read-only on 2026-12-02, and if Apple drops the old
  API the reminders stop firing silently. The replacement is maintained and covers all three platforms. **Decide
  first:** the modern macOS API needs user authorization, so this adds a permission prompt where there is none —
  a real change for an app that otherwise asks for nothing. Touches `notification_service.dart` and
  `gherkin/notifications.feature`.
- Drawdown from peak (how far below all-time high).
- Currency exposure (EUR vs. foreign share).
- **winget** — manifests + release automation already in repo; first submission to `microsoft/winget-pkgs` still
  manual. Doesn't remove SmartScreen, but builds download-reputation over time.
- **Get listed** — heise Download, AlternativeTo, Product Hunt. Free, and SmartScreen reputation is earned by
  download volume, not bought.
- **AUR** — PKGBUILD wrapping the AppImage. Lives in its own repo on aur.archlinux.org, doesn't touch this repo.

**2027**

- English UI.
- **Homebrew Cask** — blocked on Homebrew's notability rules (75 stars/30 forks/30 watchers, or 225 stars for
  self-submission; a self-hosted tap needs explicit user trust so doesn't really help). Revisit at 75 stars.
- **Q3 2027 — remove sandbox migration.** `lib/data/sandbox_migration.dart` + the `temporary-exception`
  entitlement were added in v1.8 as deliberate, dated debt — drop them once pre-sandbox installs are rare. That
  entitlement is the only outside-container read access, so removing it tightens the sandbox. Deleting anyone's
  old files is a separate, later decision.

## Done

- **macOS — signed & notarized.** DMG (carries the notarization ticket), Developer ID, Hardened Runtime, stapled
  in CI.
- **macOS — sandboxed** (v1.8). Existing data copied into the container on first launch; old files kept as fallback.
- **Checksums** — every release ships `SHA256SUMS`, hashes repeated in release notes.
- **Assisted update** — "Nach Updates suchen" downloads the right file, verifies checksum, hands off ready to
  install. Only on request, never in the background.
- **Website** — install instructions and privacy page match the signed builds.

Ideas and feedback: [open an issue](https://github.com/kreativ-anders/finanzgecko/issues).
