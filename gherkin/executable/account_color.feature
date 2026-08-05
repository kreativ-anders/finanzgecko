# Quelle: lib/constants.dart
# Implementierung: lib/constants.dart
# Ausführbar: test/bdd/account_color_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @accounts
Feature: Konto-Akzentfarbe wird aus der Bank abgeleitet

  Scenario: Bekannte Bank liefert ihre Markenfarbe
    When ich die Farbe für Bank "DKB" und Kontotyp "Girokonto" auflöse
    Then ist die Farbe die Markenfarbe der Bank "DKB"

  Scenario: Bekannte Bank ist case-insensitiv
    When ich die Farbe für Bank "trade republic" und Kontotyp "Depot" auflöse
    Then ist die Farbe die Markenfarbe der Bank "Trade Republic"

  Scenario: Leere Bank fällt auf die Kontotyp-Farbe zurück
    When ich die Farbe für Bank "" und Kontotyp "Krypto" auflöse
    Then ist die Farbe die Kontotyp-Farbe von "Krypto"

  Scenario: Unbekannte Bank wird abgelehnt
    When ich die Farbe für Bank "Interactive Brokers" und Kontotyp "Depot" auflöse
    Then wird ein Fehler ausgelöst

  # Der Kontotyp-Chip auf den Dashboard-Konto-Karten beschriftet sich mit der
  # Kontofarbe (= Bankfarbe), damit er zu Farbpunkt und Mini-Diagramm derselben
  # Karte passt. Markenfarben sind aber Logofarben und als 11px-Fettschrift auf
  # unseren Flächen oft unlesbar — deshalb die Korrektur.
  Scenario: Ausreichend lesbare Farbe bleibt unverändert
    When ich die Farbe "#00c878" für den Hintergrund "#101713" lesbar mache
    Then ist das Ergebnis unverändert "#00c878"

  Scenario: Zu dunkle Markenfarbe wird auf dunklem Grund aufgehellt
    When ich die Farbe "#000000" für den Hintergrund "#101713" lesbar mache
    Then erreicht das Ergebnis mindestens 4.5:1 gegen "#101713"
    And ist das Ergebnis heller als "#000000"

  Scenario: Zu helle Markenfarbe wird auf hellem Grund abgedunkelt
    When ich die Farbe "#ffe600" für den Hintergrund "#ffffff" lesbar mache
    Then erreicht das Ergebnis mindestens 4.5:1 gegen "#ffffff"
    And ist das Ergebnis dunkler als "#ffe600"

  Scenario: Jede Bank- und Kontotyp-Farbe wird in beiden Themes lesbar
    When ich jede Farbe aus kBanks und kTagColors gegen beide Flächen lesbar mache
    Then erreicht jedes Ergebnis mindestens 4.5:1

  Scenario: Kontrastverhältnis folgt WCAG
    Then beträgt der Kontrast zwischen "#000000" und "#ffffff" 21.0
