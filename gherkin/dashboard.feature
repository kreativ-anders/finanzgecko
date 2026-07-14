# Quelle: lib/ui/views/dashboard_view.dart, lib/state/app_state.dart, lib/utils/analysis.dart, lib/constants.dart
@dashboard
Feature: Dashboard — Vermögensübersicht
  Als Nutzer:in sehe ich auf einen Blick mein Gesamtvermögen, dessen Verlauf und Prognose, die Verteilung nach
  Kontotyp und wichtige Kennzahlen, gefiltert nach einem wählbaren Zeitraum.

  Background:
    Given die App ist gestartet und initialisiert

  Scenario: Leerer Zustand ohne jegliche Kontostände
    Given es existiert noch kein einziger erfasster Kontostand
    When ich das Dashboard öffne
    Then sehe ich den Hinweis "Noch kein Vermögen erfasst" mit einem Button zum Anlegen eines Kontos
    And trotzdem werden die Abschnitte "Fixposten" und "Vermögenswerte" mit ihrem jeweiligen Leer- oder Ist-Zustand angezeigt

  Rule: Zeitraum-Filter steuert das gesamte Dashboard

    Scenario: Verfügbare Zeitraum-Presets hängen von der Datenhistorie ab
      Given es gibt erfasste Kontostände über mehrere Jahre
      Then sind die Presets "Dieses Jahr", "12 Monate", "Letztes Jahr" und "Alle" verfügbar,
        jedes nur, wenn es eine vom Gesamtzeitraum ("Alle") unterscheidbare, nicht-leere Untermenge ergibt
      And "Alle" ist immer verfügbar

    Scenario: Standard-Preset ist "Dieses Jahr", wenn verfügbar
      Given "Dieses Jahr" liefert eine vom Gesamtzeitraum unterscheidbare Teilmenge
      When ich das Dashboard zum ersten Mal in dieser Sitzung öffne
      Then ist "Dieses Jahr" vorausgewählt
      Given "Dieses Jahr" ist nicht als eigenes Preset verfügbar (z. B. weil es der Gesamthistorie entspricht)
      Then ist stattdessen "Alle" vorausgewählt

    Scenario: Zeitraum-Wechsel wirkt auf alle zeitbasierten Karten gleichzeitig
      When ich im Zeitraum-Filter ein anderes Preset wähle
      Then aktualisieren sich gleichzeitig: die Gesamtvermögens-Kopfzeile, die Verlaufs-Karte samt Prognose, die
        Zusammensetzungs-Karte, die Verteilungs-Karte und die Kennzahlen-Karte

    Scenario: Prognose nur sichtbar, wenn der Zeitraum bis zum aktuellsten Monat reicht
      Given ich wähle das Preset "Letztes Jahr"
      Then wird in der Verlaufs-Karte keine Prognose gezeichnet, weil der Anker nicht mehr aktuell wäre
      Given ich wähle ein Preset, dessen letzter Monat der neueste insgesamt erfasste Monat ist
      Then wird eine Prognose bis zum Jahresende gezeichnet (im Dezember: ein volles Jahr vorausprojiziert)

  Rule: Gesamtvermögens-Kopfzeile

    Scenario: Vermögenswerte sind standardmäßig nicht in der Summe enthalten
      Given es existieren sowohl Kontostände als auch Vermögenswerte
      When ich das Dashboard öffne
      Then zeigt die Kopfzeile "GESAMTVERMÖGEN" nur die Summe der Kontostände
      And ein Umschalter "Konten" / "inkl. Sachwerte" ist sichtbar (nur wenn Vermögenswerte existieren)
      When ich auf "inkl. Sachwerte" umschalte
      Then wird die Summe der Vermögenswerte addiert und die Beschriftung wechselt auf
        "GESAMTVERMÖGEN INKL. SACHWERTE"

    Scenario: Veränderung gegenüber dem Vormonat
      Given es gibt einen vorherigen erfassten Monat innerhalb des aktiven Zeitraums
      Then zeigt die Kopfzeile die absolute und prozentuale Veränderung gegenüber diesem Vormonat, grün bei ≥0,
        rot bei <0
      Given es gibt keinen Vormonat im aktiven Zeitraum
      Then zeigt die Kopfzeile "Noch kein Vergleichsmonat" statt einer Delta-Angabe

    Scenario: Geschätzte Aufteilung in Einzahlungen vs. Markt
      Given es gibt Fixposten und einen Vormonat
      Then wird die Veränderung zusätzlich in "eingezahlt" (Fixposten-Netto × Monatsabstand) und
        "Markt & Sonstiges" (Rest) aufgeteilt, jeweils als Schätzung gekennzeichnet
      Given es gibt keine Fixposten
      Then entfällt diese Zusatzzeile

    Scenario: Erfassungsstand des aktuellen Monats
      Then zeigt die Kopfzeile "Für diesen Monat sind X von Y Konten erfasst"

    Scenario: Hinweis auf Rundungsdifferenzen bei Fremdwährungskonten
      Given mindestens ein Konto der aktuellen Periode hat eine von der Basiswährung abweichende Währung
      Then erscheint ein Hinweis, dass die Summe durch Wechselkurs-Rundung um wenige Cent von der Summe der einzeln
        angezeigten Kontostände abweichen kann

  Rule: Verlauf & Prognose

    Scenario: Prognose blendet Trend und Fixposten-Plan
      Given es gibt mindestens zwei Monate Verlaufs-Historie
      Then basiert die monatliche Prognoserate auf einer linearen Trendschätzung der Historie, stabilisiert durch
        das Fixposten-Netto als Prior, dessen Einfluss mit wachsender Historie abnimmt
      And der Beschriftungstext benennt die verwendete Basis ("Prognose aus X Monaten Verlauf, mit Fixposten
        geglättet" / "Prognose aus X Monaten Verlauf" / "Prognose aus den Fixposten (noch wenig Verlauf)")

    Scenario: Prognosehorizont reicht bis Jahresende
      Given der aktive Zeitraum reicht bis zum aktuellsten Monat
      Then wird die Prognose bis zum Ende des Kalenderjahres des letzten Monats projiziert
      And im Dezember wird stattdessen ein volles Jahr (12 Monate) projiziert statt 0

  Rule: Zusammensetzung & Verteilung

    Scenario: Zusammensetzung über Zeit gruppiert nach Kontotyp
      Given es gibt mindestens zwei Monate mit Daten
      Then zeigt eine gestapelte Flächen-Karte je Kontotyp-Serie über alle Monate des aktiven Zeitraums
      And negative Kontotyp-Summen (z. B. überzogenes Konto) fließen mit 0 statt negativ in den Stapel ein
      And Kontotypen werden in der Reihenfolge der bekannten Liste angezeigt, unbekannte/benutzerdefinierte Typen
        werden angehängt

    Scenario: Verteilungs-Donut zeigt nur den aktuellsten Monat des aktiven Zeitraums
      Then zeigt der Donut die Summen je Kontotyp für genau den letzten Monat des aktiven Zeitraums

    Scenario: Konzentrationsrisiko-Hinweis
      Given mindestens zwei Kontotypen mit positiver Summe existieren
      And der größte Kontotyp-Anteil an der positiven Gesamtsumme beträgt mindestens 65%
      Then erscheint ein roter Hinweis, der den Kontotyp und seinen Prozentanteil nennt
      Given der größte Anteil liegt unter 65% oder es gibt nur einen positiven Kontotyp
      Then erscheint kein Konzentrationsrisiko-Hinweis

  Rule: Kennzahlen

    Scenario: Kennzahlen-Karte erscheint erst ab zwei Monaten Historie
      Given weniger als zwei Monate mit Daten liegen im aktiven Zeitraum
      Then wird keine Kennzahlen-Karte angezeigt
      Given mindestens zwei Monate mit Daten liegen vor
      Then zeigt die Karte: Gesamtveränderung seit Startmonat, bester Monat, schwächster Monat,
        Ø-Veränderung/Monat, Monate im Plus (Anzahl und Anteil), Höchststand und dessen Monat

  Rule: Reminder-Banner (Reihenfolge ist bewusst gewählt)

    Scenario: Update-Reminder, wenn der aktuelle Monat noch nicht erfasst ist
      Given es gibt bereits Historie, aber für den aktuellen Kalendermonat existiert noch kein Kontostand
      Then erscheint als erstes Banner ein Hinweis mit dem zuletzt erfassten Monat und einer Aktion "Jetzt erfassen",
        die zur Ansicht "Einträge" führt
      Given der aktuelle Monat ist bereits vollständig oder teilweise erfasst (oder es gibt noch keine Historie)
      Then erscheint dieses Banner nicht

    Scenario: Overspend-Banner bei negativem Fixposten-Netto
      Given es existieren Fixposten und ihre Summe (Einnahmen − Ausgaben) ist negativ
      Then erscheint ein auffälliges rotes Banner mit den monatlichen Ausgaben- und Einnahmenbeträgen und einer
        Aktion "Fixposten prüfen"
      Given das Netto ist ≥0 oder es gibt keine Fixposten
      Then erscheint dieses Banner nicht

    Scenario: Backup-Reminder
      Given noch nie ein Export durchgeführt wurde
      Then erscheint ein Banner "Noch nie exportiert — leg jetzt ein erstes Backup an."
      Given der letzte Export liegt mindestens 30 Tage zurück
      Then erscheint ein Banner mit der Anzahl Tage seit dem letzten Export
      Given der letzte Export liegt weniger als 30 Tage zurück
      Then erscheint kein Backup-Reminder-Banner (nur eine unauffällige Info in den Einstellungen)

    Scenario: Asset-Reevaluation-Reminder
      Given mindestens ein Vermögenswert wurde seit mindestens 182 Tagen (~6 Monate) nicht neu bewertet
        (oder nie)
      Then erscheint ein Banner, das die betroffenen Vermögenswerte namentlich auflistet, mit Aktion "Jetzt prüfen"

  Rule: Konto-Karten

    Scenario: Jede Konto-Karte zeigt Mini-Verlauf und Monatsvergleich
      Given ein Konto hat mindestens einen erfassten Kontostand
      Then zeigt seine Karte den aktuellsten Betrag, ein Mini-Liniendiagramm über alle erfassten Monate dieses
        Kontos, und — falls ein Vormonat existiert — die Veränderung dagegen (grün/rot)
      Given ein Konto hat noch keinen erfassten Kontostand
      Then zeigt seine Karte "—" statt eines Betrags und keinen Verlauf
