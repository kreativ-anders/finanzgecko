# Source: lib/data/import_validation.dart, lib/constants.dart, lib/data/app_store.dart
# Implementation: lib/data/import_validation.dart
# Executable: test/bdd/import_validation_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @backup
Feature: Imported entries the app couldn't handle are skipped

  # A backup can come from a hand-written or AI-converted file (templates/import-template.json), so every
  # value is untrusted. An entry that would crash a view or corrupt a total after the import is skipped,
  # exactly like a malformed entry (see gherkin/backup_restore.feature). Every file this app has ever
  # exported passes unchanged: the month format, currencies and intervals have never changed.
  #
  # Free-text descriptions are deliberately comments here: the runner
  # (test/support/gherkin_runner.dart) only accepts comments, tags, and steps
  # under "Feature:" and throws on anything else.

  Scenario: A valid Kontostand is kept
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "2500"
    When the imported entries are checked
    Then 1 Kontostände remain

  Scenario: A month outside 01 to 12 is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025-13" with amount "2500"
    When the imported entries are checked
    Then 0 Kontostände remain

  Scenario: A period without a month is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025" with amount "2500"
    When the imported entries are checked
    Then 0 Kontostände remain

  Scenario: A period with a two-digit year is skipped
    Given an imported Kontostand 1 for Konto 1 in period "25-01" with amount "2500"
    When the imported entries are checked
    Then 0 Kontostände remain

  Scenario: A Kontostand in an unknown currency is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "2500" in currency "XYZ"
    When the imported entries are checked
    Then 0 Kontostände remain

  # JSON has no Infinity, but "1e999" parses to it — and one infinite amount turns every total into Infinity.
  Scenario: An infinite amount is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "Infinity"
    When the imported entries are checked
    Then 0 Kontostände remain

  Scenario: An implausibly large amount is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "1e16"
    When the imported entries are checked
    Then 0 Kontostände remain

  Scenario: A negative amount at the limit is kept
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "-1e15"
    When the imported entries are checked
    Then 1 Kontostände remain

  Scenario: Of two Kontostände with the same id, the first one wins
    Given an imported Kontostand 7 for Konto 1 in period "2025-01" with amount "100"
    And an imported Kontostand 7 for Konto 1 in period "2025-02" with amount "200"
    When the imported entries are checked
    Then 1 Kontostände remain
    And the remaining Kontostand has amount "100"

  Scenario: A second Kontostand for the same Konto and Monat is skipped
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "100"
    And an imported Kontostand 2 for Konto 1 in period "2025-01" with amount "200"
    When the imported entries are checked
    Then 1 Kontostände remain
    And the remaining Kontostand has amount "100"

  Scenario: The same Monat on two different Konten is kept
    Given an imported Kontostand 1 for Konto 1 in period "2025-01" with amount "100"
    And an imported Kontostand 2 for Konto 2 in period "2025-01" with amount "200"
    When the imported entries are checked
    Then 2 Kontostände remain

  Scenario: A Konto in an unknown currency is skipped
    Given an imported Konto 1 of Kontotyp "Girokonto" in currency "XYZ"
    When the imported entries are checked
    Then 0 Konten remain

  # Older versions offered these two Kontotypen; their backups must keep importing.
  Scenario: A Konto with a Kontotyp from an older version is kept
    Given an imported Konto 1 of Kontotyp "Festgeld" in currency "EUR"
    And an imported Konto 2 of Kontotyp "Kredit" in currency "EUR"
    When the imported entries are checked
    Then 2 Konten remain

  Scenario: Of two Konten with the same id, only the first is kept
    Given an imported Konto 1 of Kontotyp "Girokonto" in currency "EUR"
    And an imported Konto 1 of Kontotyp "Depot" in currency "USD"
    When the imported entries are checked
    Then 1 Konten remain

  Scenario: A Fixposten with a known interval is kept
    Given an imported Fixposten 1 with interval "monthly" and amount "-9.99"
    When the imported entries are checked
    Then 1 Fixposten remain

  Scenario: A Fixposten with an unknown interval is skipped
    Given an imported Fixposten 1 with interval "Monthly" and amount "-9.99"
    When the imported entries are checked
    Then 0 Fixposten remain

  Scenario: A Fixposten with an infinite amount is skipped
    Given an imported Fixposten 1 with interval "yearly" and amount "-Infinity"
    When the imported entries are checked
    Then 0 Fixposten remain

  Scenario: A Vermögenswert with an infinite value is skipped
    Given an imported Vermögenswert 1 with value "Infinity"
    When the imported entries are checked
    Then 0 Vermögenswerte remain

  Scenario: A Vermögenswert with a normal value is kept
    Given an imported Vermögenswert 1 with value "1200"
    When the imported entries are checked
    Then 1 Vermögenswerte remain

  Scenario: A known Basiswährung is adopted
    When the imported Basiswährung "CHF" is checked
    Then the Basiswährung to adopt is "CHF"

  Scenario: An unknown Basiswährung is ignored
    When the imported Basiswährung "XYZ" is checked
    Then no Basiswährung is adopted
