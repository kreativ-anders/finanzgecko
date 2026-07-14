# Quelle: lib/ui/views/assets_view.dart, lib/state/app_state.dart, lib/models/asset.dart, lib/constants.dart
@assets
Feature: Vermögenswerte (Sachwerte) verwalten
  Als Nutzer:in erfasse ich Sachwerte wie Elektronik, Möbel oder Fahrzeuge mit ihrem aktuellen Wert, getrennt von den
  monatlichen Kontoständen, da sie keinen echten Zeitverlauf haben.

  Background:
    Given die App ist gestartet und initialisiert

  Scenario: Neuen Vermögenswert anlegen
    Given ich bin auf der Ansicht "Vermögenswerte"
    When ich Bezeichnung und Wert ausfülle und auf "Anlegen" klicke
    Then wird ein neuer Vermögenswert mit dem heutigen Datum als "zuletzt bewertet" angelegt
    And ich sehe die Bestätigung "Angelegt."
    And das Formular wird geleert

  Scenario: Pflichtfelder beim Anlegen
    Given ich bin im Formular "Neuer Vermögenswert"
    When ich die Bezeichnung leer lasse oder einen nicht als Zahl interpretierbaren Wert eingebe
    Then wird der Vermögenswert nicht angelegt
    And ein Validierungsfehler wird am jeweiligen Feld angezeigt

  Scenario: Wert inline bearbeiten mit Autosave
    Given ein Vermögenswert existiert bereits
    When ich seinen Wert in der Liste direkt ändere
    Then wird nach 600ms Tippstopp automatisch gespeichert (kein expliziter Speichern-Button)
    And "zuletzt bewertet" wird auf heute aktualisiert
    And ich sehe eine unaufdringliche Speicher-Bestätigung

  Scenario: Autosave wird auch bei Fokusverlust oder Enter sofort ausgelöst
    Given ich habe den Wert eines Vermögenswerts geändert, ohne 600ms zu warten
    When ich das Feld verlasse (Klick woanders hin) oder Enter drücke
    Then wird sofort gespeichert, ohne auf den Debounce zu warten

  Scenario: Ungültiger Wert beim Inline-Edit wird verworfen
    Given ich bearbeite den Wert eines bestehenden Vermögenswerts
    When ich einen nicht interpretierbaren Text eingebe und das Feld verlasse
    Then wird nichts gespeichert
    And das Feld springt zurück auf den zuletzt gültigen gespeicherten Wert

  Scenario: Wertänderung zählt automatisch als Neubewertung
    Given ein Vermögenswert ist überfällig zur Neubewertung
    When ich seinen Wert ändere (auch wenn unverändert derselbe Betrag erneut eingegeben wird über das Wert-Feld)
    Then gilt er ab sofort wieder als aktuell bewertet, ohne separaten "Neu bewerten"-Button

  Scenario: Überfälligkeits-Kennzeichnung nach ~6 Monaten
    Given ein Vermögenswert wurde vor mindestens 182 Tagen zuletzt bewertet, oder noch nie
    Then zeigt seine Zeile ein Badge "Neu bewerten"
    Given die letzte Bewertung liegt weniger als 182 Tage zurück
    Then erscheint kein Badge

  Scenario: Vermögenswert löschen
    Given ein Vermögenswert existiert
    When ich auf "Löschen" klicke und die Sicherheitsabfrage bestätige
    Then wird der Vermögenswert entfernt
    And ich sehe die Bestätigung "Gelöscht."

  Scenario: Leerzustand
    Given es existiert kein Vermögenswert
    Then zeigt die Liste den Hinweis "Noch keine Vermögenswerte angelegt."

  Scenario: Sortierung der Liste
    Given mehrere Vermögenswerte existieren
    Then ist die Liste alphabetisch nach Bezeichnung sortiert
