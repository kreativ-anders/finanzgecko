# Source: lib/ui/views/dashboard_view.dart, lib/state/app_state.dart, lib/utils/analysis.dart, lib/constants.dart
# Implementation: lib/ui/views/dashboard_view.dart
@dashboard
Feature: Dashboard — net-worth overview
  As a user, I see my Gesamtvermögen at a glance, along with its Verlauf and projection, the Verteilung by
  Kontotyp, and key Kennzahlen, filtered by a selectable Zeitraum.

  Background:
    Given the app is started and initialized

  Rule: Empty state — two-stage onboarding

    Scenario: No Konto created yet
      Given not a single Konto exists yet
      When I open the Dashboard
      Then I see a centered welcome card with a "Konto anlegen" button that leads to the "Konten" view
      And the "Fixposten" and "Vermögenswerte" sections still show, each in its own empty or actual state

    Scenario: A Konto exists, but not a single Kontostand yet
      Given at least one Konto exists, but not a single Kontostand has been recorded yet
      When I open the Dashboard
      Then I see a centered card with an "Einträge erfassen" button that leads to the "Einträge" view
      And the "Fixposten" and "Vermögenswerte" sections still show, each in its own empty or actual state

    Scenario: The first Kontostand exists
      Given at least one Kontostand has been recorded
      When I open the Dashboard
      Then I see the normal Dashboard view with Verlauf, Verteilung, and Kennzahlen instead of the
        onboarding card

  Rule: The Zeitraum filter drives the entire Dashboard

    Scenario: Available Zeitraum presets depend on the data history
      Given there are recorded Kontostände spanning several years
      Then the presets "Dieses Jahr", "12 Monate", "Letztes Jahr", and "Alle" are available, each only when
        it yields a non-empty subset distinguishable from the full range ("Alle")
      And "Alle" is always available
      And the presets sit as a global control in the top right of the header (level with the heading, above
        the Verlauf card) instead of on a row with a label

    Scenario: The default preset is "Dieses Jahr" when available
      Given "Dieses Jahr" yields a subset distinguishable from the full range
      When I open the Dashboard for the first time this session
      Then "Dieses Jahr" is preselected
      Given "Dieses Jahr" isn't available as its own preset (e.g. because it equals the full history)
      Then "Alle" is preselected instead

    Scenario: Changing the Zeitraum affects every time-based card at once
      When I choose a different preset in the Zeitraum filter
      Then the following update simultaneously: the Gesamtvermögen header, the Verlauf card with its
        projection, the Zusammensetzung card, the Verteilung card, and the Kennzahlen card

    Scenario: The projection is only visible when the Zeitraum reaches the most recent month
      Given I choose the "Letztes Jahr" preset
      Then no projection is drawn in the Verlauf card, since its anchor would no longer be current
      Given I choose a preset whose last month is the overall most recently recorded month
      Then a projection is drawn through year end (in December: a full year projected forward)

    Scenario: Zeitraum filter, sorting, and "inkl. Sachwerte" persist across view changes
      Given I choose a preset other than the default in the Zeitraum filter, change the Konto card sort
        order, and turn on "inkl. Sachwerte"
      When I switch to another view and come back to the Dashboard
      Then the Zeitraum preset, Konto card sort order, and "inkl. Sachwerte" are still as last chosen
      And these three settings live only in the running `AppState` (not in `AppSchema`/on disk) and reset
        to their defaults the next time the app starts

  Rule: Gesamtvermögen header

    Scenario: Vermögenswerte are not included in the total by default
      Given both Kontostände and Vermögenswerte exist
      When I open the Dashboard
      Then the "GESAMTVERMÖGEN" header shows only the sum of the Kontostände
      And an "inkl. Sachwerte" toggle is visible (only when Vermögenswerte exist)
      When I toggle "inkl. Sachwerte" on
      Then the sum of the Vermögenswerte is added and the label switches to
        "GESAMTVERMÖGEN INKL. SACHWERTE"

    Scenario: Change against the previous month
      Given there is a previous recorded month within the active Zeitraum
      Then the header shows the absolute and percentage change against that previous month, green at ≥0,
        red at <0
      Given there is no previous month in the active Zeitraum
      Then the header shows "Noch kein Vergleichsmonat" instead of a delta

    Scenario: Estimated split into contributions vs. market
      Given there are Fixposten and a previous month
      Then the change is split directly below the delta row into two compact chips: "… eingezahlt"
        (Fixposten net × month gap) and "… Markt" (the rest)
      And the chip amounts are rounded to whole currency units, since the split is an estimate and cent
        precision would be false precision
      Given there are no Fixposten
      Then these chips are omitted

    Scenario: The current month's recording status only shows when incomplete
      Given all Konten are recorded for the current month (X = Y)
      Then no recording-status hint appears (the count is visible in the Verlauf chart anyway)
      Given Konten are missing for the current month (X < Y)
      Then an amber warning "Nur X von Y Konten für diesen Monat erfasst — Summe evtl. unvollständig."
        appears

    Scenario: Hint about rounding differences for foreign-currency Konten
      Given at least one Konto in the current period has a currency other than the Basiswährung
      Then a short hint "Fremdwährungskonten: Rundungsdifferenzen von wenigen Cent möglich." appears
      And this hint text stays capped at a readable line width instead of running the full (very long on
        wide windows) Dashboard width

  Rule: Verlauf & projection

    Scenario: The projection blends trend and the Fixposten plan
      Given there are at least two months of Verlauf history
      Then the monthly projection rate is based on a linear trend estimate of the history, stabilized by
        the Fixposten net as a prior whose influence shrinks as the history grows
      And the label names the basis used ("Prognose aus X Monaten Verlauf, mit Fixposten geglättet" /
        "Prognose aus X Monaten Verlauf" / "Prognose aus den Fixposten (noch wenig Verlauf)")

    Scenario: The projection horizon reaches to year end
      Given the active Zeitraum reaches the most recent month
      Then the projection is drawn through the end of that last month's calendar year
      And in December, a full year (12 months) is projected instead of 0

  Rule: Zusammensetzung & Verteilung

    Scenario: Zusammensetzung über Zeit is grouped by Kontotyp
      Given there are at least two months with data
      Then a stacked-area card shows one series per Kontotyp across every month of the active Zeitraum
      And negative Kontotyp totals (e.g. an overdrawn Konto) enter the stack as 0 instead of negative
      And Kontotypen are shown in the order of the known list, unknown/custom types are appended

    Scenario: Zusammensetzung über Zeit shows a month tooltip on hover
      Given the mouse pointer is over a month on the Zusammensetzung card
      Then a vertical guide line appears at that month
      And a tooltip lists every Kontotyp in the stack with a color dot, name, amount, and share (as a
        percentage of the month's total) for exactly that month
      And the tooltip disappears as soon as the mouse pointer leaves the card

    Scenario: The Verteilung donut shows only the most recent month of the active Zeitraum
      Then the donut shows the totals per Kontotyp for exactly the last month of the active Zeitraum

    Scenario: The Verteilung donut shows the share and Kontotyp in the empty center on hover
      Given the mouse pointer is over a segment of the Verteilung donut
      Then that segment visibly grows slightly outward
      And the Kontotyp and its percentage share appear in the donut's empty inner circle
      And the display disappears as soon as the mouse pointer leaves the segment

    Scenario: Concentration-risk hint
      Given at least two Kontotypen with a positive total exist
      And the largest Kontotyp's share of the positive total is at least 65%
      Then a red hint appears naming the Kontotyp and its percentage share
      Given the largest share is below 65% or there's only one positive Kontotyp
      Then no concentration-risk hint appears

  Rule: Kennzahlen

    Scenario: The Kennzahlen card only appears from two months of history on
      Given fewer than two months with data lie within the active Zeitraum
      Then no Kennzahlen card is shown
      Given at least two months with data exist
      Then the card shows: total change since the starting month, best month, worst month, average
        change/month, months in the black (count and share), plus the high point and its month

    Scenario: Kennzahlen tiles flow row by row according to available width
      Given the Kennzahlen card is narrower than what all tiles need in one row
      Then each row fills with as many tiles at their natural width as fit, and rearranges live as the
        window width changes
      Given the line wrap would leave a single tile alone on the last row
      Then the previous row's last tile is instead pulled down into the last row, so no row stands alone

  Rule: Reminder banners (the order is deliberate)

    Scenario: Update reminder when the current month hasn't been recorded yet
      Given history already exists, but no Kontostand exists yet for the current calendar month
      Then the first banner shown is a hint with the last recorded month and a "Jetzt erfassen" action
        leading to the "Einträge" view
      Given the current month is already fully or partially recorded (or there's no history yet)
      Then this banner doesn't appear

    Scenario: Overspend banner on a negative Fixposten net
      Given Fixposten exist and their sum (income − expenses) is negative
      Then a prominent red banner appears with the monthly expense and income amounts and a
        "Fixposten prüfen" action
      Given the net is ≥0 or there are no Fixposten
      Then this banner doesn't appear

    Scenario: No backup reminder while the app is completely empty
      Given neither Konten, Kontostände, Vermögenswerte, nor Fixposten exist
      Then no backup reminder banner appears, regardless of whether an export ever happened (nothing
        recorded means nothing to back up)

    Scenario: Backup reminder when never exported
      Given at least one Konto, Kontostand, Vermögenswert, or Fixposten exists
      And no export has ever been performed
      And the earliest recorded activity is at least kBackupReminderFirstDays (182, ~6 months) ago
      Then a banner "Noch nie exportiert — leg jetzt ein erstes Backup an und bewahre es außerhalb dieses
        Computers auf. Nur das Backup lässt sich auf einem anderen Rechner öffnen." appears
      And the text deliberately names both — the storage location and portability: for most users this
        reminder is the only place they ever learn about export, and there's deliberately no automatic
        backup (see AI_MASTER §4.1)
      Given the earliest recorded activity is less than kBackupReminderFirstDays ago
      Then no backup reminder banner appears yet (only an unobtrusive note in Einstellungen)

    Scenario: Backup reminder after a previous export
      Given at least one export has already happened
      And the last export is at least kBackupReminderRepeatDays (90, ~3 months) ago
      Then a banner appears with the number of days since the last export
      Given the last export is less than kBackupReminderRepeatDays ago
      Then no backup reminder banner appears (only an unobtrusive note in Einstellungen)

    Scenario: Asset re-evaluation reminder
      Given at least one Vermögenswert hasn't been re-evaluated for at least 182 days (~6 months), or never
      Then a banner appears listing the affected Vermögenswerte by name, with a "Jetzt prüfen" action

  Rule: Konto cards

    Scenario: Every Konto card shows a mini Verlauf and a month-over-month comparison
      Given a Konto has at least one recorded Kontostand
      Then its card shows the most recent amount, a mini line chart over every recorded month for this
        Konto, and — if a previous month exists — the change against it (green/red)
      Given a Konto has no recorded Kontostand yet
      Then its card shows "—" instead of an amount and no Verlauf

    Scenario: Clicking a Konto card leads directly to recording
      Given the mouse pointer is over a Konto card
      Then the whole card is recognizable as a click target (hover effect) and a tooltip reads
        'Kontostand für "<Kontoname>" erfassen'
      And the mouse pointer turns into a hand — the card's content is excluded from the app-wide text
        selection for this, otherwise its text cursor would win against the click cursor
      When I click the card
      Then the app switches to the "Einträge" view
      And there, exactly this Konto's row is scrolled into view and its amount field has focus
      And not just the mini chart but the whole card responds — on narrow cards, the 70px-tall chart area
        alone would be too small and hard to find as a click target

    Scenario: Konto cards are sortable
      Given the user opens the sort picker above the Konto cards
      Then the options "Standard", "Name (A–Z)", "Betrag (hoch → niedrig)", "Betrag (niedrig → hoch)",
        "Veränderung (größter Zuwachs)", and "Veränderung (größter Rückgang)" are available
      And "Standard" (the Konten's creation order) is preselected
      And Konten without a Kontostand resp. without a previous month sort to the end under amount- resp.
        change-based sorting, instead of jumping to the front
      And the selection persists for the rest of the session (see "Zeitraum filter, sorting, and
        'inkl. Sachwerte' persist across view changes"), but isn't saved to disk and resets on the next
        app restart
