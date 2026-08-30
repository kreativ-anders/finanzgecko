# Source: lib/data/app_store.dart, lib/data/secure_key_store.dart, lib/data/app_schema.dart, lib/constants.dart,
#   lib/data/sandbox_migration.dart, lib/data/crypto_platform.dart, lib/data/apple_pbkdf2.dart
# Implementation: lib/data/app_store.dart
@security @persistence
Feature: Data storage, encryption, and integrity
  As a user, I expect my financial data to be stored exclusively locally, encrypted, and robust against
  crashes or corrupted files — without ever silently losing data.

  Scenario: First use generates a new encryption key
    Given the app starts for the first time on this device
    Then a new 256-bit AES key is generated
    And it is stored in the OS credential store (Windows Credential Locker, macOS Schlüsselbund, Linux
      libsecret/kwallet depending on the platform) — never in the data file itself

  Scenario: The key is reused on every subsequent start
    Given a key has already been generated once
    Then every subsequent start reads the same key from the credential store, none is regenerated

  Scenario: The database file is unreadable without the key
    Given the data file is opened outside the app
    Then it contains only an "envelope" structure of version, nonce, ciphertext, and MAC (AES-256-GCM)
    And without the matching key in the OS credential store, the content can't be decrypted

  Scenario: Writes are atomic
    Given a change is saved
    Then it is first written to a temporary file, which is then renamed over the old one
    And a crash mid-write must never leave behind a half-written main file

  Scenario: On Linux and macOS, the data file is never deleted beforehand
    Given a change is saved on a POSIX system
    Then the rename replaces the existing file directly, without deleting it first
    And there is never a moment where no data file exists at all
    But on Windows, the old file is deleted first, since the rename would otherwise fail there

  Scenario: Permissions are set once per file per session
    Given the same file is saved multiple times within one session
    Then the OS's permission command only runs the first time
    And it is invoked via its absolute path, not via a PATH lookup

  Scenario: Parallel writes are serialized
    Given two save actions are triggered nearly simultaneously
    Then the second one only runs fully after the first has already renamed its temp file
    And a failure in one write doesn't block the ones that follow

  Scenario: Unreadable or foreign files are never silently overwritten
    Given a file sits at the expected path that isn't valid envelope JSON (wrong format, broken JSON,
      failed decryption)
    When the app starts
    Then this file is first backed up as a copy under "<dateiname>.unreadable-<Zeitstempel>"
    And only then does the app start with defaults and write a new file

  Scenario: Missing file on first start
    Given no file exists yet at the expected path
    Then the app starts with defaults, without creating a quarantine copy (nothing to lose)

  Scenario: The storage location is deliberately not selectable
    Given I open Einstellungen → Sicherheit
    Then I see the storage location, but no way to change it
    And a hint explains in plain language that the file belongs to this computer, that a copy in a cloud
      folder helps in case of a disk failure but not on a new computer or after a reinstall, and that only
      export provides a recoverable backup
    And the hint sits there permanently, not as a one-time dismissible dialog

  Scenario: A file from a different machine is detected, not quarantined
    Given the file contains a key fingerprint (keyId) that doesn't match this machine's key
    When the app starts
    Then startup aborts with an explanation ("Diese Datei gehört zu einem anderen Computer")
    And the file stays byte-identical — no quarantine copy, no write
    And the explanation points to the path via "Backup exportieren" and "Backup importieren"
    Given the same machine gets its original key back
    Then the file opens normally again

  Scenario: The key fingerprint is additive and doesn't break older app versions
    Given a newly written data file
    Then the envelope additionally contains the plaintext field "keyId" (8-byte SHA-256 of the key)
    And the envelope version stays at 1, since the check only looks at the four known fields
    And an older app version keeps reading this file unchanged
    Given a file from before this field existed (without "keyId")
    Then it is loaded as before, with no fingerprint check

  Scenario: A data file from a newer schema version is preserved, not overwritten
    Given the data file carries a "schemaVersion" greater than the version this build supports (e.g.
      because a newer app version ran and the app was downgraded afterward)
    When the app starts
    Then the file is NOT read leniently (that would silently drop unknown fields)
    And it is first backed up unchanged as a copy under "<dateiname>.newer-version-<Zeitstempel>"
    And only then does the app start with defaults — the newer file stays fully intact, so an app update
      makes the data readable again

  Scenario: A data file from an older schema version gets migrated — with a prior backup
    Given the data file carries a "schemaVersion" less than the currently supported version
    When the app starts
    Then an unchanged, encrypted copy of the previous file is first saved as
      "pre-migrate-backup-<Zeitstempel>.json" in the data directory
    And only then is the file rewritten in the current format and stamped with the current schema version
    And a failure in this backup must not prevent startup (best effort)

  Scenario: Individual faulty records don't endanger the whole file
    Given the database contains a list (Konten/Kontostände/Vermögenswerte/Fixposten) with a single faulty
      entry
    Then only this entry is skipped on load
    And every other entry and section of the file stays usable

  Scenario: File permissions as an additional layer of defense
    Given the app created the data directory and the data file
    Then on Linux/macOS the permissions are set to 700 (directory) resp. 600 (file)
    And on Windows an ACL is set that allows access only to the current user
    And this counts as a supplement to the encryption, not a substitute for it

  Scenario: The exchange-rate cache is deliberately unencrypted and separate
    Then the exchange-rate cache lives in its own file "finanzgecko-rates.json" next to the main database
    And a parse error in this file is silently ignored (rates can be fetched again anytime, no risk of
      data loss)

  Scenario: Encryption runs in the operating system's implementation, not a bundled one
    Given the app runs on macOS, iOS or Android
    Then AES-256-GCM is performed by the OS implementation (CryptoKit/CommonCrypto resp. javax.crypto)
    And this holds for every payload size — there is no threshold below which a bundled implementation
      takes over, because a small database would otherwise be encrypted by the very implementation the
      App Store export-compliance declaration says is not used
    And PBKDF2-HMAC-SHA256 for backups is performed by CommonCrypto on macOS and iOS, since the plugin
      covers that algorithm natively on Android only
    And if the OS function cannot be reached at all, the app fails loudly rather than quietly falling back —
      a silent fallback would turn a filed declaration into a false one
    Given the app runs on Windows or Linux
    Then no OS implementation exists for these algorithms and the bundled one is used, off the UI isolate

  Scenario: Switching implementations changes no file
    Given a data file or a password-protected backup written by a version before this change
    Then it is read unchanged afterwards — same envelope fields, same KDF parameters, same key fingerprint
    And a backup written on macOS opens on Windows and Linux, and one written there opens on macOS
    And nothing is re-encrypted or rewritten on account of this change

  Scenario: Which implementation is live can be checked on a real build
    Given the app starts
    Then it writes one line to the OS log naming the implementation in use for AES-GCM and for PBKDF2
    And that line contains no path and no key material
    And it is the only way to verify this on a signed, sandboxed build: an automated test runs without a
      plugin registrant and would always report the fallback

  Scenario: macOS — the keychain variant depends on the delivery form
    Given the app was shipped as a DMG (Developer ID build, the default case)
    Then the classic (non-data-protection) keychain variant is used
    And the first key access does NOT fail with "A required entitlement isn't present."
    And this holds unchanged for locally built, ad-hoc-signed builds without an Apple Developer team
    Given the app was built for the Mac App Store (kIsMacAppStore)
    Then the data-protection keychain variant is used — a sandboxed app has no access to the classic
      keychain, so here the variant is forced, not preferred
    And this requires the "keychain-access-groups" entitlement with a team-ID prefix
      (macos/Runner/AppStore.entitlements, deployed by packaging/macos/build_appstore.sh)
    And both variants store their keys separately: neither can find the other's key

  Scenario: macOS — the app sandbox is active in every build
    Given the app runs on macOS
    Then it runs with the app sandbox active, regardless of the delivery form
    And "$HOME" therefore points at "~/Library/Containers/de.finanzgecko.app/Data", under which the same
      relative path results again: resolveDataDirectory() stays unchanged, only the root path differs
    And the file-permission hardening (chmod) is skipped in the App Store build, since the container is
      already isolated per app and user

  Scenario: macOS — existing data is moved into the container once
    Given an installation from a version before the sandbox has data sitting under
      "~/Library/Application Support/de.finanzgecko.app/"
    And the container is empty (first start of the sandboxed build)
    When the app starts
    Then the data file and exchange-rate cache are COPIED into the container before anything is read for
      the first time
    And the target folder is named "FinanzGecko" rather than after the application ID: a folder name
      ending in ".app" reads to Finder as an app bundle. The rename rides along on this same one-time copy,
      instead of needing its own migration later
    And the original files stay unchanged and are NOT deleted — they're the fallback in case the copy was
      faulty
    And afterward a note "migrated-from-unsandboxed.txt" sits in the container, naming the old path
    Given a data file already sits in the container
    Then no migration happens — the container always wins, so a second start or an already-imported
      backup doesn't get overwritten
    Given there's no data in the container nor at the old path
    Then this is a genuine fresh install and the app starts normally empty
    Given the old path exists but isn't readable (a missing or mis-scoped temporary-exception entitlement)
    Then this is recorded as a failure and NOT treated as a fresh install — the two cases look the same to
      users (an empty app), but mean the opposite
