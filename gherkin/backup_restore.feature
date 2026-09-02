# Source: lib/ui/backup_actions.dart, lib/ui/navigation_shell.dart, lib/data/app_store.dart, lib/data/app_schema.dart,
#   lib/data/backup_crypto.dart, lib/ui/widgets/backup_passphrase_dialog.dart
# Implementation: lib/ui/backup_actions.dart
@backup
Feature: Export and import a backup
  As a user, I can export all my data as JSON — either in plaintext or password-protected — and import it
  back. Export is the only path that works on a different machine: the data file itself is bound to its
  device (see gherkin/data_security.feature).

  Background:
    Given the app is started and initialized

  Scenario: Export via menu or keyboard shortcut
    When I trigger "Backup exportieren…" via the Datei menu or Strg/⌘+E
    Then a native save dialog opens with the suggested name "finanzgecko-backup-<YYYY-MM-DD>.json"
    And only the ".json" extension is accepted as the type

  Scenario: Successful export
    Given I confirmed a save location in the dialog
    Then an unencrypted, indented JSON file is written with all Konten, Kontostände, Vermögenswerte,
      Fixposten, the Basiswährung, and the schema version
    And "zuletzt exportiert am" is updated to now
    And I see the confirmation "Backup exportiert."
    But the export does NOT include the exchange-rate cache, internal counters (meta), the window
      geometry, or the Konto accent color (color) — the latter is re-derived from the bank on import

  Scenario: Export dialog cancelled
    Given I cancel the save dialog
    Then nothing happens — no error, no timestamp update

  Scenario: A password is asked for before the save location
    Given I start an export
    Then the question of whether to protect the backup with a password appears first
    And there are two dedicated buttons for this, "Ohne Passwort" and "Mit Passwort schützen" — no empty
      field as a silent default, so a dismissed dialog never produces an unprotected export
    And a hint states the consequence: without this password the backup can no longer be opened later, but
      the data in the app stays unaffected by it
    When I cancel the dialog
    Then nothing is exported at all

  Scenario: Export without a password stays exactly as before
    Given I choose "Ohne Passwort"
    Then the same unencrypted, indented JSON file is written as before this feature existed
    And existing backups stay valid because of this

  Scenario: Export with a password
    Given I set a password and repeat it
    Then an encrypted file is written (AES-256-GCM, key derived via PBKDF2-HMAC-SHA256 from the password)
    And both are computed by the operating system's own implementation where it offers one (see
      gherkin/data_security.feature) — which implementation runs changes nothing about the file
    And the file contains neither plaintext data nor the password itself
    And the method, salt, and iteration count are stored in the file, so they can be strengthened later
      without making old backups unreadable
    And two exports of the same state produce different files (own salt, own nonce)
    But "Mit Passwort schützen" isn't selectable while the two password fields don't match

  Scenario: Import detects the format itself
    Given I choose a backup file to import
    Then the app detects whether it's protected from the file's structure — not from its extension or name
    And an unencrypted backup is read in without any confirmation, as before

  Scenario: Import of a password-protected file
    Given the chosen file is password-protected
    Then I am asked for the password
    When I enter a wrong password
    Then I am asked again with the hint "Das Passwort stimmt nicht.", instead of the process being
      cancelled
    When I cancel the dialog
    Then my current data stays unchanged
    Given the file was modified afterward
    Then decryption fails just as it would with a wrong password (the MAC check trips)

  Scenario: Export fails (e.g. write permissions)
    Given writing the file at the chosen location fails
    Then I see an error message "Export fehlgeschlagen: …"
    And "zuletzt exportiert am" is NOT updated

  Scenario: Import via menu or keyboard shortcut, with confirmation
    When I trigger "Backup importieren…" via the Datei menu or Strg/⌘+I
    And I choose a JSON file in the native open dialog
    Then a safety prompt "Import ersetzt ALLE aktuellen Daten. Fortfahren?" appears
    Given I cancel this prompt
    Then all current data stays unchanged

  Scenario: Successful import
    Given I chose a valid backup file and confirmed the import
    Then ALL current Konten, Kontostände, Vermögenswerte, and Fixposten are replaced by the file's content
    And the Basiswährung is adopted if present in the file
    And the auto-increment counters are set so future new records don't collide with imported IDs
    And the view automatically jumps to the Dashboard
    And I see the confirmation "Import abgeschlossen."

  Scenario: Before every import, a backup of the previous state is created automatically
    Given an import is performed (regardless of the outcome of the subsequent check)
    Then the previous data state is first saved as its own encrypted file
      "pre-import-backup-<Zeitstempel>.json" in the data directory
    And a failure in this backup must not prevent the actual import (best effort)

  Scenario: Old snapshot backups are pruned automatically
    Given more than 10 "pre-import-backup-*.json" files already sit in the data directory
    When a new one is written
    Then only the 10 most recent survive, the older ones are deleted
    And "pre-reset-backup-*.json" files (see settings.feature) are pruned the same way, counted separately
    And a failure while pruning must not prevent the snapshot that was just written (best effort)

  Scenario: Import of a corrupted or invalid file
    Given the chosen file isn't valid JSON or doesn't have the expected structure
    Then the import is aborted
    And I see "Import fehlgeschlagen: Datei ist kein gültiges Backup." with a technical detail
    And the current data stays untouched

  Scenario: Import of a file from a newer schema version is rejected
    Given the backup file has a "schemaVersion" greater than the version this app supports
    Then the import is rejected with a clear error message asking to update the app
    And the current data stays unchanged

  Scenario: Import of a file from an older or equal schema version is accepted
    Given the backup file has a "schemaVersion" less than or equal to the supported version
    Then the import is performed
    And missing fields in older entries are filled with sensible default values

  Scenario: Individual faulty entries don't block the whole import
    Given an otherwise valid backup file contains a single faulty entry in a list
    Then only this entry is skipped
    And every other entry is imported

  Scenario: Import enforces the bank→color rule and rejects unknown banks
    Given a backup/migration file contains Konten
    When the import runs
    Then every Konto's accent color is re-derived from its bank (the color from the file is ignored): a
      known bank → the bank's brand color, an empty bank (e.g. Bargeld/Krypto) → the Kontotyp color
    But if a Konto has a non-empty, unknown bank, the ENTIRE import is aborted with a clear error message
      ("Import abgebrochen bei Konto …") and the current data stays unchanged

  Scenario: Migration from an earlier app version
    Given an older version of the app was backed up via "Backup exportieren"
    When this file is imported into the current version
    Then Fixposten and the Intervall default in effect back then are restored correctly too (symmetric to
      export — no silently dropped fields)

  Scenario: Migration from a third-party tool via the import template
    Given I converted my data from another tool into the format of "templates/import-template.json"
      (fields, types, and value ranges as described in "templates/README.md", using AI-assisted conversion
      if needed)
    When I read this file in via "Backup importieren…"
    Then it's treated like a regular backup (the same checks: schema version, safety prompt, per-entry
      fault tolerance, auto-increment counters)
