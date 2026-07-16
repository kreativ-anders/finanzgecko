# Quelle: lib/utils/analysis.dart
# Ausführbar: test/bdd/analysis_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @dashboard
Feature: Vermögensprognose und Kennzahlen (reine Logik)

  Scenario: Trendsteigung einer linearen Reihe
    Given die Monatswerte 100, 200, 300, 400
    Then ist die Trendsteigung 100

  Scenario: Prognoserate mischt Trend und Fixposten-Prior je zur Hälfte
    When ich die Prognoserate mit Trend 300, Plan 100, 3 Punkten und Prior 3 berechne
    Then ist die Prognoserate 200

  Scenario: Prognosehorizont reicht bis Jahresende
    Then sind es von "2026-06" 6 Monate bis Jahresende
    And sind es von "2026-12" 12 Monate bis Jahresende

  Scenario: Anomalie erkennt einen Zehnersprung
    Then ist 22000 gegenüber 2200 eine Anomalie
    And ist 2400 gegenüber 2200 keine Anomalie
