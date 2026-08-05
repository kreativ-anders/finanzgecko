# Quelle: lib/ui/views/entries_view.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/models/balance.dart
# Implementierung: lib/ui/views/entries_view.dart
@balances @entries
Feature: Monatliche Kontostände erfassen
  Als Nutzer:in erfasse ich monatlich die Kontostände all meiner Konten an einer Stelle, damit das Dashboard einen
  vollständigen Vermögensverlauf berechnen kann.

  Background:
    Given die App ist gestartet und initialisiert
    And mindestens ein aktives Konto existiert

  Scenario: Ohne Konten wird zuerst zur Kontoerstellung geleitet
    Given noch kein Konto existiert
    When ich die Ansicht "Einträge" öffne
    Then sehe ich den Hinweis "Erst ein Konto anlegen"
    And einen Button, der mich zur Ansicht "Konten" bringt

  Scenario: Standardmäßig ist der aktuelle Monat ausgewählt
    Given ich öffne die Ansicht "Einträge"
    Then ist der Zeitraum auf den aktuellen Kalendermonat voreingestellt

  Scenario: Rückwirkende Erfassung durch Monatswechsel
    Given ich bin auf der Ansicht "Einträge"
    When ich über den Monats-Picker einen anderen (auch vergangenen) Monat wähle
    Then zeigt die Liste die für diesen Monat bereits gespeicherten Werte je Konto
    And leere Konten zeigen den Wert des letzten bekannten Monats nur als Platzhalter (Hint), nicht vorausgefüllt

  Scenario: Bestehenden Eintrag überschreiben (Upsert pro Konto+Monat)
    Given für Konto "Girokonto" existiert bereits ein Kontostand im gewählten Monat
    When ich für dieses Konto einen neuen Betrag eingebe und speichere
    Then wird der bestehende Eintrag für Konto+Monat überschrieben (kein Duplikat)
    And der neue Wechselkurs zum Speicherzeitpunkt wird eingefroren

  Scenario: Leere Felder werden beim Speichern übersprungen
    Given mehrere Konten sind in der Liste sichtbar
    When ich nur einen Teil der Beträge ausfülle und auf "Alle speichern" klicke
    Then werden nur die ausgefüllten Konten gespeichert
    And die leer gelassenen Konten bleiben unverändert
    And die Rückmeldung nennt die Anzahl gespeicherter Konten

  Scenario: Enter springt zum nächsten Konto, letztes Enter speichert
    Given ich habe den Fokus im Betragsfeld eines Kontos, das nicht das letzte in der Liste ist
    When ich Enter drücke
    Then springt der Fokus zum Betragsfeld des nächsten Kontos
    Given ich habe den Fokus im Betragsfeld des letzten Kontos in der Liste
    When ich Enter drücke
    Then löst das denselben Effekt wie "Alle speichern" aus

  Scenario: Aus dem Dashboard auf ein bestimmtes Konto gesprungen
    Given ich habe auf dem Dashboard eine Konto-Karte angeklickt
    When die Ansicht "Einträge" öffnet
    Then hat das Betragsfeld genau dieses Kontos den Fokus statt des ersten Kontos in der Liste
    And die Zeile wird in den sichtbaren Bereich gescrollt, falls sie unterhalb liegt
    And der Monat ist der übliche Standard (aktueller Monat), die Liste bleibt vollständig — es wird nicht gefiltert
    Given das angeklickte Konto ist in der Liste gar nicht enthalten (z. B. archiviert)
    Then verhält sich die Ansicht wie bei einem normalen Aufruf: der Fokus liegt auf dem ersten Konto
    Given ich verlasse "Einträge" und kehre später über die Navigationsleiste zurück
    Then wirkt der frühere Kartenklick nicht nach — der Fokus liegt wieder auf dem ersten Konto

  Scenario: Nur fehlende Konten anzeigen
    Given im gewählten Monat ist für einen Teil der Konten bereits ein Wert erfasst
    When ich den Schalter "Nur fehlende anzeigen" aktiviere
    Then zeigt die Liste ausschließlich Konten ohne Eintrag für diesen Monat

  Scenario: Live-Zwischensumme während der Eingabe
    Given ich tippe Beträge in mehrere Betragsfelder, ohne zu speichern
    Then aktualisiert sich am unteren Bildschirmrand laufend eine Zwischensumme in der Basiswährung
    And eine Differenz gegenüber der Summe der zuletzt gespeicherten Werte wird angezeigt
    And diese Vorschau nutzt keinen Netzwerkaufruf, sondern eine Kursschätzung (siehe currency_exchange.feature)

  Scenario: Live-Zwischensumme warnt vor fehlender Kursschätzung
    Given ein Konto in Fremdwährung hat weder einen vorherigen Kontostand noch einen anderen gespeicherten Kurs
      derselben Währung
    When ich für dieses Konto einen Betrag eintippe
    Then wird es in der Live-Zwischensumme nicht mitgerechnet
    And ein Hinweis nennt die Anzahl der Konten "in Fremdwährung ohne Kursschätzung"

  Scenario: Anomalie-Hinweis bei ungewöhnlichem Sprung
    Given der letzte gespeicherte Kontostand eines Kontos beträgt 1000 in Kontowährung
    When ich einen neuen Betrag eintippe, der mindestens 10x größer oder kleiner als 1000 ist (und ungleich 0)
    Then erscheint neben dem Feld ein nicht blockierender Hinweis "Ungewöhnlich: … Tippfehler?"
    And ich kann den Wert trotzdem unverändert speichern (kein Zwangsstopp)

  Scenario: Kein Anomalie-Hinweis ohne Vergleichswert
    Given für dieses Konto existiert noch kein vorheriger Kontostand
    When ich einen beliebigen Betrag eintippe
    Then erscheint kein Anomalie-Hinweis

  Scenario: Bestehenden Eintrag löschen
    Given ein Kontostand für Konto+Monat existiert
    When ich in dieser Zeile auf das Lösch-Icon klicke und die Sicherheitsabfrage bestätige
    Then wird der Eintrag entfernt
    And das Eingabefeld dieser Zeile wird geleert
    And ich sehe die Bestätigung "Gelöscht."

  Scenario: Verwaiste Einträge archivierter Konten bleiben sichtbar
    Given ein Konto mit erfassten Kontoständen wird archiviert
    When ich die Ansicht "Einträge" für einen Monat mit einem solchen Eintrag öffne
    Then erscheint ein separater Abschnitt "Archivierte Konten" mit diesem Eintrag
    And von dort aus kann das zugehörige Konto wiederhergestellt oder der Eintrag gelöscht werden

  Scenario: Verwaister Eintrag eines vollständig gelöschten Kontos
    Given ein Kontostand referenziert eine Konto-ID, die nicht mehr existiert (z. B. nach manuellem Import)
    Then zeigt die Zeile "Konto gelöscht" anstelle eines Kontonamens
    And es ist nur die Option "Löschen" verfügbar, keine "Wiederherstellen"-Option

  Scenario: Datum für den Wechselkurs-Abruf hängt vom Monat ab
    Given der gewählte Monat ist der aktuelle Kalendermonat
    When ich speichere
    Then wird für Fremdwährungskonten der Kurs zum heutigen Datum abgefragt (nicht zum Monatsende, das ggf. in der
      Zukunft liegt und noch keinen veröffentlichten Kurs hat)
    Given der gewählte Monat liegt vollständig in der Vergangenheit
    When ich speichere
    Then wird der Kurs zum letzten Kalendertag dieses Monats abgefragt
