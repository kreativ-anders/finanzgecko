# Quelle: lib/utils/update_assets.dart
# Implementierung: lib/utils/update_assets.dart
# Ausführbar: test/bdd/update_assets_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @settings
Feature: Update-Datei je Plattform auswählen und gegen die Prüfsumme halten

  # Die manuelle Update-Prüfung (siehe gherkin/settings.feature) lädt nach Bestätigung genau die Datei
  # herunter, die zum laufenden Betriebssystem gehört, und vergleicht sie mit der im Release
  # veröffentlichten SHA256SUMS-Datei. Beides ist reine Logik und hier ohne Netz und ohne Dateisystem
  # festgeschrieben. Die Endungen sind dieselben wie in release.yml und in docs/download.html.
  #
  # Freitext-Beschreibungen sind hier bewusst Kommentare: der Runner
  # (test/support/gherkin_runner.dart) akzeptiert unter "Feature:" nur
  # Kommentare, Tags und Schritte und wirft bei allem anderen.

  Scenario: macOS bekommt das Disk-Image
    When ich das Asset für "macos" aus "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage" wähle
    Then ist das gewählte Asset "FinanzGecko-1.7.0-mac.dmg"

  Scenario: Windows bekommt den Installer
    When ich das Asset für "windows" aus "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage" wähle
    Then ist das gewählte Asset "FinanzGecko-1.7.0-Setup.exe"

  Scenario: Linux bekommt das AppImage
    When ich das Asset für "linux" aus "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage" wähle
    Then ist das gewählte Asset "FinanzGecko-1.7.0-x86_64.AppImage"

  # Die SHA256SUMS-Datei liegt im selben Release und darf nie als Update angeboten werden.
  Scenario: Die Prüfsummen-Datei wird nie als Update gewählt
    When ich das Asset für "macos" aus "SHA256SUMS, FinanzGecko-1.7.0-mac.dmg" wähle
    Then ist das gewählte Asset "FinanzGecko-1.7.0-mac.dmg"

  # Kein Raten: lieber gar kein Download und der Fallback auf die Download-Seite.
  Scenario: Fehlt das Asset der Plattform, wird keines gewählt
    When ich das Asset für "windows" aus "FinanzGecko-1.7.0-mac.dmg, SHA256SUMS" wähle
    Then wird kein Asset gewählt

  Scenario: Unbekannte Plattform wählt kein Asset
    When ich das Asset für "fuchsia" aus "FinanzGecko-1.7.0-mac.dmg" wähle
    Then wird kein Asset gewählt

  Scenario: Prüfsummen-Datei wird in Dateiname und Hash zerlegt
    When ich die Prüfsummen "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111  FinanzGecko-1.7.0-mac.dmg" parse
    Then ist der Hash für "FinanzGecko-1.7.0-mac.dmg" gleich "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"

  # Der Stern markiert bei sha256sum den Binärmodus und gehört nicht zum Namen.
  Scenario: Binärmodus-Markierung gehört nicht zum Dateinamen
    When ich die Prüfsummen "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222 *FinanzGecko-1.7.0-Setup.exe" parse
    Then ist der Hash für "FinanzGecko-1.7.0-Setup.exe" gleich "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"

  Scenario: Unbrauchbare Zeilen werden übersprungen statt zu scheitern
    When ich die Prüfsummen "### Kommentar\nzu kurz  x.dmg\ncccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333  FinanzGecko-1.7.0-mac.dmg" parse
    Then enthält das Ergebnis genau 1 Eintrag
    And ist der Hash für "FinanzGecko-1.7.0-mac.dmg" gleich "cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333"

  Scenario: Ein unbekannter Dateiname liefert keinen Hash
    When ich die Prüfsummen "dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444  FinanzGecko-1.7.0-mac.dmg" parse
    Then gibt es keinen Hash für "FinanzGecko-1.7.0-Setup.exe"

  # Bytes unter 0x10 müssen zweistellig bleiben, sonst ist der Digest zu kurz und jeder Vergleich scheitert.
  Scenario: Kleine Byte-Werte behalten die führende Null
    When ich die Bytes "0, 1, 15, 16, 255" hex-kodiere
    Then ist die Hex-Darstellung "00010f10ff"

  Scenario: Groß- und Kleinschreibung des Digests ist egal
    When ich den Digest "ABCDEF1234" mit "abcdef1234" vergleiche
    Then stimmen die Digests überein

  Scenario: Ein abweichender Digest wird erkannt
    When ich den Digest "abcdef1234" mit "abcdef1235" vergleiche
    Then stimmen die Digests nicht überein
