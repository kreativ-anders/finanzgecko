# Source: lib/utils/analysis.dart
# Implementation: lib/utils/analysis.dart
# Executable: test/bdd/analysis_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @dashboard
Feature: Net-worth projection and Kennzahlen (pure logic)

  Scenario: Trend slope of a linear series
    Given the monthly values 100, 200, 300, 400
    Then the trend slope is 100

  Scenario: Projection rate blends trend and Fixposten prior evenly
    When I compute the projection rate with trend 300, plan 100, 3 points, and prior 3
    Then the projection rate is 200

  Scenario: Projection horizon reaches to year end
    Then it is 6 months from "2026-06" to year end
    And it is 12 months from "2026-12" to year end

  Scenario: Anomaly detects a tenfold jump
    Then 22000 against 2200 is an anomaly
    And 2400 against 2200 is not an anomaly
