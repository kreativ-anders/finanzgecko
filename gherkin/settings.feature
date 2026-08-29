# Source: lib/ui/views/settings_view.dart, lib/ui/backup_actions.dart, lib/utils/csv_export.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/data/app_schema.dart, lib/ui/theme.dart, lib/constants.dart, lib/ui/widgets/reset_confirm_dialog.dart, lib/services/currency_service.dart, lib/services/update_service.dart, lib/utils/update_assets.dart
# Implementation: lib/ui/views/settings_view.dart
@settings
Feature: Einstellungen
  As a user, I control the Basiswährung, see security information about the encryption, and can fully
  reset the app in an emergency.

  Background:
    Given the app is started and initialized
    And I am on the "Einstellungen" view

  Scenario: Change the Basiswährung
    When I choose a different currency from the list in "Basiswährung"
    Then it is applied immediately (no separate save action needed)
    And I see a save confirmation
    And every Dashboard total is computed in this currency from now on

  Scenario: Choose the appearance
    Then the "Erscheinungsbild" section shows a choice of "System", "Hell", and "Dunkel", defaulting to
      "System"
    When I choose "Hell" resp. "Dunkel"
    Then the app switches to the matching color palette immediately (no separate save action needed)
    And I see a save confirmation
    And the choice persists across an app restart
    Given "System" is chosen
    Then the app follows the OS's light/dark setting and switches automatically when the OS changes its
      setting

  Scenario: Turn desktop notifications on/off
    Then the "Benachrichtigungen" section shows a "Desktop-Benachrichtigungen" toggle, off by default
    When I turn the toggle on
    Then macOS asks once for permission, and only with permission granted does the toggle stay on
    When I turn the toggle off again
    Then no more OS notifications are sent from now on (detail behavior: see gherkin/notifications.feature)

  Scenario: Security information is viewable, but not sensitive
    Then the "Sicherheit" section shows a "Verschlüsselung aktiv" badge
    And the method "AES-256-GCM"
    And the platform-specific key-store name (Windows Credential Locker / macOS Schlüsselbund / Linux
      Secret Service, depending on the OS)
    And the data file's storage location, with a button to open it in the file manager

  Scenario: Open the storage location in the file manager
    When I click the "Im Dateimanager öffnen" button next to the storage location
    Then the OS's native file manager opens at the data directory
    And on macOS, the PARENT directory is deliberately opened instead: the data directory is named after
      the application ID and thus ends in ".app", which macOS treats as an app bundle — it then tries to
      launch the folder and reports "beschädigt oder unvollständig". A trailing slash does NOT help here
      (measured on 2026-08-13), opening the parent directory does
    And on Linux and Windows, the data directory itself keeps opening directly — there, ".app" isn't a
      special suffix
    Given opening it fails (e.g. no file manager registered)
    Then an error snackbar "Ordner konnte nicht geöffnet werden." appears

  Scenario: Export status is shown
    Given never exported before
    Then the export section shows "Noch nie exportiert."
    Given the last export was on date X
    Then the export section shows "Letzter Export: <Datum>, <Uhrzeit>"

  Scenario: Keyboard shortcuts are documented in Einstellungen
    Then the export section shows the shortcut "Strg+E" (resp. "⌘+E" on macOS)
    And the import section shows "Strg+I" (resp. "⌘+I")

  Scenario: Additionally export the data as CSV tables
    Given I am in the export section
    When I click "Als CSV-Tabellen exportieren…"
    Then a native folder dialog opens (not a file dialog: the export consists of several files)
    And four UTF-8 CSV files (with BOM) with fixed names are written into the chosen folder:
      "finanzgecko-konten-<YYYY-MM-DD>.csv" — per Konto: Konto-ID, Konto, Bank, Kontotyp
      "finanzgecko-kontostaende-<YYYY-MM-DD>.csv" — per Konto and month: Monat, Konto-ID, Konto, Währung, Betrag
      "finanzgecko-fixposten-<YYYY-MM-DD>.csv" — per Fixposten: Fixposten, Art (Einnahme/Ausgabe), Intervall,
      Währung, Betrag
      "finanzgecko-vermoegenswerte-<YYYY-MM-DD>.csv" — per Vermögenswert: Vermögenswert, Wert (Basiswährung)
    And all files are ";"-separated, use a decimal comma, and RFC 4180 quoting
    And "Konto-ID" links the Konten table to the Kontostände table — master data (Bank, Kontotyp) appears
      exactly once instead of on every month row
    And every amount appears exactly once, in the currency it was recorded in — no rate, no second
      converted amount, no derived column (not even a monthly equivalent: the Intervall sits next to it)
    And conversion is the evaluating spreadsheet's job, not the export's
    And the Fixposten amount applies per Intervall, not per month
    And income items come before expense items, and Konten/Fixposten/Vermögenswerte are sorted by name,
      matching their respective views
    And archived Konten are included (otherwise their historical Kontostände would point at nothing), but
      not marked as archived
    And this export does NOT count as a backup — the backup reminder and "zuletzt exportiert" stay untouched
    And the CSVs are deliberately not re-importable (only the JSON export is a lossless round trip)

  Scenario: An empty section still yields a table
    Given I haven't recorded any Fixposten or Vermögenswerte (yet)
    When I export the data as CSV
    Then four files are still produced; the empty ones contain only their header row

  Scenario: Existing files are only overwritten after confirmation
    Given files with these names already exist in the chosen folder (e.g. an earlier export from today)
    When I confirm the folder
    Then exactly one confirmation "Dateien überschreiben?" appears for the whole set
    And on "Abbrechen" not a single file is written

  Scenario: CSV export neutralizes formula injection in free-text fields
    Given a Konto name, a bank, a Fixposten name, or a Vermögenswert name starts with "=", "+", "-", or "@"
      (e.g. from an imported backup)
    When I export the data as CSV
    Then a leading "'" is prepended to the affected field, so spreadsheet apps (Excel/LibreOffice) don't
      interpret it as a formula/DDE command on open
    And number/enum columns (Kontotyp, Intervall, Währung, Betrag) stay unchanged, so e.g. negative amounts
      keep working normally in sum formulas

  Scenario: The Hilfe section shows app and system information
    Then the "Hilfe" section shows the installed version plus build number, read directly from the running
      installation (so it always matches the actually installed release, even after a tag auto-bumped by
      the release workflow)
    And dynamically determined system information: OS plus version, number of CPU cores, system language,
      Dart runtime version
    And the resolution(s) of every connected screen (makes a multi-monitor/external-display setup
      recognizable at a glance) plus the app's current window size
    And a live reachability check of the exchange-rate API ("Erreichbar" / "Nicht erreichbar" / "Prüfe…"),
      accompanied by a note that this is the app's only automatic external network connection (no tracking,
      no analytics services) — this row doubles as the answer to "what permissions does the app use"
    And a "Nach Updates suchen" link, "E-Mail-Support" (mailto to the support address), plus
      "Fehler melden (GitHub)" to the project's issue tracker
    And a "Debug-Informationen kopieren" button that copies version, system, and connection info as text to
      the clipboard, confirmed via a "Debug-Informationen kopiert." snackbar

  Scenario: Manual update check in the Hilfe section
    Given I am in the "Hilfe" section
    When I click the "Nach Updates suchen" link
    Then the app queries the project's public GitHub releases API (kreativ-anders/finanzgecko) for the
      latest release tag and compares it against the installed version
    And this query happens only on this click — no automatic background check at app start or periodically
      while running (see AI_MASTER.md Section 6)
    Given a newer version is available
    Then a dialog "Update verfügbar" opens with the new version number and the currently installed version,
      plus the buttons "Später" (closes the dialog with no action) and "Herunterladen"

  Scenario: Download an update and check it against the checksum
    Given I chose "Herunterladen" in the "Update verfügbar" dialog
    Then the app asks via a file dialog where the file should be saved (no silent drop into the downloads
      folder: that would trigger its own macOS system prompt "Zugriff auf den Ordner Downloads")
    And the name of the release asset matching the running OS is suggested (-mac.dmg, -Setup.exe resp.
      -x86_64.AppImage — the same suffixes as in release.yml and docs/download.html, see
      gherkin/executable/update_assets.feature)
    When I confirm a save location
    Then the app downloads the file with a progress indicator and compares it against the SHA256SUMS file
      from the same release
    And the file is only written once the checksum matches — an unverified file never ends up in the
      chosen folder
    Then a dialog "Update geladen und geprüft" shows the platform-dependent next step plus an
      "Im Ordner zeigen" button
    And this dialog first asks to quit FinanzGecko before installing the new version (replacing a running
      app leads to errors) — deliberately worded once for all platforms, not per platform, so the hint
      can't be missing on any of them
    And the app does NOT execute the file and doesn't replace itself — on Windows, "start the installer"
      would mean launching a freshly downloaded executable file
    Given the checksum doesn't match
    Then a dialog "Prüfsumme stimmt nicht" appears (deliberately not a snackbar) and the file wasn't saved
    Given the release contains no file for this OS, or no SHA256SUMS (older releases)
    Then nothing is guessed — the website's download page opens instead
    Given the GitHub response names an address for an asset that doesn't point via HTTPS at a known GitHub
      release host
    Then that host isn't even contacted, and the same path as above is taken (download page)
    And it likewise aborts if the file exceeds the allowed size — it's held fully in memory before the
      checksum check
    And this case deliberately uses a dialog instead of a snackbar (like the two cases below): a genuinely
      actionable message shouldn't disappear on its own like a mere confirmation
    Given the installed version is already the latest
    Then a snackbar shows "Du verwendest bereits die neueste Version (<Version>)."
    Given the query fails (no internet connection, repository not yet public, GitHub unreachable, or
      similar)
    Then no error is thrown — instead an error snackbar "Update-Prüfung fehlgeschlagen — bitte später
      erneut versuchen." is shown

  Scenario: The update check is entirely absent from the App Store build
    Given the app was built for the Mac App Store (kIsMacAppStore, see gherkin/data_security.feature)
    Then the "Nach Updates suchen" link is missing from the "Hilfe" section — the other links
      ("E-Mail-Support", "Fehler melden (GitHub)", "Debug-Informationen kopieren") stay unchanged
    And the network note now names only the exchange-rate API and closes with "Updates erhältst du über
      den App Store." — the sentence about the GitHub releases API is dropped, since that call doesn't
      exist in this build; it's a privacy claim and must not assert anything that doesn't happen
    And this isn't a matter of taste: a second self-update path alongside the App Store violates App
      Review Guideline 2.4.5
    And because kIsMacAppStore is a compile-time constant, the tree shaker removes the download path from
      the binary, rather than just hiding the button

  Scenario: Resetting the app requires a typed confirmation phrase
    When I click "App zurücksetzen…" in the red-bordered "Zurücksetzen" section
    Then a dialog opens explaining that all Konten, Kontostände, Vermögenswerte, and Fixposten will be
      irrevocably deleted and the Basiswährung reset
    And the confirm button only becomes active once I've typed exactly "ZURÜCKSETZEN" into the text field

  Scenario: Before every reset, a backup of the previous state is created automatically
    Given I typed "ZURÜCKSETZEN" correctly and confirmed
    Then the previous data state is first saved as its own encrypted file
      "pre-reset-backup-<Zeitstempel>.json" in the data directory (like on import, see backup_restore.feature)
    And a failure in this backup must not prevent the actual reset (best effort)

  Scenario: Successful reset
    Given I typed "ZURÜCKSETZEN" correctly and confirmed
    Then all Konten, Kontostände, Vermögenswerte, and Fixposten are deleted
    And the Basiswährung is reset to its default value
    And the window geometry (size/maximized state) stays unchanged (no UI jump)
    And I see the confirmation "App wurde auf Standardwerte zurückgesetzt."

  Scenario: Cancel the reset
    Given the confirmation dialog is open
    When I click "Abbrechen" or don't type the phrase exactly
    Then all data stays unchanged
