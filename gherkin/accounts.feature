# Source: lib/ui/views/accounts_view.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/models/account.dart
# Implementation: lib/ui/views/accounts_view.dart
@accounts
Feature: Manage Konten
  As a user, I manage my Konten (Girokonto, Tagesgeld, Depot, Bargeld, Krypto, …), so that I can record
  Kontostände on them every month.

  Note on the known bank list: `kBanks` (`lib/constants.dart`) is a hand-maintained, deliberately
  non-exhaustive list — currently including German branch, cooperative, development, and auto banks, common
  neobanks/fintechs and brokers, plus PayPal/Wise as international payment services. It grows with every
  confirmed user request (see the "Bank fehlt?" hint below); `kBanks` itself is the single source of truth
  for the current state, not this document.

  Background:
    Given the app is started and initialized

  Scenario: Create a new Konto with required fields
    Given I am on the "Konten" view
    When I enter the following values in the "Neues Konto" form:
      | Field    | Value         |
      | Bank     | DKB           |
      | Name     | Gehaltskonto  |
      | Typ      | Girokonto     |
      | Währung  | EUR           |
    And I click "Konto anlegen"
    Then a new Konto is saved with these values
    And the Konto's accent color is the brand color of "DKB"
    And the Konto is not archived
    And I see the confirmation "Angelegt."
    And the form is empty again (Bank/Name cleared, Typ/Währung reset to their defaults)

  Scenario: Enter submits the "Neues Konto" form
    Given I am on the "Konten" view in the "Neues Konto" form with all required fields filled in
    When I press Enter in the Bank field or the Name field
    Then this has the same effect as clicking "Konto anlegen"

  Scenario: Enter submits the Konto edit form
    Given a Konto is currently being edited
    When I press Enter in the Bank field or the Name field
    Then this has the same effect as clicking "Speichern"

  Scenario: The bank field only allows known banks
    Given I am on the "Konten" view in the "Neues Konto" form
    When I enter text in the bank field that matches no bank from the known list
    Then the form shows the validation error "Bitte eine Bank aus der Liste auswählen"
    And the Konto is not created

  Scenario: The bank field suggests matching banks with a color preview
    Given I am on the "Konten" view in the "Neues Konto" form
    When I enter a partial match of a known bank in the bank field
    Then matching suggestions appear, each with the bank's brand color as a color dot
    And a "Bank fehlt?" hint with links to "Auf GitHub vorschlagen" and "E-Mail schreiben" is visible

  Scenario: No color fallback without a known bank — Kontotyp color as the default
    Given I am on the "Konten" view in the "Neues Konto" form
    And the bank field is empty
    Then the color preview shows the default color of the currently selected Kontotyp

  Scenario: The foreign-currency hint only appears for a differing currency
    Given the app's Basiswährung is "EUR"
    And I am in the "Neues Konto" form
    When I choose "USD" as the Konto's currency
    Then I see the hint that exchange rates are fetched automatically via the frankfurter.dev API and cached
      for offline use
    When I choose "EUR" as the Konto's currency
    Then this hint disappears

  Scenario: Edit an existing Konto
    Given a Konto "Tagesgeld Sparkasse" exists
    When I click "Bearbeiten" on this Konto
    And I change the name, bank, Typ, or currency
    And I click "Speichern"
    Then the changes are applied
    And I see a save confirmation
    And the edit form closes again

  Scenario: Editing without a valid name is rejected
    Given a Konto is currently being edited
    When I clear the name field and click "Speichern"
    Then an error message "Bitte einen Namen eingeben." is shown
    And the Konto is not saved

  Scenario: Editing with an unknown bank is rejected
    Given a Konto is currently being edited
    When I enter text in the bank field that matches no known bank
    And I click "Speichern"
    Then an error message "Bitte eine Bank aus der Liste auswählen." is shown
    And the Konto is not saved

  Scenario: Archive a Konto (soft delete)
    Given a Konto "Altes Depot" exists
    When I archive it and confirm the safety prompt
    Then the Konto disappears from the active Konten list
    And it disappears from every Dashboard chart and the Einträge view
    And Kontostände already recorded for this Konto stay preserved in the database (no data loss)

  Scenario: Archiving requires confirmation
    Given a Konto exists
    When I click "Archivieren"
    Then a safety prompt appears noting that the Konto will then disappear completely from every chart
    And on "Abbrechen" the Konto stays active

  Scenario: Restore Kontostände of an archived Konto
    Given a Konto was archived and has Kontostände from earlier months
    When I click "Wiederherstellen" on one of its entries in the "Einträge" view, section
      "Archivierte Konten"
    Then the corresponding Konto is reactivated (no longer archived)
    And it reappears in the active Konten list and every chart
