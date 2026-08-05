# Quelle: lib/ui/backup_actions.dart, lib/ui/navigation_shell.dart, lib/data/app_store.dart, lib/data/app_schema.dart,
#   lib/data/backup_crypto.dart, lib/ui/widgets/backup_passphrase_dialog.dart
# Implementierung: lib/ui/backup_actions.dart
@backup
Feature: Backup exportieren und importieren
  Als Nutzer:in kann ich meine gesamten Daten als JSON exportieren — wahlweise im Klartext oder mit einem Passwort
  geschützt — und wieder importieren. Der Export ist der einzige Weg, der auf einem anderen Rechner funktioniert:
  die Datendatei selbst ist an ihr Gerät gebunden (siehe gherkin/data_security.feature).

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
    But der Export enthält NICHT den Wechselkurs-Cache, interne Zähler (meta), die Fenstergeometrie
      oder die Konto-Akzentfarbe (color) — Letztere wird beim Import aus der Bank abgeleitet

  Scenario: Export-Dialog abgebrochen
    Given ich breche den Speichern-Dialog ab
    Then passiert nichts — kein Fehler, kein Zeitstempel-Update

  Scenario: Vor dem Speicherort wird nach einem Passwort gefragt
    Given ich starte einen Export
    Then erscheint zuerst die Frage, ob das Backup mit einem Passwort geschützt werden soll
    And es gibt dafür zwei eigene Knöpfe, "Ohne Passwort" und "Mit Passwort schützen" — kein leeres Feld als
      stille Voreinstellung, damit ein weggeklickter Dialog keinen ungeschützten Export erzeugt
    And ein Hinweis nennt die Folge: ohne dieses Passwort lässt sich das Backup später nicht mehr öffnen, die
      Daten in der App bleiben davon aber unberührt
    When ich den Dialog abbreche
    Then wird gar nichts exportiert

  Scenario: Export ohne Passwort bleibt exakt wie bisher
    Given ich wähle "Ohne Passwort"
    Then wird dieselbe unverschlüsselte, eingerückte JSON-Datei geschrieben wie vor diesem Feature
    And bereits vorhandene Backups bleiben dadurch gültig

  Scenario: Export mit Passwort
    Given ich vergebe ein Passwort und wiederhole es
    Then wird eine verschlüsselte Datei geschrieben (AES-256-GCM, Schlüssel per PBKDF2-HMAC-SHA256 aus dem Passwort)
    And die Datei enthält weder Klartextdaten noch das Passwort selbst
    And Verfahren, Salt und Iterationszahl stehen in der Datei, damit sie später verschärft werden können, ohne
      alte Backups unlesbar zu machen
    And zwei Exporte desselben Standes ergeben unterschiedliche Dateien (eigenes Salt, eigene Nonce)
    But solange die beiden Passwortfelder nicht übereinstimmen, ist "Mit Passwort schützen" nicht auswählbar

  Scenario: Import erkennt das Format selbst
    Given ich wähle eine Backup-Datei zum Import
    Then erkennt die App an der Struktur der Datei, ob sie geschützt ist — nicht an Dateiendung oder Name
    And ein unverschlüsseltes Backup wird ohne jede Rückfrage eingelesen wie bisher

  Scenario: Import einer passwortgeschützten Datei
    Given die gewählte Datei ist passwortgeschützt
    Then werde ich nach dem Passwort gefragt
    When ich ein falsches Passwort eingebe
    Then werde ich mit dem Hinweis "Das Passwort stimmt nicht." erneut gefragt, statt den Vorgang abzubrechen
    When ich den Dialog abbreche
    Then bleiben meine aktuellen Daten unverändert
    Given die Datei wurde nachträglich verändert
    Then schlägt das Entschlüsseln ebenso fehl wie bei einem falschen Passwort (der MAC schlägt an)

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

  Scenario: Import erzwingt die Bank→Farbe-Regel und lehnt unbekannte Banken ab
    Given eine Backup-/Migrationsdatei enthält Konten
    When der Import läuft
    Then wird die Akzentfarbe jedes Kontos aus seiner Bank neu abgeleitet (die Farbe aus der Datei wird ignoriert):
      bekannte Bank → Markenfarbe der Bank, leere Bank (z. B. Bargeld/Krypto) → Kontotyp-Farbe
    But enthält ein Konto eine nicht-leere, unbekannte Bank, wird der GESAMTE Import mit einer klaren
      Fehlermeldung ("Import abgebrochen bei Konto …") abgebrochen und die aktuellen Daten bleiben unverändert

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
