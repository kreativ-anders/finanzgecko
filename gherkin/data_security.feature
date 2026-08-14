# Quelle: lib/data/app_store.dart, lib/data/secure_key_store.dart, lib/data/app_schema.dart, lib/constants.dart, lib/data/sandbox_migration.dart
# Implementierung: lib/data/app_store.dart
@security @persistence
Feature: Datenspeicherung, Verschlüsselung und Integrität
  Als Nutzer:in erwarte ich, dass meine Vermögensdaten ausschließlich lokal, verschlüsselt und robust gegenüber
  Abstürzen oder beschädigten Dateien gespeichert werden — ohne jemals stillschweigend Daten zu verlieren.

  Scenario: Erste Nutzung erzeugt einen neuen Verschlüsselungsschlüssel
    Given die App startet zum ersten Mal auf diesem Gerät
    Then wird ein neuer 256-Bit-AES-Schlüssel erzeugt
    And er wird im OS-Credential-Speicher abgelegt (Windows Credential Locker, macOS Schlüsselbund, Linux
      libsecret/kwallet je nach Plattform) — niemals in der Datendatei selbst

  Scenario: Wiederverwendung des Schlüssels bei jedem weiteren Start
    Given ein Schlüssel wurde bereits einmal erzeugt
    Then wird bei jedem weiteren Start derselbe Schlüssel aus dem Credential-Speicher gelesen, kein neuer erzeugt

  Scenario: Die Datenbank-Datei ist ohne den Schlüssel unlesbar
    Given die Datendatei wird außerhalb der App geöffnet
    Then enthält sie nur eine "Envelope"-Struktur aus Version, Nonce, Chiffretext und MAC (AES-256-GCM)
    And ohne den zugehörigen Schlüssel im OS-Credential-Speicher ist der Inhalt nicht entschlüsselbar

  Scenario: Schreibvorgänge sind atomar
    Given eine Änderung wird gespeichert
    Then wird zunächst in eine temporäre Datei geschrieben, dann die alte Datei ersetzt, dann umbenannt
    And ein Absturz mitten im Schreibvorgang darf niemals eine halb geschriebene Hauptdatei hinterlassen

  Scenario: Parallele Schreibvorgänge werden serialisiert
    Given zwei Speicheraktionen werden nahezu gleichzeitig ausgelöst
    Then läuft die zweite erst vollständig, nachdem die erste ihre temporäre Datei bereits umbenannt hat
    And ein Fehler in einem Schreibvorgang blockiert nicht die nachfolgenden

  Scenario: Unlesbare oder fremde Dateien werden nie stillschweigend überschrieben
    Given am erwarteten Dateipfad liegt eine Datei, die kein gültiges Envelope-JSON ist (falsches Format, kaputtes
      JSON, fehlgeschlagene Entschlüsselung)
    When die App startet
    Then wird diese Datei zuerst als Kopie unter "<dateiname>.unreadable-<Zeitstempel>" gesichert
    And erst danach startet die App mit Standardwerten und schreibt eine neue Datei

  Scenario: Fehlende Datei beim ersten Start
    Given am erwarteten Pfad existiert noch keine Datei
    Then startet die App mit Standardwerten, ohne eine Quarantäne-Kopie anzulegen (nichts zu verlieren)

  Scenario: Der Speicherort ist bewusst nicht wählbar
    Given ich öffne Einstellungen → Sicherheit
    Then sehe ich den Speicherort, aber keine Möglichkeit, ihn zu ändern
    And ein Hinweis erklärt in Alltagssprache, dass die Datei zu diesem Computer gehört, dass eine Kopie in einem
      Cloud-Ordner bei einem Plattenschaden hilft, aber nicht bei einem neuen Computer oder nach einer
      Neuinstallation, und dass ein wiederherstellbares Backup nur der Export liefert
    And der Hinweis steht dauerhaft dort, nicht als einmalig wegklickbarer Dialog

  Scenario: Datei von einem anderen Rechner wird erkannt, nicht in Quarantäne geschoben
    Given die Datei enthält eine Schlüsselkennung (keyId), die nicht zum Schlüssel dieses Rechners passt
    When die App startet
    Then bricht der Start mit einer Erklärung ab ("Diese Datei gehört zu einem anderen Computer")
    And die Datei bleibt byte-identisch liegen — keine Quarantäne-Kopie, kein Schreibvorgang
    And die Erklärung verweist auf den Weg über "Backup exportieren" und "Backup importieren"
    Given derselbe Rechner erhält seinen ursprünglichen Schlüssel zurück
    Then öffnet die Datei wieder normal

  Scenario: Schlüsselkennung ist additiv und bricht ältere App-Versionen nicht
    Given eine neu geschriebene Datendatei
    Then enthält der Envelope zusätzlich das Klartextfeld "keyId" (8 Byte SHA-256 des Schlüssels)
    And die Envelope-Version bleibt bei 1, weil die Prüfung nur die vier bekannten Felder betrachtet
    And eine ältere App-Version liest diese Datei unverändert weiter
    Given eine Datei aus der Zeit vor diesem Feld (ohne "keyId")
    Then wird sie wie bisher geladen, ohne Prüfung der Kennung

  Scenario: Datendatei aus einer neueren Schema-Version wird bewahrt, nicht überschrieben
    Given die Datendatei trägt eine "schemaVersion" größer als die von diesem Build unterstützte Version
      (z. B. weil eine neuere App-Version lief und die App danach herabgestuft wurde)
    When die App startet
    Then wird die Datei NICHT fehlertolerant eingelesen (das würde unbekannte Felder stillschweigend verwerfen)
    And sie wird zuerst unverändert als Kopie unter "<dateiname>.newer-version-<Zeitstempel>" gesichert
    And erst danach startet die App mit Standardwerten — die neuere Datei bleibt vollständig erhalten, sodass
      ein Update der App die Daten wieder lesbar macht

  Scenario: Datendatei aus einer älteren Schema-Version wird migriert — mit vorheriger Sicherung
    Given die Datendatei trägt eine "schemaVersion" kleiner als die aktuell unterstützte Version
    When die App startet
    Then wird zuerst eine unveränderte, verschlüsselte Kopie der bisherigen Datei als
      "pre-migrate-backup-<Zeitstempel>.json" im Datenverzeichnis abgelegt
    And erst danach wird die Datei im aktuellen Format neu geschrieben und mit der aktuellen Schema-Version gestempelt
    And ein Fehler bei dieser Sicherung darf den Start nicht verhindern (best effort)

  Scenario: Einzelne fehlerhafte Datensätze gefährden nicht die ganze Datei
    Given die Datenbank enthält eine Liste (Konten/Kontostände/Vermögenswerte/Fixposten) mit einem einzelnen
      fehlerhaften Eintrag
    Then wird beim Laden nur dieser Eintrag übersprungen
    And alle anderen Einträge und Bereiche der Datei bleiben nutzbar

  Scenario: Dateiberechtigungen als zusätzliche Verteidigungsebene
    Given die App hat das Datenverzeichnis und die Datendatei angelegt
    Then sind unter Linux/macOS die Zugriffsrechte auf 700 (Verzeichnis) bzw. 600 (Datei) gesetzt
    And unter Windows ist eine ACL gesetzt, die nur dem aktuellen Benutzer Zugriff erlaubt
    And dies gilt als Ergänzung zur Verschlüsselung, nicht als deren Ersatz

  Scenario: Wechselkurs-Cache ist bewusst unverschlüsselt und getrennt
    Then liegt der Wechselkurs-Cache in einer eigenen Datei "finanzgecko-rates.json" neben der Hauptdatenbank
    And ein Parse-Fehler dieser Datei wird stillschweigend ignoriert (Kurse sind jederzeit neu abrufbar, kein
      Datenverlustrisiko)

  Scenario: macOS — die Schlüsselbund-Variante hängt an der Auslieferungsform
    Given die App wurde als DMG ausgeliefert (Developer-ID-Build, der Standardfall)
    Then wird die klassische (nicht Data-Protection-) Keychain-Variante verwendet
    And der erste Schlüssel-Zugriff schlägt NICHT mit "A required entitlement isn't present." fehl
    And das gilt unverändert für lokal gebaute, ad-hoc-signierte Builds ohne Apple-Developer-Team
    Given die App wurde für den Mac App Store gebaut (kIsMacAppStore)
    Then wird die Data-Protection-Keychain-Variante verwendet — eine sandboxed App hat auf die klassische
      Keychain keinen Zugriff, hier ist die Variante also erzwungen und nicht bevorzugt
    And das setzt das Entitlement "keychain-access-groups" mit Team-ID-Präfix voraus
      (macos/Runner/AppStore.entitlements, eingesetzt von packaging/macos/build_appstore.sh)
    And beide Varianten legen ihre Schlüssel getrennt ab: keine der beiden findet den Schlüssel der anderen

  Scenario: macOS — App-Sandbox ist in allen Builds aktiv
    Given die App läuft auf macOS
    Then läuft sie mit aktiver App-Sandbox, unabhängig von der Auslieferungsform
    And "$HOME" zeigt dadurch auf "~/Library/Containers/de.finanzgecko.app/Data", worunter derselbe relative
      Pfad erneut entsteht: resolveDataDirectory() bleibt unverändert, nur der Wurzelpfad ist ein anderer
    And die Dateiberechtigungs-Härtung (chmod) entfällt im App-Store-Build, weil der Container bereits pro App
      und Benutzer abgeschottet ist

  Scenario: macOS — Bestandsdaten werden einmalig in den Container übernommen
    Given eine Installation aus einer Version vor der Sandbox hat Daten unter
      "~/Library/Application Support/de.finanzgecko.app/" liegen
    And der Container ist leer (erster Start des sandboxed Builds)
    When die App startet
    Then werden Datendatei und Wechselkurs-Cache in den Container KOPIERT, bevor zum ersten Mal gelesen wird
    And der Zielordner heißt dabei "FinanzGecko" statt wie die Application-ID: ein auf ".app" endender
      Ordnername gilt dem Finder als Programmbündel. Die Umbenennung reist auf derselben einmaligen Kopie mit,
      statt später eine eigene Migration zu brauchen
    And die Originaldateien bleiben unverändert liegen und werden NICHT gelöscht — sie sind die Rückfalloption,
      falls die Kopie fehlerhaft war
    And im Container liegt anschließend eine Notiz "migrated-from-unsandboxed.txt", die den alten Pfad nennt
    Given im Container liegt bereits eine Datendatei
    Then findet keine Migration statt — der Container gewinnt immer, damit ein zweiter Start oder ein bereits
      importiertes Backup nicht überschrieben wird
    Given es gibt weder im Container noch am alten Pfad Daten
    Then ist dies eine echte Neuinstallation und die App startet regulär leer
    Given der alte Pfad existiert, ist aber nicht lesbar (fehlendes oder falsch zugeschnittenes
      temporary-exception-Entitlement)
    Then wird dies als Fehlschlag festgehalten und NICHT als Neuinstallation behandelt — die beiden Fälle sehen
      für Nutzer:innen gleich aus (leere App), bedeuten aber das Gegenteil
