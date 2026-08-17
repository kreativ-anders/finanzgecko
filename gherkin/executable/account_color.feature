# Source: lib/constants.dart
# Implementation: lib/constants.dart
# Executable: test/bdd/account_color_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @accounts
Feature: Konto accent color is derived from the bank

  Scenario: A known bank returns its brand color
    When I resolve the color for bank "DKB" and Kontotyp "Girokonto"
    Then the color is the brand color of bank "DKB"

  Scenario: A known bank is case-insensitive
    When I resolve the color for bank "trade republic" and Kontotyp "Depot"
    Then the color is the brand color of bank "Trade Republic"

  Scenario: An empty bank falls back to the Kontotyp color
    When I resolve the color for bank "" and Kontotyp "Krypto"
    Then the color is the Kontotyp color of "Krypto"

  Scenario: An unknown bank is rejected
    When I resolve the color for bank "Interactive Brokers" and Kontotyp "Depot"
    Then an error is thrown

  # The Kontotyp chip on the Dashboard Konto cards labels itself with the
  # Konto color (= bank color), so it matches the color dot and mini-chart of
  # the same card. But brand colors are logo colors and are often unreadable
  # as 11px bold text on our surfaces — hence the correction.
  Scenario: A sufficiently readable color stays unchanged
    When I make the color "#00c878" readable against the background "#101713"
    Then the result is unchanged "#00c878"

  Scenario: A brand color that's too dark gets lightened on a dark background
    When I make the color "#000000" readable against the background "#101713"
    Then the result reaches at least 4.5:1 against "#101713"
    And the result is lighter than "#000000"

  Scenario: A brand color that's too light gets darkened on a light background
    When I make the color "#ffe600" readable against the background "#ffffff"
    Then the result reaches at least 4.5:1 against "#ffffff"
    And the result is darker than "#ffe600"

  Scenario: Every bank and Kontotyp color is readable in both themes
    When I make every color from kBanks and kTagColors readable against both surfaces
    Then every result reaches at least 4.5:1

  Scenario: Contrast ratio follows WCAG
    Then the contrast between "#000000" and "#ffffff" is 21.0
