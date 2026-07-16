# Quelle: lib/constants.dart
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
