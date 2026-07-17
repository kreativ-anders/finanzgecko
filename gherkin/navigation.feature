# Quelle: lib/ui/navigation_shell.dart, lib/ui/app_view.dart
# Implementierung: lib/ui/navigation_shell.dart
@navigation
Feature: Navigation und In-App-Menü
  Als Nutzer:in erwarte ich eine konsistente Navigation zwischen den Ansichten, auch dort, wo das Betriebssystem
  keine native Menüleiste anbietet.

  Scenario: Sechs Hauptansichten über eine einfache Top-Navigation
    Then sind über die Kopfleiste genau diese Ansichten erreichbar, in dieser Reihenfolge: Dashboard, Einträge,
      Konten, Fixposten, Vermögenswerte, Einstellungen
    And die aktive Ansicht ist optisch hervorgehoben (Primärfarbe, fett)

  Scenario: Banner-Aktionen navigieren direkt zur passenden Ansicht
    Given ein Dashboard-Banner mit Aktions-Button ist sichtbar (z. B. Update-, Overspend-, Backup- oder Asset-Reminder)
    When ich auf den Aktions-Button klicke
    Then wechselt die Navigation direkt zur zuständigen Ansicht (Einträge / Fixposten / Einstellungen / Vermögenswerte)

  Scenario: Kein natives Menü unter Linux/Windows — In-App-Ersatz
    Given die App läuft unter Linux oder Windows (keine native PlatformMenuBar-Unterstützung)
    Then gibt es stattdessen einen "Datei"-Bereich direkt im eigenen Fensterkopf mit denselben Funktionen
      (Backup exportieren/importieren, Beenden)

  Scenario: Globale Tastenkürzel funktionieren unabhängig vom Menü
    Given die App hat den Fokus
    Then lösen Strg+E (⌘+E auf macOS) den Export, Strg+I (⌘+I) den Import und Strg+Q (⌘+Q) das Beenden aus
    And dies funktioniert unabhängig davon, ob das Datei-Menü gerade sichtbar/geöffnet ist

  Scenario: Nur Inhaltstext ist markierbar, keine Navigation/Buttons
    Given die gesamte App steht unter einer app-weiten Textauswahl (SelectionArea)
    Then sind Kopfleiste, Navigationsbuttons, Button-Labels und Footer explizit davon ausgenommen
    And normaler Inhaltstext (Werte, Hinweise, Labels in Karten) bleibt markier- und kopierbar
