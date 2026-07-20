# Quelle: lib/services/notification_service.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/data/app_schema.dart, lib/ui/views/settings_view.dart
# Implementierung: lib/services/notification_service.dart
@notifications
Feature: OS-Benachrichtigungen für Backup- und Vermögenswerte-Reminder
  Als Nutzer:in möchte ich eine native System-Benachrichtigung bekommen, sobald der Backup- oder der
  Vermögenswerte-Reminder neu überfällig wird — nicht nur als Banner im Dashboard, das ich nur sehe, wenn die
  App gerade im Vordergrund ist.

  Background:
    Given die App ist gestartet und initialisiert
    And Desktop-Benachrichtigungen sind aktiviert (Standard)

  Scenario: Benachrichtigungen sind standardmäßig aktiviert
    Given eine frische Installation ohne bisherige Einstellung
    Then ist der Schalter "Desktop-Benachrichtigungen" in den Einstellungen aktiv

  Scenario: Deaktivierter Schalter unterdrückt beide Benachrichtigungsarten
    Given ich habe "Desktop-Benachrichtigungen" in den Einstellungen deaktiviert
    And sowohl der Backup- als auch der Vermögenswerte-Reminder sind überfällig
    Then wird keine OS-Benachrichtigung gesendet

  Rule: Backup-Reminder — einmal pro überfälliger Episode

    Scenario: Keine Benachrichtigung, solange die App komplett leer ist
      Given es existieren weder Konten noch Kontostände noch Vermögenswerte noch Fixposten
      Then erscheint keine Backup-Benachrichtigung, unabhängig davon, ob je exportiert wurde

    Scenario: Benachrichtigung feuert, sobald der Backup-Reminder neu überfällig wird
      Given es existiert mindestens ein Konto, Kontostand, Vermögenswert oder Fixposten
      And entweder liegt der letzte Export kBackupReminderRepeatDays (90, ~3 Monate) oder länger zurück, oder es
        wurde nie exportiert und die früheste erfasste Aktivität liegt kBackupReminderFirstDays (182, ~6 Monate)
        oder länger zurück
      And für diese Überfälligkeit wurde noch nicht benachrichtigt
      When die App startet oder eine Aktion einen Reload auslöst
      Then erscheint eine OS-Benachrichtigung mit demselben Text wie das Dashboard-Banner
      And die Episode wird als "benachrichtigt" vermerkt

    Scenario: Keine erneute Benachrichtigung, solange die Episode ungelöst bleibt
      Given für die aktuelle Backup-Überfälligkeit wurde bereits benachrichtigt
      When die App neu gestartet wird oder weitere Zeit vergeht, ohne dass exportiert wird
      Then erscheint keine weitere Benachrichtigung für diese Episode

    Scenario: Export löst die Episode auf — die nächste Überfälligkeit benachrichtigt wieder
      Given für die aktuelle Backup-Überfälligkeit wurde bereits benachrichtigt
      When ich ein Backup exportiere
      Then wird die Episode zurückgesetzt
      And sobald kBackupReminderRepeatDays erneut erreicht sind, erscheint wieder genau eine Benachrichtigung

  Rule: Vermögenswerte-Reminder — einmal pro Vermögenswert und Episode

    Scenario: Benachrichtigung feuert für neu überfällige Vermögenswerte, gebündelt
      Given mindestens ein Vermögenswert ist seit über kAssetReevaluationDays (182) Tagen nicht neu bewertet
      And für diese Vermögenswerte wurde noch nicht benachrichtigt
      Then erscheint eine einzelne OS-Benachrichtigung mit allen betroffenen Namen (wie im Dashboard-Banner) —
        keine Benachrichtigungsflut, eine Meldung pro Prüfzyklus, nicht eine je Vermögenswert

    Scenario: Neubewertung eines Vermögenswerts löst dessen Episode auf
      Given für einen Vermögenswert wurde bereits benachrichtigt
      When ich seinen Wert neu bewerte (aktualisiere)
      Then wird seine Episode zurückgesetzt
      And er löst frühestens nach erneut kAssetReevaluationDays Tagen wieder eine Benachrichtigung aus

    Scenario: Löschen eines Vermögenswerts entfernt seine Episode
      Given für einen Vermögenswert wurde bereits benachrichtigt
      When ich ihn lösche
      Then wird sein Benachrichtigungs-Status verworfen (kein Datenleck über die Lebensdauer des Vermögenswerts hinaus)

  Rule: Bewusste Grenzen

    Scenario: Klick auf die Benachrichtigung navigiert nicht in der App
      Given eine Benachrichtigung ist sichtbar
      When ich darauf klicke
      Then passiert außer dem OS-typischen Fokussieren/Öffnen des Fensters nichts Zusätzliches (kein Deep-Link)

    Scenario: Keine Zustellung bei geschlossener App
      Given die App läuft nicht
      Then wird auch dann keine Benachrichtigung gesendet, wenn währenddessen ein Reminder überfällig wird
      And die Prüfung holt das erst beim nächsten Start bzw. während der App danach wieder läuft nach
        (kein Hintergrunddienst, siehe AI_MASTER.md §2/§6)

    Scenario: Ein fehlendes Notification-Backend darf die App nie zum Absturz bringen
      Given kein Notification-Daemon ist verfügbar (z. B. minimales Linux-Setup) oder die Berechtigung wurde verweigert
      Then bleibt die Benachrichtigung stumm aus
      And alle anderen App-Funktionen bleiben unbeeinträchtigt
