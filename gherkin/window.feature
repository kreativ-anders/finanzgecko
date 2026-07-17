# Quelle: lib/main.dart, lib/ui/splash_screen.dart
# Implementierung: lib/main.dart
@window
Feature: Fensterverhalten und Splash
  Als Nutzer:in eines nativen Desktop-Programms erwarte ich vertrautes Fensterverhalten (Größe/Maximiert-Status
  merken) und einen ruhigen Start.

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

  Scenario: Splash-Screen beim Start
    Given die App wird gestartet
    Then wird für mindestens 1100ms ein Marken-Splash (Logo + "🦎 FinanzGecko") gezeigt — Store und Fenster sind zu
      diesem Zeitpunkt bereits vollständig initialisiert, der Splash gated also keinen echten Ladevorgang
    And danach blendet die App über 400ms zur Dashboard-Ansicht über
