# Quelle: lib/ui/views/settings_view.dart, lib/ui/backup_actions.dart, lib/utils/csv_export.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/data/app_schema.dart, lib/ui/theme.dart, lib/constants.dart, lib/ui/widgets/reset_confirm_dialog.dart, lib/services/currency_service.dart, lib/services/update_service.dart, lib/utils/update_assets.dart
# Implementierung: lib/ui/views/settings_view.dart
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

  Scenario: Erscheinungsbild wählen
    Then zeigt der Abschnitt "Erscheinungsbild" eine Auswahl mit "System", "Hell" und "Dunkel", standardmäßig "System"
    When ich "Hell" bzw. "Dunkel" wähle
    Then wird die App sofort auf die entsprechende Farbpalette umgestellt (keine separate Speichern-Aktion nötig)
    And ich sehe eine Speicher-Bestätigung
    And die Wahl bleibt über einen Neustart der App hinweg erhalten
    Given "System" ist gewählt
    Then folgt die App der Hell-/Dunkel-Einstellung des Betriebssystems und wechselt automatisch mit, wenn das
      Betriebssystem seine Einstellung ändert

  Scenario: Desktop-Benachrichtigungen ein-/ausschalten
    Then zeigt der Abschnitt "Benachrichtigungen" einen Schalter "Desktop-Benachrichtigungen", standardmäßig aktiv
    When ich den Schalter deaktiviere
    Then werden ab sofort keine OS-Benachrichtigungen mehr gesendet (Detailverhalten: siehe
      gherkin/notifications.feature)

  Scenario: Sicherheits-Informationen sind einsehbar, aber nicht sensibel
    Then zeigt der Abschnitt "Sicherheit" ein Badge "Verschlüsselung aktiv"
    And das Verfahren "AES-256-GCM"
    And den plattformspezifischen Schlüsselspeicher-Namen (Windows Credential Locker / macOS Schlüsselbund /
      Linux Secret Service, je nach Betriebssystem)
    And den Speicherort der Datendatei, mit einem Button zum Öffnen im Dateimanager

  Scenario: Speicherort im Dateimanager öffnen
    When ich auf den "Im Dateimanager öffnen"-Button neben dem Speicherort klicke
    Then öffnet sich der native Dateimanager des Betriebssystems am Datenverzeichnis
    And unter macOS wird bewusst das ÜBERGEORDNETE Verzeichnis geöffnet: das Datenverzeichnis heißt wie die
      Application-ID und endet damit auf ".app", was macOS für ein Programmbündel hält — es versucht dann, den
      Ordner zu starten, und meldet "beschädigt oder unvollständig". Ein angehängter Schrägstrich hilft dabei
      NICHT (am 2026-08-13 gemessen), das übergeordnete Verzeichnis zu öffnen schon
    And unter Linux und Windows wird weiterhin direkt das Datenverzeichnis geöffnet — dort ist ".app" keine
      besondere Endung
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

  Scenario: Daten zusätzlich als CSV-Tabellen exportieren
    Given ich bin im Export-Bereich
    When ich auf "Als CSV-Tabellen exportieren…" klicke
    Then öffnet sich ein nativer Ordner-Dialog (kein Datei-Dialog: der Export besteht aus mehreren Dateien)
    And in den gewählten Ordner werden vier UTF-8-CSV-Dateien (mit BOM) mit festen Namen geschrieben:
      "finanzgecko-konten-<YYYY-MM-DD>.csv" — je Konto: Konto-ID, Konto, Bank, Kontotyp
      "finanzgecko-kontostaende-<YYYY-MM-DD>.csv" — je Konto und Monat: Monat, Konto-ID, Konto, Währung, Betrag
      "finanzgecko-fixposten-<YYYY-MM-DD>.csv" — je Fixposten: Fixposten, Art (Einnahme/Ausgabe), Intervall,
      Währung, Betrag
      "finanzgecko-vermoegenswerte-<YYYY-MM-DD>.csv" — je Vermögenswert: Vermögenswert, Wert (Basiswährung)
    And alle Dateien sind ";"-getrennt, nutzen Dezimalkomma und RFC-4180-Quoting
    And "Konto-ID" verbindet die Konten- mit der Kontostände-Tabelle — Stammdaten (Bank, Kontotyp) stehen genau
      einmal statt in jeder Monatszeile
    And jeder Betrag steht genau einmal, in seiner Erfassungswährung — kein Kurs, kein zweiter umgerechneter Betrag,
      keine abgeleitete Spalte (auch kein Monatsäquivalent: das Intervall steht daneben)
    And Umrechnung ist Sache der auswertenden Tabelle, nicht des Exports
    And der Fixposten-Betrag gilt je Intervall, nicht je Monat
    And Einnahmen stehen vor Ausgaben und Konten/Fixposten/Vermögenswerte sind nach Namen sortiert, wie in den
      jeweiligen Ansichten
    And archivierte Konten sind enthalten (sonst zeigten ihre historischen Kontostände ins Leere), aber nicht
      als archiviert markiert
    And dieser Export zählt NICHT als Backup — der Backup-Reminder und "zuletzt exportiert" bleiben unberührt
    And die CSVs sind bewusst nicht wieder importierbar (nur der JSON-Export ist ein verlustfreier Round-Trip)

  Scenario: Ein leerer Bereich ergibt trotzdem eine Tabelle
    Given ich habe (noch) keine Fixposten oder Vermögenswerte erfasst
    When ich die Daten als CSV exportiere
    Then entstehen trotzdem vier Dateien; die leeren enthalten nur ihre Kopfzeile

  Scenario: Vorhandene Dateien werden nur nach Rückfrage überschrieben
    Given im gewählten Ordner liegen bereits Dateien mit diesen Namen (z. B. ein früherer Export von heute)
    When ich den Ordner bestätige
    Then erscheint genau eine Rückfrage "Dateien überschreiben?" für den gesamten Satz
    And bei "Abbrechen" wird keine einzige Datei geschrieben

  Scenario: CSV-Export neutralisiert Formel-Injection in freien Textfeldern
    Given ein Konto-Name, eine Bank, ein Fixposten- oder ein Vermögenswert-Name beginnt mit
      "=", "+", "-" oder "@" (z. B. aus einem importierten Backup)
    When ich die Daten als CSV exportiere
    Then wird dem betroffenen Feld ein führendes "'" vorangestellt, damit Tabellenkalkulationen (Excel/LibreOffice)
      es beim Öffnen nicht als Formel/DDE-Kommando interpretieren
    And Zahlen-/Enum-Spalten (Kontotyp, Intervall, Währung, Betrag) bleiben unverändert, damit z. B. negative Beträge
      weiterhin normal in Summenformeln funktionieren

  Scenario: Hilfe-Bereich zeigt App- und Systeminformationen
    Then zeigt der Abschnitt "Hilfe" die installierte Version samt Build-Nummer, direkt aus der
      laufenden Installation ausgelesen (stimmt dadurch immer mit dem tatsächlich installierten Release
      überein, auch nach einem über den Release-Workflow automatisch hochgezählten Tag)
    And dynamisch ermittelte Systeminformationen: Betriebssystem samt Version, Anzahl Prozessorkerne,
      Systemsprache, Dart-Laufzeitversion
    And die Auflösung(en) aller angeschlossenen Bildschirme (macht einen Mehrschirm-/externen-Monitor-Aufbau
      auf einen Blick erkennbar) sowie die aktuelle Fenstergröße der App
    And einen Live-Erreichbarkeits-Check der Wechselkurs-API ("Erreichbar" / "Nicht erreichbar" / "Prüfe…"),
      begleitet vom Hinweis, dass dies die einzige automatische externe Netzwerkverbindung der App ist (kein
      Tracking, keine Analyse-Dienste) — macht diese Zeile zugleich zur Antwort auf "welche Berechtigungen
      nutzt die App"
    And einen Link "Nach Updates suchen", "E-Mail-Support" (mailto an die Support-Adresse) sowie
      "Fehler melden (GitHub)" zum Issue-Tracker des Projekts
    And einen Button "Debug-Informationen kopieren", der Version-, System- und Verbindungsinfos als Text in
      die Zwischenablage kopiert, bestätigt per Snackbar "Debug-Informationen kopiert."

  Scenario: Manuelle Update-Prüfung im Hilfe-Bereich
    Given ich bin im Abschnitt "Hilfe"
    When ich auf den Link "Nach Updates suchen" klicke
    Then fragt die App den neuesten Release-Tag der öffentlichen GitHub-Releases-API des Projekts
      (kreativ-anders/finanzgecko) ab und vergleicht ihn mit der installierten Version
    And diese Abfrage findet ausschließlich bei diesem Klick statt — kein automatischer Hintergrund-Check
      beim App-Start oder periodisch währenddessen (siehe AI_MASTER.md Abschnitt 6)
    Given eine neuere Version ist verfügbar
    Then öffnet sich ein Dialog "Update verfügbar" mit der neuen Versionsnummer und der aktuell installierten
      Version, sowie den Buttons "Später" (schließt den Dialog ohne Aktion) und "Herunterladen"

  Scenario: Update herunterladen und gegen die Prüfsumme halten
    Given im Dialog "Update verfügbar" habe ich "Herunterladen" gewählt
    Then fragt die App über einen Datei-Dialog, wo die Datei gespeichert werden soll (kein stilles Ablegen im
      Download-Ordner: das löste unter macOS eine eigene Systemabfrage "Zugriff auf den Ordner Downloads" aus)
    And vorgeschlagen wird der Name des Release-Assets, das zum laufenden Betriebssystem gehört
      (-mac.dmg, -Setup.exe bzw. -x86_64.AppImage — dieselben Endungen wie in release.yml und
      docs/download.html, siehe gherkin/executable/update_assets.feature)
    When ich einen Speicherort bestätige
    Then lädt die App die Datei mit Fortschrittsanzeige und vergleicht sie mit der Datei SHA256SUMS aus
      demselben Release
    And erst wenn die Prüfsumme übereinstimmt, wird die Datei überhaupt geschrieben — eine ungeprüfte Datei
      landet nie im gewählten Ordner
    Then zeigt ein Dialog "Update geladen und geprüft" den plattformabhängigen nächsten Schritt sowie einen
      Button "Im Ordner zeigen"
    And dieser Dialog fordert zuerst dazu auf, FinanzGecko zu beenden, bevor die neue Version installiert wird
      (eine laufende Anwendung zu ersetzen führt zu Fehlern) — bewusst einmal für alle Plattformen formuliert,
      nicht je Plattform, damit der Hinweis bei keiner fehlen kann
    And die App führt die Datei NICHT aus und ersetzt sich nicht selbst — unter Windows hieße "Installer
      starten" eine frisch heruntergeladene ausführbare Datei zu starten
    Given die Prüfsumme weicht ab
    Then erscheint ein Dialog "Prüfsumme stimmt nicht" (bewusst kein Snackbar) und die Datei wurde nicht
      gespeichert
    Given das Release enthält keine Datei für dieses Betriebssystem oder keine SHA256SUMS (ältere Releases)
    Then wird nichts geraten, sondern die Download-Seite der Website geöffnet
    Given die GitHub-Antwort nennt für ein Asset eine Adresse, die nicht per HTTPS auf einen bekannten
      GitHub-Release-Host zeigt
    Then wird dieser Host nicht einmal kontaktiert und derselbe Weg wie oben eingeschlagen (Download-Seite)
    And ebenso wird abgebrochen, wenn die Datei die zulässige Größe überschreitet — sie wird vor der
      Prüfsummen-Kontrolle vollständig im Arbeitsspeicher gehalten
    And dieser Fall nutzt bewusst einen Dialog statt einer Snackbar (wie bei den beiden Fällen unten): eine
      tatsächlich handlungsrelevante Meldung soll nicht wie eine bloße Bestätigung von selbst wieder verschwinden
    Given die installierte Version ist bereits die neueste
    Then zeigt eine Snackbar "Du verwendest bereits die neueste Version (<Version>)."
    Given die Abfrage schlägt fehl (keine Internetverbindung, Repository noch nicht öffentlich, GitHub
      nicht erreichbar, o. ä.)
    Then wird kein Fehler geworfen, sondern eine Fehler-Snackbar "Update-Prüfung fehlgeschlagen — bitte
      später erneut versuchen." angezeigt

  Scenario: Im App-Store-Build entfällt die Update-Prüfung vollständig
    Given die App wurde für den Mac App Store gebaut (kIsMacAppStore, siehe gherkin/data_security.feature)
    Then fehlt im Abschnitt "Hilfe" der Link "Nach Updates suchen" — die übrigen Links ("E-Mail-Support",
      "Fehler melden (GitHub)", "Debug-Informationen kopieren") bleiben unverändert
    And der Netzwerk-Hinweis nennt nur noch die Wechselkurs-API und schließt mit "Updates erhältst du über den
      App Store." — der Satz zur GitHub-Releases-API entfällt, weil dieser Aufruf in diesem Build nicht
      existiert; er ist eine Datenschutz-Aussage und darf nichts behaupten, was nicht stattfindet
    And das ist keine Geschmacksfrage: ein zweiter Selbst-Update-Weg neben dem App Store verstößt gegen
      App-Review-Richtlinie 2.4.5
    And weil kIsMacAppStore eine Compile-Zeit-Konstante ist, entfernt der Tree-Shaker den Download-Pfad aus
      dem Binary, statt nur den Button zu verbergen

  Scenario: App zurücksetzen erfordert eine getippte Bestätigungsphrase
    When ich im rot umrandeten Bereich "Zurücksetzen" auf "App zurücksetzen…" klicke
    Then öffnet sich ein Dialog, der erklärt, dass alle Konten, Kontostände, Vermögenswerte und Fixposten
      unwiderruflich gelöscht werden und die Basiswährung zurückgesetzt wird
    And der Bestätigen-Button ist erst aktiv, wenn ich exakt "ZURÜCKSETZEN" ins Textfeld eingetippt habe

  Scenario: Vor jedem Zurücksetzen wird automatisch eine Sicherung des vorherigen Stands angelegt
    Given ich habe "ZURÜCKSETZEN" korrekt eingetippt und bestätigt
    Then wird zuvor der bisherige Datenstand als eigene, verschlüsselte Datei
      "pre-reset-backup-<Zeitstempel>.json" im Datenverzeichnis abgelegt (wie beim Import, siehe backup_restore.feature)
    And ein Fehler bei dieser Sicherung darf das eigentliche Zurücksetzen nicht verhindern (best effort)

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
