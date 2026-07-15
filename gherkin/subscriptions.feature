# Quelle: lib/ui/views/subscriptions_view.dart, lib/state/app_state.dart, lib/models/subscription.dart, lib/constants.dart
@subscriptions
Feature: Fixposten (wiederkehrende Ein-/Ausgaben) verwalten
  Als Nutzer:in erfasse ich wiederkehrende Ein- und Ausgaben (Gehalt, Miete, Abos, Dividenden), damit die App meinen
  monatlichen Netto-Cashflow und eine Vermögensprognose berechnen kann.

  Background:
    Given die App ist gestartet und initialisiert

  Scenario: Neuen Fixposten anlegen als Ausgabe (Standard)
    Given ich bin im Formular "Neuer Fixposten"
    Then ist der Vorzeichen-Umschalter standardmäßig auf Ausgabe (−) gestellt
    When ich Name, Intervall, Währung und Betrag ausfülle und auf "Anlegen" klicke
    Then wird ein Fixposten mit negativem Betrag gespeichert
    And der zum Anlegezeitpunkt gültige Wechselkurs zur Basiswährung wird eingefroren

  Scenario: Neuen Fixposten als Einnahme anlegen
    Given ich bin im Formular "Neuer Fixposten"
    When ich den Vorzeichen-Umschalter auf Einnahme (+) stelle
    And ich das Formular ausfülle und speichere
    Then wird ein Fixposten mit positivem Betrag gespeichert

  Scenario: Pflichtfelder und Betragsvalidierung
    Given ich bin im Formular "Neuer Fixposten"
    When Name leer ist oder der Betrag nicht als positive Zahl interpretierbar ist
    And ich auf "Anlegen" klicke
    Then wird ein Fehler "Bitte Name und einen gültigen Betrag eingeben." angezeigt
    And nichts wird gespeichert

  Scenario: Kein Wechselkurs verfügbar beim Anlegen
    Given weder die Wechselkurs-API noch der Cache liefern einen Kurs für die gewählte Fremdwährung
    When ich das Formular ausfülle und speichere
    Then werde ich nach einem manuellen Kurs gefragt (siehe currency_exchange.feature)
    Given ich breche den manuellen Kurs-Dialog ab
    Then wird der Fixposten nicht gespeichert
    And ich sehe die Meldung "Kein Wechselkurs verfügbar — Fixposten wurde nicht gespeichert."

  Scenario: Intervall-Umrechnung auf ein Monatsäquivalent
    Given ein Fixposten hat ein Intervall ungleich "monatlich"
    Then wird für Summen und Prognosen intern immer der Monatsäquivalent-Betrag verwendet
      (täglich ×30,4368; wöchentlich ×4,34524; monatlich ×1; vierteljährlich ÷3; jährlich ÷12)

  Scenario: Bestehenden Fixposten inline bearbeiten mit Autosave
    Given ein Fixposten existiert
    When ich Name, Intervall, Währung, Vorzeichen oder Betrag in der Liste direkt ändere
    Then wird nach 600ms Tippstopp (bzw. sofort bei Intervall-/Vorzeichenwechsel, Fokusverlust oder Enter)
      automatisch gespeichert
    And die monatliche Vorschau ("≈ … /Monat") aktualisiert sich schon vor dem eigentlichen Speichern

  Scenario: Ungültige Eingabe beim Inline-Edit wird abgelehnt
    Given ich bearbeite einen bestehenden Fixposten
    When Name leer ist oder der Betrag nicht als nicht-negative Zahl interpretierbar ist
    Then wird eine Fehlermeldung angezeigt
    And die sichtbaren Felder springen beim nächsten Rendern auf die zuletzt gespeicherten Werte zurück

  Scenario: Kein Wechselkurs verfügbar beim Bearbeiten
    Given ich ändere die Währung eines bestehenden Fixpostens auf eine Währung ohne verfügbaren Kurs
    And ich breche den manuellen Kurs-Dialog ab
    Then wird die Änderung nicht gespeichert
    And ich sehe die Meldung "Kein Wechselkurs verfügbar — Änderung wurde nicht gespeichert."

  Scenario: Fixposten löschen
    Given ein Fixposten existiert
    When ich auf "Löschen" klicke und die Sicherheitsabfrage bestätige
    Then wird der Fixposten entfernt

  Scenario: Liste gruppiert Einnahmen vor Ausgaben
    Given es existieren sowohl Einnahmen- als auch Ausgaben-Fixposten
    Then werden zuerst alle Einnahmen (alphabetisch), danach alle Ausgaben (alphabetisch) angezeigt

  Scenario: Summen-Übersicht
    Given mehrere Fixposten existieren
    Then berechnet die App: Summe der monatlichen Einnahmen, Summe der monatlichen Ausgaben (als positiver Betrag),
      und die Differenz (Netto) — jeweils zusätzlich als Jahresbetrag (×12) ausgewiesen

  Scenario: Leerzustand
    Given es existiert kein Fixposten
    Then zeigt die Liste den Hinweis "Noch keine Fixposten erfasst."
