# Source: lib/ui/views/assets_view.dart, lib/state/app_state.dart, lib/models/asset.dart, lib/constants.dart
# Implementation: lib/ui/views/assets_view.dart
@assets
Feature: Manage Vermögenswerte (Sachwerte)
  As a user, I record Sachwerte like electronics, furniture, or vehicles with their current value, separate
  from the monthly Kontostände, since they have no real time series.

  Background:
    Given the app is started and initialized

  Scenario: Create a new Vermögenswert
    Given I am on the "Vermögenswerte" view
    When I fill in the label and value and click "Anlegen"
    Then a new Vermögenswert is created with today's date as "zuletzt bewertet"
    And I see the confirmation "Angelegt."
    And the form is cleared

  Scenario: Enter submits the "Neuer Vermögenswert" form
    Given I am in the "Neuer Vermögenswert" form with label and value filled in
    When I press Enter in the label or value field
    Then this has the same effect as clicking "Anlegen"

  Scenario: Required fields when creating
    Given I am in the "Neuer Vermögenswert" form
    When I leave the label empty or enter a value that can't be parsed as a number
    Then the Vermögenswert is not created
    And a validation error is shown on the respective field

  Scenario: Edit the value inline with autosave
    Given a Vermögenswert already exists
    When I change its value directly in the list
    Then it is saved automatically 600ms after typing stops (no explicit Speichern button)
    And "zuletzt bewertet" is updated to today
    And I see an unobtrusive save confirmation

  Scenario: Autosave also triggers immediately on focus loss or Enter
    Given I changed a Vermögenswert's value without waiting 600ms
    When I leave the field (click elsewhere) or press Enter
    Then it is saved immediately, without waiting for the debounce

  Scenario: An invalid value during inline edit is discarded
    Given I am editing the value of an existing Vermögenswert
    When I enter unparseable text and leave the field
    Then nothing is saved
    And the field snaps back to the last valid saved value

  Scenario: A value change automatically counts as a re-evaluation
    Given a Vermögenswert is overdue for re-evaluation
    When I change its value (even entering the same unchanged amount again via the value field)
    Then it counts as currently evaluated again from now on, without a separate "Neu bewerten" button

  Scenario: Overdue flag after ~6 months
    Given a Vermögenswert was last evaluated at least 182 days ago, or never
    Then its row shows a "Neu bewerten" badge
    Given the last evaluation was less than 182 days ago
    Then no badge appears

  Scenario: Delete a Vermögenswert
    Given a Vermögenswert exists
    When I click "Löschen" and confirm the safety prompt
    Then the Vermögenswert is removed
    And I see the confirmation "Gelöscht."

  Scenario: Empty state
    Given no Vermögenswert exists
    Then the list shows the hint "Noch keine Vermögenswerte angelegt."

  Scenario: List sorting
    Given several Vermögenswerte exist
    Then the list is sorted by value, highest first
    And Vermögenswerte of equal value are ordered alphabetically by label as a tiebreak
