# Quelle: lib/ui/views/settings_view.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/ui/widgets/reset_confirm_dialog.dart
@settings
Feature: Einstellungen
  Als Nutzer:in steuere ich die Basiswährung, sehe Sicherheits-Informationen zur Verschlüsselung und kann die App
  im Notfall komplett zurücksetzen.

  Background:
    Given die App ist gestartet und initialisiert
    And ich bin auf der Ansicht "Einstellungen"

  Scenario: Basiswährung ändern
    When ich in "Basiswährung" eine andere Währung aus der Liste wähle
    Then wird sie sofort übernommen (keine separate Speichern-Aktion nötig)
    And ich sehe eine Speicher-Bestätigung
    And alle Dashboard-Summen werden ab sofort in dieser Währung berechnet

  Scenario: Sicherheits-Informationen sind einsehbar, aber nicht sensibel
    Then zeigt der Abschnitt "Sicherheit" ein Badge "Verschlüsselung aktiv"
    And das Verfahren "AES-256-GCM"
    And den plattformspezifischen Schlüsselspeicher-Namen (Windows Credential Locker / macOS Schlüsselbund /
      Linux Secret Service, je nach Betriebssystem)
    And den Speicherort der Datendatei, mit einem Button zum Öffnen im Dateimanager

  Scenario: Speicherort im Dateimanager öffnen
    When ich auf den "Im Dateimanager öffnen"-Button neben dem Speicherort klicke
    Then öffnet sich der native Dateimanager des Betriebssystems am Datenverzeichnis
    Given das Öffnen schlägt fehl (z. B. kein Dateimanager registriert)
    Then erscheint eine Fehler-Snackbar "Ordner konnte nicht geöffnet werden."

  Scenario: Export-Status wird angezeigt
    Given noch nie exportiert wurde
    Then zeigt der Export-Bereich "Noch nie exportiert."
    Given zuletzt am Datum X exportiert wurde
    Then zeigt der Export-Bereich "Letzter Export: <Datum>, <Uhrzeit>"

  Scenario: Tastenkürzel werden in den Einstellungen dokumentiert
    Then zeigt der Export-Bereich das Tastenkürzel "Strg+E" (bzw. "⌘+E" auf macOS)
    And der Import-Bereich zeigt "Strg+I" (bzw. "⌘+I")

  Scenario: App zurücksetzen erfordert eine getippte Bestätigungsphrase
    When ich im rot umrandeten Bereich "Zurücksetzen" auf "App zurücksetzen…" klicke
    Then öffnet sich ein Dialog, der erklärt, dass alle Konten, Kontostände, Vermögenswerte und Fixposten
      unwiderruflich gelöscht werden und die Basiswährung zurückgesetzt wird
    And der Bestätigen-Button ist erst aktiv, wenn ich exakt "ZURÜCKSETZEN" ins Textfeld eingetippt habe

  Scenario: Erfolgreiches Zurücksetzen
    Given ich habe "ZURÜCKSETZEN" korrekt eingetippt und bestätigt
    Then werden alle Konten, Kontostände, Vermögenswerte und Fixposten gelöscht
    And die Basiswährung wird auf den Standardwert zurückgesetzt
    And die Fenstergeometrie (Größe/Maximiert-Status) bleibt unverändert erhalten (kein UI-Sprung)
    And ich sehe die Bestätigung "App wurde auf Standardwerte zurückgesetzt."

  Scenario: Zurücksetzen abbrechen
    Given der Bestätigungsdialog ist offen
    When ich auf "Abbrechen" klicke oder die Phrase nicht exakt eingebe
    Then bleiben alle Daten unverändert
