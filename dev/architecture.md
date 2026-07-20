# Architektur-Entscheidungen

Für die vollständige Architektur/Datenfluss/Domänen-Referenz siehe [AI_MASTER.md](../AI_MASTER.md). Hier nur die
Entscheidungen, die typische Rückfragen beantworten.

## Warum keine Datenbank-Engine

Eine einzige JSON-Datei im OS-Datenverzeichnis, keine SQLite/Hive/Isar-Abhängigkeit. Für die Datenmenge eines
persönlichen Vermögenstrackers (ein paar hundert Kontostände) reicht "ganze Datei lesen/schreiben" und hält den Code
einfach.

**Dateipfad:** `<Datenverzeichnis>/finanzgecko-data.json` (Verzeichnis je OS: [setup.md](setup.md)).

- **Verschlüsselung:** AES-256-GCM (`lib/data/app_store.dart`, `lib/data/secure_key_store.dart`). Schlüssel liegt im
  OS-Credential-Speicher (Windows Credential Locker, macOS Keychain, Linux libsecret/kwallet), pro Installation
  einmalig erzeugt.
- Nur eine echte Envelope-Datei wird als Datenquelle akzeptiert; alles andere wird vor dem Überschreiben unter
  `*.unreadable-<Zeitstempel>` gesichert, die App startet dann mit Standardwerten.
- Dateirechte als zusätzliche Ebene: `chmod 0700`/`0600` (Linux/macOS), ACL via `icacls` (Windows).
- Wechselkurse (öffentliche EZB-Referenzkurse) liegen bewusst **nicht** in der verschlüsselten Datei, sondern
  klartext in `finanzgecko-rates.json` daneben — ein neu gecachter Kurs löst so kein Neu-Verschlüsseln der ganzen
  Datenbank aus. Alle Schreibvorgänge laufen über eine gemeinsame Warteschlange.

**macOS — zwei bewusste, nicht offensichtliche Einstellungen:**

- `SecureKeyStore` nutzt `MacOsOptions(usesDataProtectionKeychain: false)`. Der Plugin-Default (`true`) bindet den
  Schlüssel an die Team-ID der Code-Signatur — bei einem unsigniert/ad-hoc-signierten Build (kein Apple-Developer-
  Team) bricht der erste Schlüsselzugriff mit `PlatformException(..., -34018, "A required entitlement isn't
  present.")` ab. Ohne Team-ID-Bindung funktioniert es auch ohne Zertifikat.
- App-Sandbox ist deaktiviert (`com.apple.security.app-sandbox = false`, beide `.entitlements`) — mit aktiver
  Sandbox virtualisiert macOS `$HOME` auf einen Container-Pfad, wodurch `resolveDataDirectory()` am dokumentierten
  Pfad vorbeischreiben würde und dort abgelegte Bestandsdaten unauffindbar wären.

Beide Einstellungen **nicht ohne Rücksprache rückgängig machen** (siehe AI_MASTER "Regeln für KI-Agenten").

## Fensterverhalten

Startet mit zuletzt verwendeter Größe (Standard 1280×860, Mindestgröße 960×640, `window_manager`) plus
Maximiert-Status. Bewusst **keine** gespeicherte Bildschirmposition — sonst landet das Fenster nach einem
Monitor-/Auflösungswechsel außerhalb des sichtbaren Bereichs.

## In-App-Menü statt nativer Menüleiste

Flutters `PlatformMenuBar` unterstützt nur macOS. Linux/Windows bekommen stattdessen einen "Datei"-Menüpunkt im
eigenen Fensterkopf (plattformübergreifend identisch) plus globale Tastenkürzel (<kbd>Strg</kbd>/<kbd>Cmd</kbd>+
<kbd>E</kbd>/<kbd>I</kbd>/<kbd>Q</kbd>).
