# Quelle: lib/ui/app_shell.dart, lib/data/app_store.dart, lib/data/app_data.dart
@backup
Feature: Backup exportieren und importieren
  Als Nutzer:in kann ich meine gesamten Daten als Klartext-JSON exportieren (z. B. für einen Rechnerwechsel oder als
  zusätzliche Sicherung) und wieder importieren.

  Background:
    Given die App ist gestartet und initialisiert

  Scenario: Export über Menü oder Tastenkürzel
    When ich "Backup exportieren…" über das Datei-Menü oder Strg/⌘+E auslöse
    Then öffnet sich ein nativer Speichern-Dialog mit Vorschlagsnamen "finanzgecko-backup-<YYYY-MM-DD>.json"
    And nur die Dateiendung ".json" ist als Typ akzeptiert

  Scenario: Erfolgreicher Export
    Given ich habe im Dialog einen Speicherort bestätigt
    Then wird eine unverschlüsselte, eingerückte JSON-Datei mit allen Konten, Kontoständen, Vermögenswerten,
      Fixposten, der Basiswährung und der Schemaversion geschrieben
    And "zuletzt exportiert am" wird auf jetzt aktualisiert
    And ich sehe die Bestätigung "Backup exportiert."
    But der Export enthält NICHT den Wechselkurs-Cache, interne Zähler (meta) oder die Fenstergeometrie

  Scenario: Export-Dialog abgebrochen
    Given ich breche den Speichern-Dialog ab
    Then passiert nichts — kein Fehler, kein Zeitstempel-Update

  Scenario: Export schlägt fehl (z. B. Schreibrechte)
    Given das Schreiben der Datei am gewählten Ort schlägt fehl
    Then sehe ich eine Fehlermeldung "Export fehlgeschlagen: …"
    And "zuletzt exportiert am" wird NICHT aktualisiert

  Scenario: Import über Menü oder Tastenkürzel mit Bestätigung
    When ich "Backup importieren…" über das Datei-Menü oder Strg/⌘+I auslöse
    And ich im nativen Öffnen-Dialog eine JSON-Datei auswähle
    Then erscheint eine Sicherheitsabfrage "Import ersetzt ALLE aktuellen Daten. Fortfahren?"
    Given ich breche diese Abfrage ab
    Then bleiben alle aktuellen Daten unverändert

  Scenario: Erfolgreicher Import
    Given ich habe eine gültige Backup-Datei ausgewählt und den Import bestätigt
    Then werden ALLE aktuellen Konten, Kontostände, Vermögenswerte und Fixposten durch den Inhalt der Datei ersetzt
    And die Basiswährung wird übernommen, falls in der Datei vorhanden
    And die Auto-Increment-Zähler werden so gesetzt, dass künftige neue Datensätze nicht mit importierten IDs kollidieren
    And die Ansicht springt automatisch zum Dashboard
    And ich sehe die Bestätigung "Import abgeschlossen."

  Scenario: Vor jedem Import wird automatisch eine Sicherung des vorherigen Stands angelegt
    Given ein Import wird durchgeführt (unabhängig vom Ergebnis der anschließenden Prüfung)
    Then wird zuvor der bisherige Datenstand als eigene, verschlüsselte Datei
      "pre-import-backup-<Zeitstempel>.json" im Datenverzeichnis abgelegt
    And ein Fehler bei dieser Sicherung darf den eigentlichen Import nicht verhindern (best effort)

  Scenario: Import einer beschädigten oder ungültigen Datei
    Given die gewählte Datei ist kein gültiges JSON oder hat nicht die erwartete Struktur
    Then wird der Import abgebrochen
    And ich sehe "Import fehlgeschlagen: Datei ist kein gültiges Backup." mit technischem Detail
    And die aktuellen Daten bleiben unangetastet

  Scenario: Import einer Datei aus einer neueren Schema-Version wird abgelehnt
    Given die Backup-Datei hat eine "schemaVersion" größer als die von dieser App unterstützte Version
    Then wird der Import mit einer klaren Fehlermeldung abgelehnt, die zum Aktualisieren der App auffordert
    And die aktuellen Daten bleiben unverändert

  Scenario: Import einer Datei aus einer älteren oder gleichen Schema-Version wird akzeptiert
    Given die Backup-Datei hat eine "schemaVersion" kleiner oder gleich der unterstützten Version
    Then wird der Import durchgeführt
    And fehlende Felder in älteren Einträgen werden mit sinnvollen Standardwerten aufgefüllt

  Scenario: Einzelne fehlerhafte Einträge blockieren nicht den gesamten Import
    Given eine ansonsten gültige Backup-Datei enthält einen einzelnen fehlerhaften Eintrag in einer Liste
    Then wird nur dieser Eintrag übersprungen
    And alle anderen Einträge werden importiert

  Scenario: Migration von einer früheren App-Version
    Given eine ältere Version der App wurde über "Backup exportieren" gesichert
    When diese Datei in die aktuelle Version importiert wird
    Then werden auch Fixposten und das damalige Standard-Fixposten-Intervall korrekt wiederhergestellt
      (symmetrisch zum Export — keine stillschweigend verworfenen Felder)

  Scenario: Migration aus einem Fremdtool über die Import-Vorlage
    Given ich habe meine Daten aus einem anderen Tool in das Format von "templates/import-template.json" überführt
      (Felder, Typen und Wertebereiche wie in "templates/README.md" beschrieben, notfalls per KI-Konvertierung)
    When ich diese Datei über "Backup importieren…" einlese
    Then wird sie wie ein reguläres Backup behandelt (dieselben Prüfungen: Schemaversion, Sicherheitsabfrage,
      Fehlertoleranz pro Eintrag, Auto-Increment-Zähler)
