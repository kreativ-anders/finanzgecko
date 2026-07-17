# Quelle: lib/ui/views/accounts_view.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/models/account.dart
# Implementierung: lib/ui/views/accounts_view.dart
@accounts
Feature: Konten verwalten
  Als Nutzer:in verwalte ich meine Konten (Girokonto, Tagesgeld, Depot, Bargeld, Krypto, …), damit ich darauf
  monatlich Kontostände erfassen kann.

  Background:
    Given die App ist gestartet und initialisiert

  Scenario: Neues Konto anlegen mit Pflichtfeldern
    Given ich bin auf der Ansicht "Konten"
    When ich im Formular "Neues Konto" folgende Werte eingebe:
      | Feld     | Wert          |
      | Bank     | DKB           |
      | Name     | Gehaltskonto  |
      | Typ      | Girokonto     |
      | Währung  | EUR           |
    And ich auf "Konto anlegen" klicke
    Then wird ein neues Konto mit diesen Werten gespeichert
    And die Akzentfarbe des Kontos ist die Markenfarbe von "DKB"
    And das Konto ist nicht archiviert
    And ich sehe die Bestätigung "Angelegt."
    And das Formular ist wieder leer (Bank/Name geleert, Typ/Währung auf Vorgabewerte zurückgesetzt)

  Scenario: Bankfeld erlaubt nur bekannte Banken
    Given ich bin auf der Ansicht "Konten" im Formular "Neues Konto"
    When ich im Bankfeld einen Text eingebe, der zu keiner Bank aus der bekannten Liste passt
    Then zeigt das Formular den Validierungsfehler "Bitte eine Bank aus der Liste auswählen"
    And das Konto wird nicht angelegt

  Scenario: Bankfeld schlägt passende Banken mit Farb-Vorschau vor
    Given ich bin auf der Ansicht "Konten" im Formular "Neues Konto"
    When ich im Bankfeld einen Teiltext einer bekannten Bank eingebe
    Then erscheinen passende Vorschläge, jeweils mit der Markenfarbe der Bank als Farbpunkt
    And ein Hinweis "Bank fehlt?" mit Links zu "Auf GitHub vorschlagen" und "E-Mail schreiben" ist sichtbar

  Scenario: Kein Farbfallback ohne bekannte Bank — Kontotyp-Farbe als Standard
    Given ich bin auf der Ansicht "Konten" im Formular "Neues Konto"
    And das Bankfeld ist leer
    Then zeigt die Farb-Vorschau die Standardfarbe des aktuell gewählten Kontotyps

  Scenario: Fremdwährungs-Hinweis erscheint nur bei abweichender Währung
    Given die Basiswährung der App ist "EUR"
    And ich bin im Formular "Neues Konto"
    When ich als Kontowährung "USD" wähle
    Then sehe ich den Hinweis, dass Wechselkurse automatisch über die frankfurter.dev API abgerufen und für den
      Offline-Betrieb zwischengespeichert werden
    When ich als Kontowährung "EUR" wähle
    Then verschwindet dieser Hinweis

  Scenario: Bestehendes Konto bearbeiten
    Given ein Konto "Tagesgeld Sparkasse" existiert
    When ich bei diesem Konto auf "Bearbeiten" klicke
    And ich Name, Bank, Typ oder Währung ändere
    And ich auf "Speichern" klicke
    Then werden die Änderungen übernommen
    And ich sehe eine Speicher-Bestätigung
    And das Bearbeitungsformular schließt sich wieder

  Scenario: Bearbeiten ohne gültigen Namen wird abgelehnt
    Given ein Konto wird gerade bearbeitet
    When ich das Namensfeld leere und auf "Speichern" klicke
    Then wird eine Fehlermeldung "Bitte einen Namen eingeben." angezeigt
    And das Konto wird nicht gespeichert

  Scenario: Bearbeiten mit unbekannter Bank wird abgelehnt
    Given ein Konto wird gerade bearbeitet
    When ich im Bankfeld einen Text eingebe, der zu keiner bekannten Bank passt
    And ich auf "Speichern" klicke
    Then wird eine Fehlermeldung "Bitte eine Bank aus der Liste auswählen." angezeigt
    And das Konto wird nicht gespeichert

  Scenario: Konto archivieren (Soft-Delete)
    Given ein Konto "Altes Depot" existiert
    When ich es archiviere und die Sicherheitsabfrage bestätige
    Then verschwindet das Konto aus der aktiven Kontenliste
    And es verschwindet aus allen Dashboard-Charts und der Erfassen-Ansicht
    And bereits erfasste Kontostände dieses Kontos bleiben in der Datenbank erhalten (kein Datenverlust)

  Scenario: Archivieren erfordert Bestätigung
    Given ein Konto existiert
    When ich auf "Archivieren" klicke
    Then erscheint eine Sicherheitsabfrage mit dem Hinweis, dass das Konto danach komplett aus allen Charts verschwindet
    And bei "Abbrechen" bleibt das Konto aktiv

  Scenario: Kontostände eines archivierten Kontos wiederherstellen
    Given ein Konto wurde archiviert und hat Kontostände aus früheren Monaten
    When ich in der Ansicht "Einträge" im Abschnitt "Archivierte Konten" bei einem seiner Einträge auf
      "Wiederherstellen" klicke
    Then wird das zugehörige Konto reaktiviert (nicht mehr archiviert)
    And es erscheint wieder in der aktiven Kontenliste und allen Charts
