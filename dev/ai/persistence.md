# FinanzGecko — Persistence, encryption & schema

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

## Persistence (`lib/data/app_store.dart`)

- **One file per installation**, no DB server: `finanzgecko-data.json` in the OS data directory (`AppStore.resolveDataDirectory()`).
  - Linux: `~/.local/share/de.finanzgecko.app/` (or `$XDG_DATA_HOME`)
  - macOS: `~/Library/Containers/de.finanzgecko.app/Data/Library/Application Support/FinanzGecko/`
    (sandbox container from v1.8 on; before that `~/Library/Application Support/de.finanzgecko.app/` — the
    migration in `persistence.md` copies over once). **The folder is deliberately named `FinanzGecko` on macOS, not the
    application ID**: a folder name ending in `.app` reads to Finder as an app bundle (generic icon, kind
    "Programm", double-click reports "beschädigt oder unvollständig"). Linux and Windows keep
    `de.finanzgecko.app`, where the suffix is meaningless and reverse-DNS is conventional.
  - Windows: `%APPDATA%\de.finanzgecko.app\`
- **The storage location is deliberately NOT selectable.** A folder picker was designed, built, and removed
  again: the only reason to want one is "then my file sits in a folder my cloud backs up" — and that's exactly
  what it doesn't deliver. The key is device-bound in the OS keychain; after a disk failure or on a new machine,
  even the nicest cloud copy is no longer openable (exception: a full system restore that brings the keychain
  along). Such a dialog would therefore promise a safety it doesn't have. Recoverable backups run exclusively
  through **export** (see below). The rationale is additionally documented as a doc comment on
  `resolveDataDirectory()` and in plain language under Einstellungen → Sicherheit.
- **Encryption:** AES-256-GCM "envelope" (`{v, keyId, nonce, cipherText, mac}`, `_envelopeVersion = 1`). The key
  comes from `SecureKeyStore` (OS keychain), generated once per installation on first start.
- **`keyId` detects foreign files** (8-byte SHA-256 of the key, plaintext, `AppStore.keyFingerprint`). Without
  this field, "file belongs to a different machine" can't be distinguished from "file is corrupt" — both fail at
  decryption — and the intact foreign file would run into quarantine + a blank start. If `keyId` doesn't match,
  the store throws `ForeignKeyDataException`; it **must** bypass the `catch (_)` in `ensureInitialized()`
  (`on ForeignKeyDataException { rethrow; }`), otherwise exactly the safety net that would be fatal here kicks in.
  `main()` then shows `_ForeignDataApp` — nothing gets moved and **nothing gets written**.
  **`v` stays at 1**: `keyId` is additive, `_isEnvelope` only checks the four known fields, so older app versions
  keep reading new files. A version bump would have broken that. Files without `keyId` (written before the
  feature existed) unchangedly take the previous path.
- **Export is the only device-independent path**, deliberately separate from the data file's envelope
  (`lib/data/backup_crypto.dart`): its key is derived via PBKDF2-HMAC-SHA256 from a **password**, not from the OS
  keychain — that's what lets it be read back in on any machine. The password is **optional**: without one, the
  export still writes exactly the previous plaintext JSON, so existing backups stay valid. Import tells the two
  forms apart by structure (`isEncryptedBackup`), not by extension or filename, and only prompts for protected
  files. The KDF parameters (method, salt, iterations) live **in the file**, so they can be raised later without
  breaking old backups. In the export dialog, "without a password" is its own button rather than "leave the field
  empty" — a dismissed dialog must never produce an unprotected export (`null` = cancelled vs. `''` = deliberately none).
- **Export compliance: every algorithm runs in the operating system's implementation, not a bundled one.**
  This is a distribution requirement, not a security one — the algorithms and every byte of both file formats are
  unchanged. Apple's App Store Connect help distinguishes three cases: encryption *limited to that within the
  Apple operating system* needs no documentation, an *industry-standard algorithm not provided by the OS* needs a
  French encryption declaration, and proprietary algorithms need a CCATS on top. Until v1.9 the app was the second
  case: `package:cryptography` ships its own Dart AES-GCM and PBKDF2.
  - **AES-GCM** comes from `cryptography_flutter` (CryptoKit/CommonCrypto on Apple, `javax.crypto` on Android),
    via `buildAesGcm256()` (`lib/data/crypto_platform.dart`) — the two call sites (`app_store.dart`,
    `backup_crypto.dart`) were changed from `AesGcm.with256bits()` to this factory, deliberately **not** via
    `FlutterCryptography.enable()` (deprecated, and would break clean `flutter analyze`). The factory checks
    `FlutterCryptography.isPluginPresent` itself and returns the plain Dart cipher when no plugin is registered
    (Windows, Linux, `flutter test`) — otherwise `FlutterAesGcm`.
  - **`buildAesGcm256()` is not decoration beyond that.** `FlutterAesGcm` only hands work to the OS above a size
    threshold by default, because a platform-channel round trip costs more than encrypting a few bytes. That
    default would leave a new user's small database on the Dart implementation — the exact case the declaration
    denies. The explicit `CryptographyChannelPolicy(minLength: 0, maxLength: null)` removes the threshold.
  - **PBKDF2** is bound directly to CommonCrypto in `lib/data/apple_pbkdf2.dart`, because `FlutterPbkdf2` is
    native on **Android only**. `dart:ffi` against libSystem, so no plugin, no CocoaPods entry, no Podfile change.
    A failed symbol lookup throws rather than falling back — a silent fallback here would make a filed declaration
    false.
  - **Windows and Linux are unchanged in substance.** No OS implementation is used there; the work merely moves to
    a background isolate. Both formats stay byte-compatible in every direction, so a backup written on macOS opens
    on Windows and the reverse.
  - **`main()` logs which implementation is live** (`describeCryptoPlatform()`), not debug-gated and free of paths or
    key material. `flutter test` cannot answer this question at all — it runs without a plugin registrant and
    always reports the Dart fallback — so the check is a manual one against the OS log, scripted as the smoke test
    in `dev/app-store.md`.
  - **The residue that is not solved:** the Flutter engine links BoringSSL for `dart:io` TLS, so the exchange-rate
    request does not use the OS TLS stack. Accepted deliberately; reasoning, the `cupertino_http` alternative, and
    the full per-dependency audit are in [`dev/native-libraries.md`](../native-libraries.md).
  - `macos/Runner/Info.plist` carries `ITSAppUsesNonExemptEncryption = false` on this basis. **If any of the above
    stops being true, that key is the first thing to change.**
- **The exchange-rate cache deliberately lives OUTSIDE the encrypted file**, in its own plaintext file
  `finanzgecko-rates.json` next to it — public ECB reference rates aren't a secret, and this way a newly cached
  rate never triggers a full re-encrypt of the whole DB. Migration: old stores with `ratesCache` in the DB get it
  moved into the standalone file automatically on first load.
- **Atomic writes:** always write a temp file → delete the old file → rename the temp file (shared helper
  `_atomicWrite`, used by `_persistNow` and `_persistRatesNow`). Prevents a half-written file on a crash mid-write.
- **Rollback on a failed write:** every mutating `AppStore` method holds onto the previous value before mutating
  and restores it if `_persist()`/`_persistRates()` throws — memory and disk never silently drift apart this way.
  `resetAll()` and `importAllData()` additionally write an encrypted snapshot of the previous state **beforehand**
  (`pre-reset-backup-<timestamp>.json` resp. `pre-import-backup-<timestamp>.json`, shared helper
  `_writeSnapshotBackup`) — the app's only two one-way actions (see `gherkin/settings.feature` "Zurücksetzen" and
  `gherkin/backup_restore.feature` "Import").
- **Errors from `AppStore` carry no German UI text:** slim exception types (`RecordNotFoundException`,
  `UnsupportedBackupVersionException`, `AccountImportRejectedException`) transport only structured data: which
  record is missing, which schema version was imported, which bank was unknown. The German user-facing wording
  happens exclusively in `describeError()` (`ui/widgets/app_snackbar.dart`) — keeps the persistence layer
  language-neutral without changing the messages actually shown.
- **Startup safety net:** if initialization in `main()` fails (e.g. no OS keychain/secret service available), the
  app shows a minimal error screen (`_StartupErrorApp`) instead of a silent crash before the first frame —
  deliberately without `AppState`/`AppStore`, exactly what might just have failed.
- **Serialized write queue** (`_writeQueue`/`_enqueueWrite`): prevents two parallel saves from colliding on the
  same temp file. A failed write doesn't poison the queue for later.
- **Unreadable/foreign files are never silently overwritten** — they're first backed up under
  `*.unreadable-<timestamp>` (`_quarantineFile(file, 'unreadable')`), only then does the app start with defaults.
- **Schema-version guard on the load path (not just on import):** on startup, `ensureInitialized()` checks the
  decrypted data file's `schemaVersion` against `currentSchemaVersion`:
  - *Newer than this build* (downgrade) → the file is NOT read leniently (that would drop unknown fields and then
    lossily overwrite the only copy of the user's data); instead it's preserved unchanged under
    `*.newer-version-<timestamp>` (`_quarantineFile(file, 'newer-version')`); the app starts with defaults. An app
    update makes the data readable again. Mirrors the import check
    (`UnsupportedBackupVersionException`) for the everyday load path, which previously had no version guard at all.
  - *Older than this build* (forward migration) → first a byte-exact copy of the (already-encrypted) file as
    `pre-migrate-backup-<timestamp>.json` (`_writePreMigrationBackup`), then the in-memory schema is stamped to
    `currentSchemaVersion` and written back immediately, so the file and the backup don't drift apart across
    restarts. A botched migration stays recoverable this way.
- **Import enforces the bank→color rule:** in `importAllData`, `account.color` gets reset via
  `resolveAccountColor(bank, tag)` (`constants.dart`) — a known bank → its brand color, an empty bank
  (cash/crypto) → the Kontotyp color. An unknown, non-empty bank **aborts the whole import** (no silent injection
  of an arbitrary color). This exactly mirrors the Konto form's rule
  (`bankColorHex(bank) ?? tagColorHex(tag)` + known-bank validator).
- **`kBanks` is a hand-maintained list** (`constants.dart`), organized into branch banks (Sparkassen,
  Volks-/Raiffeisenbanken, big banks, development banks), direct/neobanks, auto banks, brokers & crypto,
  credit-card/niche banks, plus the internationally common payment services PayPal, Wise, and Revolut —
  **not** an automatically generated or complete list (currently ~43 entries, also documented on the website
  under `docs/index.html` FAQ "Welche Banken werden unterstützt?" — kept in sync there **manually**, since the
  static page doesn't read `kBanks` at build time). Every `colorHex` is the bank's **official brand color** (from
  its logo/corporate design/brand kit), hand-researched, not algorithmically derived — for banks without a
  verifiable official source there's deliberately **no** entry rather than a guessed hex value. A missing bank
  gets suggested through the channels linked in the Konto form (GitHub issue or email, see
  `gherkin/accounts.feature`) and then manually added as another `Bank(name, colorHex)` entry (also update the
  FAQ list on the website then).
- **File permissions as defense in depth:** `chmod 700`/`600` (Linux/macOS), `icacls` current-user-only (Windows)
  — in addition to encryption, not as a substitute for it.
- **macOS specifics (important, don't revert by accident):**

  Since App Store preparation there are **two macOS delivery forms**, distinguished by the compile-time constant
  `kIsMacAppStore` (`lib/constants.dart`, `bool.fromEnvironment('FINANZGECKO_MAS')`, **default `false`**).
  Everything below applies to the default case — the DMG build every existing user has installed. The App Store
  build's deviations are noted underneath each point and are **only** reachable via
  `packaging/macos/build_appstore.sh`.

  - `SecureKeyStore` uses `MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore)`.
    - **DMG build (`false`):** the classic keychain. The data-protection variant binds the key to a
      team-ID-derived access group and requires a `keychain-access-groups` entitlement; a build without it —
      including every locally ad-hoc-signed `.app` — fails with `-34018`. That a Developer ID now exists changes
      **nothing** about that: switching would make the key look elsewhere and render every existing user's data
      file unreadable. Don't switch.
    - **App Store build (`true`):** the data-protection variant is mandatory, because a sandboxed app has no
      access to the classic keychain. Works there because `AppStore.entitlements` brings the matching access
      group. Store→store updates are safe by construction: access is decided by the `keychain-access-groups`
      entitlement (`<TeamID>.de.finanzgecko.app`), not by a per-item ACL, so Apple re-signing every version
      changes nothing. Only a Team-ID change or an app transfer to another team would lose the items.
  - **Channel switch (DMG ↔ App Store) — the two builds share the container, not the key.** Both are sandboxed
    (below), so both read the same file at the same path. But the DMG build keeps its key in the login keychain
    and the store build in the data-protection keychain, so each finds the other's file, sees a `keyId`
    fingerprint that isn't its own, and throws `ForeignKeyDataException`. `main()` then shows `_ForeignDataApp`
    and writes, moves and deletes **nothing** — the other channel keeps working if you go back. The route across
    is *Backup exportieren…* / *Backup importieren…*, and `_ForeignDataApp` says so in wording branched on
    `kIsMacAppStore`, because "another computer" is wrong when it is the same Mac.
    - **Still open for the store build:** a user coming from ≤1.7 has no file in the container at all, and
      `AppStore.entitlements` deliberately carries no temporary exception, so `SandboxMigration` cannot reach the
      pre-sandbox path. That user lands in an empty app with no explanation. Close this before the first store
      submission — see `dev/app-store.md`.
  - **App sandbox has been active in ALL macOS builds since v1.8** (`com.apple.security.app-sandbox = true` in
    `Release.entitlements`, `DebugProfile.entitlements`, and `AppStore.entitlements`). This is a **deliberate
    reversal** of the decision documented through v1.7; the old rationale ("otherwise macOS virtualizes `$HOME`
    and `resolveDataDirectory()` writes past the documented path") was correct, but is now resolved through a
    one-time migration instead of avoidance. The goal is exactly **one** macOS behavior instead of two.
    - `resolveDataDirectory()` needs **no** case distinction: under the sandbox, `$HOME` already points at
      `~/Library/Containers/de.finanzgecko.app/Data`, and the same relative path results again there. The
      documented path is the container path from v1.8 on.
    - **`lib/data/sandbox_migration.dart` is the price of this reversal.** On a sandboxed build's first start, an
      existing installation's data file still sits under the real home. The migration **copies** it into the
      container — it doesn't move it and deletes nothing. Two rules that are non-negotiable: never overwrite (the
      container always wins) and never delete the original (the only fallback if the copy was subtly wrong).
      Runs in `ensureInitialized()` **before** the file is first read.
    - Read access to the old path comes from the entitlement
      `com.apple.security.temporary-exception.files.home-relative-path.read-write`, scoped tightly to
      `/Library/Application Support/de.finanzgecko.app/`. It's **transitional**: once the old path is no longer
      read, it comes out (ROADMAP). Deliberately absent in the App Store build.
    - The `chmod` hardening is skipped in the App Store build (`_chmod` bails immediately when `kIsMacAppStore`).
    - **Keychain question: settled empirically on 2026-08-13 — yes, it works.** A sandboxed build signed with the
      Developer ID reads the existing legacy keychain entry unchanged. Keychain ACLs hang off the code-signing
      identity, and the sandbox doesn't change that (same Developer ID, same bundle ID). That's why
      `SandboxMigration` deliberately migrates **files only, never a key**.
      Tested against a real existing installation: file hash in the container identical to the old path, the app
      showed all data without an import. **Not verifiable in CI** — on a change of signing identity (e.g. the
      App Store build, which Apple re-signs), this result explicitly does **not** hold and needs re-checking.
  - The in-app update path (*Nach Updates suchen*) is absent from the App Store build: App Review
    Guideline 2.4.5 forbids a second update channel, and the App Store updates itself. The privacy paragraph in
    the help section correspondingly loses its sentence about the GitHub releases API there (see
    `gherkin/settings.feature`).
    - **`AppState.updateService` is `UpdateService?` and is `null` when `kIsMacAppStore`.** That nullability is
      the point, not an accident: as long as the field was non-nullable, `AppState`'s constructor referenced
      `UpdateService()` unconditionally and the tree shaker had to keep the class — and the `api.github.com`
      URL — in the store binary, however well hidden the button was. **Do not "simplify" it back to a
      non-nullable field with a dummy instance.**
    - `_checkForUpdates` returns immediately on that `null` (`lib/ui/views/settings_view.dart`), and
      `_downloadUpdate` takes the resolved `UpdateService` as a parameter rather than reading it back off
      `AppState`. Two locks: a re-added UI entry still cannot reach the network, and nothing in the store build
      references the service by value.

## Schema (`lib/data/app_schema.dart`)

`AppSchema` is the complete in-memory image of the JSON file: `schemaVersion`, `baseCurrency`, lists (`accounts`,
`balances`, `assets`, `subscriptions`), `ratesCache` (legacy migration path, see above), auto-increment IDs
(`nextAccountId` etc.), `lastExportAt`, `window` (`WindowPrefs`), plus the reminder-notification tracking
`notificationsEnabled`, `backupOverdueNotified`, `assetOverdueNotifiedIds` (episode-based, see [state-and-models.md](state-and-models.md) and
`gherkin/notifications.feature`), plus `themeMode` (`AppThemeMode`, default `system`, see [ui-conventions.md](ui-conventions.md)
"Appearance") and `rateFetchConsent` (`RateFetchConsent`, default `unset`, see [stack.md](stack.md) and
`gherkin/currency_exchange.feature`) — all additive `meta` fields, no `schemaVersion` bump needed.
For `rateFetchConsent` this is explicitly intentional: a missing key (every file written before the feature
existed) yields `unset`, i.e. **no** assumed consent — existing installations are asked once instead of being
silently grandfathered in. `notificationsEnabled` follows the same principle for the same reason, and goes one
step further: it is persisted under the key **`notificationsOptIn`**, not under its own field name. Files
written before the switch to opt-in carry `notificationsEnabled: true` — the default of the day — and reading
that key would hand a macOS authorization prompt to users who never chose the feature. Ignoring it lets every
existing file start from the opt-in default `false`, and whoever wants notifications switches the toggle on
once, by hand. Renaming the key rather than bumping `schemaVersion` costs nothing on the backup side: `meta` is
not part of the export format at all (see `toExportJson()`).
`fromDynamic()` is **fault-tolerant per entry**: a broken line in a list gets skipped
instead of making the whole file unreadable. `toExportJson()` is deliberately slimmer than `toJson()` (no
`ratesCache`/`meta`/`window` — internal implementation detail, not part of a backup) **and without
`account.color`** (`Account.toExportJson`): the color is derivable from the bank and gets reset on import via
`resolveAccountColor` — smaller backups, a hardened import.

`currentSchemaVersion = 1` — increment on every incompatible schema change. That affects **two** paths: (1) the
import check in `AppStore.importAllData()` (rejects backups from a *newer* version, with a clear error message)
and (2) the startup load path in `ensureInitialized()` (downgrade guard + automatic `pre-migrate-backup`, see
`persistence.md`). **When incrementing, do NOT** touch the frozen golden-file fixture `test/fixtures/backup_v1.json` —
instead add a new `backup_v<n>.json` + test, so that "a newer app can no longer read old data" shows up in CI
before it ships.

## Details worth knowing before you touch this file

- **Reminder notifications are throttled per episode, not by time.** A flag (`backupOverdueNotified`) resp. an id
  set (`assetOverdueNotifiedIds`) records that the *current* overdue state has been notified; the action that
  resolves it — an export, or re-valuing the Vermögenswert — clears the entry, so the next episode notifies
  again. Nothing here is time-based.
- **File-permission hardening runs once per path per session** (`_hardened`): the bits survive a rewrite, and
  persists are frequent (inline-edited amounts autosave after a typing pause), so one subprocess spawn per path
  beats one per keystroke pause. Both binaries are addressed **absolutely** on purpose (`/bin/chmod`,
  `%SystemRoot%\System32\icacls.exe`) because `PATH` is attacker-influenced, and `icacls` is applied to the
  *directory* with inheritable flags so later quarantine copies and snapshots inherit the restriction without
  each call site having to remember.
- **`resetAll()` deliberately preserves `WindowPrefs`.** Window geometry is not a user-visible setting; resetting
  it would move and resize the window in the middle of an action the user thinks is about their data.
- **PBKDF2 stays at 200,000 iterations**, even though the native Apple path could afford far more. The number was
  a compromise against the pure-Dart implementation on the UI isolate; it is deliberately **not** raised until
  Windows and Linux can follow, so the file format never depends on which machine wrote the backup. The
  parameters live in the file precisely so the number can be raised later, on all platforms at once.
- **`ApplePbkdf2` binds `CCKeyDerivationPBKDF` through libSystem**, not through a plugin — no Podfile entry, which
  also keeps the build working past the CocoaPods registry going read-only. `deriveKey` is synchronous on
  purpose: native iterations cost far less than the pure-Dart path, and `Isolate.run` is the escape hatch if the
  count is ever raised.
