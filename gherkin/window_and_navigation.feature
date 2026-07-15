# Quelle: lib/main.dart, lib/ui/app_shell.dart, lib/ui/app_view.dart, lib/ui/splash_screen.dart
@window @navigation
Feature: Fensterverhalten, Navigation und In-App-Menü
  Als Nutzer:in eines nativen Desktop-Programms erwarte ich vertrautes Fensterverhalten (Größe/Position merken) und
  eine konsistente Navigation, auch dort, wo das Betriebssystem keine native Menüleiste anbietet.

  Scenario: Fenstergröße und Maximiert-Status werden gemerkt
    Given ich habe die Fenstergröße geändert oder das Fenster maximiert/wiederhergestellt
    Then wird dies (debounced) gespeichert
    When ich die App neu starte
    Then öffnet sich das Fenster in genau dieser Größe bzw. maximiert

  Scenario: Fensterposition wird bewusst nicht gespeichert
    Given ich habe das Fenster auf einen zweiten Monitor verschoben
    When ich die App neu starte, ggf. ohne diesen Monitor angeschlossen
    Then wird nur Größe/Maximiert-Status wiederhergestellt, die Position folgt der Standard-Zentrierung
    And das Fenster landet dadurch nie außerhalb des sichtbaren Bereichs

  Scenario: Mindestgröße und Standardgröße
    Given es ist die allererste Nutzung (keine gespeicherten Fensterwerte)
    Then öffnet sich das Fenster mit 1280×860, maximiert
    And das Fenster kann zu keinem Zeitpunkt kleiner als 960×640 werden

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

  Scenario: Splash-Screen beim Start
    Given die App wird gestartet
    Then wird für mindestens 1100ms ein Marken-Splash (Logo + "🦎 FinanzGecko") gezeigt — Store und Fenster sind zu
      diesem Zeitpunkt bereits vollständig initialisiert, der Splash gated also keinen echten Ladevorgang
    And danach blendet die App über 400ms zur Dashboard-Ansicht über
