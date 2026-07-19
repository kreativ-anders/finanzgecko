# Quelle: lib/data/app_store.dart, lib/data/secure_key_store.dart, lib/data/app_schema.dart
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

  Scenario: macOS — Schlüsselbund-Zugriff funktioniert auch ohne Code-Signing-Zertifikat
    Given die App ist ad-hoc-signiert, ohne Apple-Developer-Team
    Then wird die klassische (nicht Data-Protection-) Keychain-Variante verwendet
    And der erste Schlüssel-Zugriff schlägt NICHT mit "A required entitlement isn't present." fehl

  Scenario: macOS — App-Sandbox ist deaktiviert, damit der dokumentierte Datenpfad stimmt
    Given die App läuft auf macOS
    Then schreibt sie ihre Daten direkt unter "~/Library/Application Support/de.finanzgecko.app/" (echter Home-Pfad)
    And NICHT in einen sandboxed Container-Pfad, der vom dokumentierten Pfad abweichen würde
