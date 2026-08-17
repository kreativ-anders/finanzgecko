# Source: lib/ui/navigation_shell.dart, lib/ui/app_view.dart
# Implementation: lib/ui/navigation_shell.dart
@navigation
Feature: Navigation and in-app menu
  As a user, I expect consistent navigation between views, even where the operating system offers no native
  menu bar.

  Scenario: Six main views via a simple top navigation
    Then exactly these views are reachable via the header, in this order: Dashboard, Einträge, Konten,
      Fixposten, Vermögenswerte, Einstellungen
    And the active view is visually highlighted (primary color, bold)

  Scenario: Banner actions navigate directly to the matching view
    Given a Dashboard banner with an action button is visible (e.g. the update, overspend, backup, or asset
      reminder)
    When I click the action button
    Then navigation switches directly to the responsible view (Einträge / Fixposten / Einstellungen /
      Vermögenswerte)

  Scenario: No native menu on Linux/Windows — in-app replacement
    Given the app runs on Linux or Windows (no native PlatformMenuBar support)
    Then there is instead a "Datei" area directly in the app's own window header with the same functions
      (Backup exportieren/importieren, Beenden)

  Scenario: Global keyboard shortcuts work independently of the menu
    Given the app has focus
    Then Strg+E (⌘+E on macOS) triggers export, Strg+I (⌘+I) import, and Strg+Q (⌘+Q) quitting
    And this works regardless of whether the Datei menu is currently visible/open

  Scenario: Only content text is selectable, no navigation/buttons
    Given the entire app sits under an app-wide text selection (SelectionArea)
    Then the header, nav buttons, button labels, and footer are explicitly excluded from it
    And ordinary content text (values, hints, labels in cards) stays selectable and copyable
