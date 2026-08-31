# Source: lib/ui/views/entries_view.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/models/balance.dart
# Implementation: lib/ui/views/entries_view.dart
@balances @entries
Feature: Record monthly Kontostände
  As a user, I record the Kontostände of all my Konten in one place every month, so the Dashboard can
  compute a complete Verlauf of my net worth.

  Background:
    Given the app is started and initialized
    And at least one active Konto exists

  Scenario: Without any Konten, the user is directed to create one first
    Given no Konto exists yet
    When I open the "Einträge" view
    Then I see the hint "Erst ein Konto anlegen"
    And a button that takes me to the "Konten" view

  Scenario: The current month is selected by default
    Given I open the "Einträge" view
    Then the Zeitraum defaults to the current calendar month

  Scenario: Retroactive recording via changing the month
    Given I am on the "Einträge" view
    When I pick a different (including past) month via the month picker
    Then the list shows the values already saved for this month, per Konto
    And empty Konten show the value of the last known month only as a placeholder (hint), not pre-filled

  Scenario: Overwrite an existing entry (upsert per Konto+month)
    Given a Kontostand already exists for the Konto "Girokonto" in the chosen month
    When I enter a new amount for this Konto and save
    Then the existing entry for that Konto+month is overwritten (no duplicate)
    And the new exchange rate at the time of saving is frozen

  Scenario: Empty fields are skipped on save
    Given several Konten are visible in the list
    When I fill in only some of the amounts and click "Alle speichern"
    Then only the filled-in Konten are saved
    And the Konten left empty stay unchanged
    And the feedback states the number of Konten saved

  Scenario: Enter jumps to the next Konto, the last Enter saves
    Given I have focus in the amount field of a Konto that isn't the last one in the list
    When I press Enter
    Then focus jumps to the amount field of the next Konto
    Given I have focus in the amount field of the last Konto in the list
    When I press Enter
    Then this triggers the same effect as "Alle speichern"

  Scenario: Jumped from the Dashboard to a specific Konto
    Given I clicked a Konto card on the Dashboard
    When the "Einträge" view opens
    Then the amount field of exactly that Konto has focus instead of the first Konto in the list
    And the row is scrolled into view if it sits below the fold
    And the month is the usual default (current month), the list stays complete — nothing is filtered
    Given the clicked Konto isn't in the list at all (e.g. archived)
    Then the view behaves like a normal open: focus sits on the first Konto
    Given I leave "Einträge" and return later via the nav bar
    Then the earlier card click has no lasting effect — focus is on the first Konto again

  Scenario: Calculate a combined value directly in the amount field
    Given I am entering a Kontostand
    When I type a simple arithmetic expression using +, -, * or / instead of a plain number
      (e.g. "1300,12 +5201.75" to combine a broker's depot and cash balance into one Konto)
    Then the expression is evaluated (× and ÷ bind tighter than + and −, left to right, no parentheses)
    And the resulting sum is what gets saved as the Kontostand on "Alle speichern"
    And the live running total and the anomaly hint already use the computed value while typing

  Scenario: Invalid input in the amount field is rejected, not silently skipped
    Given I am entering a Kontostand
    When I type text that isn't a valid number or arithmetic expression (e.g. contains letters, or a
      dangling operator) and press Enter
    Then focus does not move to the next Konto and nothing is saved for this Konto
    And a toast "Ungültige Eingabe — nur Zahlen und Rechenzeichen (+ - * /) sind erlaubt." appears

  Scenario: Show only missing Konten
    Given a value has already been recorded for some of the Konten in the chosen month
    When I turn on the "Nur fehlende anzeigen" toggle
    Then the list shows only Konten without an entry for this month

  Scenario: Live running total while typing
    Given I type amounts into several amount fields, without saving
    Then a running total in Basiswährung keeps updating at the bottom of the screen
    And a difference against the sum of the last saved values is shown
    And this preview uses no network call, but a rate estimate (see currency_exchange.feature)

  Scenario: The live running total warns about a missing rate estimate
    Given a Konto in a foreign currency has neither a previous Kontostand nor any other saved rate for the
      same currency
    When I type an amount for this Konto
    Then it is not included in the live running total
    And a hint states the number of Konten "in Fremdwährung ohne Kursschätzung"

  Scenario: Anomaly hint on an unusual jump
    Given the last saved Kontostand of a Konto is 1000 in the Konto's currency
    When I type a new amount that's at least 10× bigger or smaller than 1000 (and not 0)
    Then a non-blocking hint "Ungewöhnlich: … Tippfehler?" appears next to the field
    And I can still save the value unchanged (no forced stop)

  Scenario: No anomaly hint without a comparison value
    Given no previous Kontostand exists yet for this Konto
    When I type any amount
    Then no anomaly hint appears

  Scenario: Delete an existing entry
    Given a Kontostand for a Konto+month exists
    When I click the delete icon in this row and confirm the safety prompt
    Then the entry is removed
    And this row's input field is cleared
    And I see the confirmation "Gelöscht."

  Scenario: Orphaned entries of archived Konten stay visible
    Given a Konto with recorded Kontostände gets archived
    When I open the "Einträge" view for a month that has such an entry
    Then a separate "Archivierte Konten" section appears with this entry
    And from there, the corresponding Konto can be restored or the entry deleted

  Scenario: An orphaned entry of a fully deleted Konto
    Given a Kontostand references a Konto ID that no longer exists (e.g. after a manual import)
    Then the row shows "Konto gelöscht" instead of a Konto name
    And only the "Löschen" option is available, no "Wiederherstellen" option

  Scenario: The date used for the exchange-rate lookup depends on the month
    Given the chosen month is the current calendar month
    When I save
    Then for foreign-currency Konten, the rate is looked up for today's date (not month-end, which may lie
      in the future and not have a published rate yet)
    Given the chosen month lies entirely in the past
    When I save
    Then the rate is looked up for the last calendar day of that month
