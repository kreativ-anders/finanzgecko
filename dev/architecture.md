# Architecture decisions

For the full architecture/data-flow/domain reference see [AI_MASTER.md](../AI_MASTER.md). This file only covers
the decisions that tend to raise questions.

## Why no database engine

A single JSON file in the OS data directory, no SQLite/Hive/Isar dependency. For the data volume of a personal
net-worth tracker (a few hundred balance entries) "read/write the whole file" is entirely sufficient and keeps the
code simple.

**File path:** `<data directory>/finanzgecko-data.json` (per-OS directory: [setup.md](setup.md)).

- **Encryption:** AES-256-GCM (`lib/data/app_store.dart`, `lib/data/secure_key_store.dart`). The key lives in the
  OS credential store (Windows Credential Locker, macOS Keychain, Linux libsecret/kwallet), generated once per
  installation.
- Only a genuine envelope file is accepted as a data source; anything else is quarantined under
  `*.unreadable-<timestamp>` before being overwritten, and the app starts with defaults.
- File permissions as an extra layer: `chmod 0700`/`0600` (Linux/macOS), ACL via `icacls` (Windows).
- Exchange rates (public ECB reference rates) live deliberately **outside** the encrypted file, in plaintext
  `finanzgecko-rates.json` next to it — caching a freshly fetched rate doesn't trigger a full re-encrypt of the
  database. All writes go through a shared queue.

**macOS — two deliberate, non-obvious settings:**

- `SecureKeyStore` uses `MacOsOptions(usesDataProtectionKeychain: false)`. The plugin default (`true`) binds the
  key entry to the code signature's team ID — on an unsigned/ad-hoc-signed build (no Apple Developer team), the
  first key access fails with `PlatformException(..., -34018, "A required entitlement isn't present.")`. Without
  the team-ID binding it also works without a certificate.
- App Sandbox is disabled (`com.apple.security.app-sandbox = false`, both `.entitlements` files) — with sandbox
  active, macOS virtualizes `$HOME` for the process to a container path, so `resolveDataDirectory()` would miss the
  documented path and any data already stored there would become unreachable.

Neither setting should be reverted without discussion first (see AI_MASTER "Rules for AI Agents").

## Schema migration on startup

`ensureInitialized()` compares the decrypted data file's `schemaVersion` against `currentSchemaVersion` on every
launch:

- **Newer than this build (downgrade):** the file is quarantined untouched as `*.newer-version-<timestamp>`, the
  app starts with defaults. A matching app update makes the data readable again.
- **Older than this build (forward migration):** a byte-exact copy of the still-encrypted file is saved first as
  `pre-migrate-backup-<timestamp>.json`, then the in-memory schema is stamped to `currentSchemaVersion` and
  rewritten immediately.

This runs automatically on first launch after an update — **a normal upgrade needs no manual export/import**, just
install the new release and start it. Export/Import (see [troubleshooting.md](troubleshooting.md)) is for moving to
a new device or making a manual backup, not for upgrading in place.

## Window behavior

Starts at the last-used size (default 1280×860, minimum 960×640, `window_manager`) plus maximized state. Screen
position is deliberately **not** saved — otherwise the window could land outside the visible area after a
monitor/resolution change.

## In-app menu instead of a native menu bar

Flutter's `PlatformMenuBar` only supports macOS. Linux/Windows get a "Datei" menu entry in the app's own window
header instead (identical across platforms), plus global keyboard shortcuts (<kbd>Strg</kbd>/<kbd>Cmd</kbd>+
<kbd>E</kbd>/<kbd>I</kbd>/<kbd>Q</kbd>).
