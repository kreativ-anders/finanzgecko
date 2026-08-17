# Source: lib/main.dart, lib/ui/splash_screen.dart
# Implementation: lib/main.dart
@window
Feature: Window behavior and splash
  As a user of a native desktop program, I expect familiar window behavior (remembering size/maximized
  state) and a calm start.

  Scenario: Window size and maximized state are remembered
    Given I changed the window size or maximized/restored the window
    Then this is saved (debounced)
    When I restart the app
    Then the window opens at exactly this size, or maximized

  Scenario: Window position is deliberately not saved
    Given I moved the window to a second monitor
    When I restart the app, possibly without that monitor connected
    Then only size/maximized state is restored, the position follows the default centering
    And the window therefore never ends up outside the visible area

  Scenario: Minimum size and default size
    Given this is the very first use (no saved window values)
    Then the window opens at 1280×860, maximized
    And the window can never become smaller than 960×640

  Scenario: Splash screen on startup
    Given the app is starting
    Then a brand splash (logo + "🦎 FinanzGecko") is shown for at least 1100ms — the store and window are
      already fully initialized by this point, so the splash doesn't gate any real loading
    And after that the app crossfades to the Dashboard view over 400ms

  Scenario: The splash logo follows the active theme
    Given the app starts in the dark theme
    Then the splash shows the light logo (white text), which reaches 13.7:1 there
    Given the app starts in the light theme
    Then the splash shows the dark logo (black text) at 6.4:1
    And both files share the same crop (512×333), so the splash looks the same in both themes
    And even the empty window before the splash has the correct background color — main.dart resolves the
      brightness via primeThemeBrightness before the WindowOptions are built

  Scenario: Splash duration is a deliberate branding decision
    Given main.dart already calls windowManager.show() before runApp
    Then an empty window in kBackground is visible before the splash for the duration of initialization
    And the 1100ms + 400ms add to that time, so the start feels branded for ~1.5s overall
    And exactly these values were evaluated and deliberately kept — they are not to be "optimized" without
      discussing it first
