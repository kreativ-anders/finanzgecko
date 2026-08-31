# Source: lib/ui/views/subscriptions_view.dart, lib/state/app_state.dart, lib/models/subscription.dart, lib/constants.dart
# Implementation: lib/ui/views/subscriptions_view.dart
@subscriptions
Feature: Manage Fixposten (recurring income/expenses)
  As a user, I record recurring income and expenses (salary, rent, subscriptions, dividends), so the app can
  compute my monthly net cash flow and a net-worth projection.

  Background:
    Given the app is started and initialized

  Scenario: Create a new Fixposten as an expense (default)
    Given I am in the "Neuer Fixposten" form
    Then the sign toggle defaults to expense (−)
    When I fill in name, Intervall, currency, and amount and click "Anlegen"
    Then a Fixposten is saved with a negative amount
    And the exchange rate to Basiswährung valid at creation time is frozen

  Scenario: Create a new Fixposten as income
    Given I am in the "Neuer Fixposten" form
    When I set the sign toggle to income (+)
    And I fill in the form and save
    Then a Fixposten is saved with a positive amount

  Scenario: Enter submits the "Neuer Fixposten" form
    Given I am in the "Neuer Fixposten" form with name, currency, and amount filled in
    When I press Enter in the name, currency, or amount field
    Then this has the same effect as clicking "Anlegen"

  Scenario: Required fields and amount validation
    Given I am in the "Neuer Fixposten" form
    When the name is empty or the amount can't be parsed as a positive number
    And I click "Anlegen"
    Then an error "Bitte Name und einen gültigen Betrag eingeben." is shown
    And nothing is saved

  Scenario: No exchange rate available when creating
    Given neither the exchange-rate API nor the cache provides a rate for the chosen foreign currency
    When I fill in the form and save
    Then I am asked for a manual rate (see currency_exchange.feature)
    Given I cancel the manual rate dialog
    Then the Fixposten is not saved
    And I see the message "Kein Wechselkurs verfügbar — Fixposten wurde nicht gespeichert."

  Scenario: Interval conversion to a monthly equivalent
    Given a Fixposten has an Intervall other than "monatlich"
    Then totals and projections always use the monthly-equivalent amount internally
      (täglich ×30.4368; wöchentlich ×4.34524; monatlich ×1; vierteljährlich ÷3; jährlich ÷12)

  Scenario: Edit an existing Fixposten inline with autosave
    Given a Fixposten exists
    When I change name, Intervall, currency, sign, or amount directly in the list
    Then it is saved automatically 600ms after typing stops (or immediately on an Intervall/sign change,
      focus loss, or Enter)
    And the monthly preview ("≈ … /Monat") updates even before the actual save

  Scenario: Invalid input during inline edit is rejected
    Given I am editing an existing Fixposten
    When the name is empty or the amount can't be parsed as a non-negative number
    Then an error message is shown
    And the visible fields snap back to the last saved values on the next render

  Scenario: No exchange rate available when editing
    Given I change an existing Fixposten's currency to one with no rate available
    And I cancel the manual rate dialog
    Then the change is not saved
    And I see the message "Kein Wechselkurs verfügbar — Änderung wurde nicht gespeichert."

  Scenario: Delete a Fixposten
    Given a Fixposten exists
    When I click "Löschen" and confirm the safety prompt
    Then the Fixposten is removed

  Scenario: The list groups income before expenses
    Given both income and expense Fixposten exist
    Then all income items are shown first, then all expense items
    And within each group, items are ordered by monthly-equivalent amount, highest first
    And Fixposten of equal monthly amount are ordered alphabetically as a tiebreak

  Scenario: Totals overview
    Given several Fixposten exist
    Then the app computes: sum of monthly income, sum of monthly expenses (as a positive amount), and the
      difference (net) — each also shown as a yearly amount (×12)

  Scenario: Empty state
    Given no Fixposten exists
    Then the list shows the hint "Noch keine Fixposten erfasst."
