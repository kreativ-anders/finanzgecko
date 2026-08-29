# Source: lib/services/notification_service.dart, lib/state/app_state.dart, lib/data/app_store.dart, lib/data/app_schema.dart, lib/ui/views/settings_view.dart
# Implementation: lib/services/notification_service.dart
@notifications
Feature: OS notifications for backup and Vermögenswerte reminders
  As a user, I want a native system notification as soon as the backup or Vermögenswerte reminder newly
  becomes overdue — not only as a Dashboard banner that I only see while the app is in the foreground.

  Background:
    Given the app is started and initialized
    And Desktop-Benachrichtigungen are switched on, unless a scenario says otherwise

  Rule: Opt-in — the feature is off until the user asks for it

    Scenario: Notifications are off by default
      Given a fresh installation with no prior setting
      Then the "Desktop-Benachrichtigungen" toggle in Einstellungen is off
      And no OS notification is sent even while a reminder is overdue
      And the operating system is never asked for permission

    Scenario: An installation from before the opt-in switch also starts off
      Given a data file written by an older version, in which the setting was on by default
      When the app is started
      Then the toggle is off, because that older value is deliberately not carried over
      And nobody gets a permission prompt they did not ask for

    Scenario: Switching the toggle on asks macOS for permission
      Given the toggle is off
      When I switch it on
      Then macOS asks once for permission for notifications
      And with permission granted the toggle stays on
      And a reminder that is already overdue notifies right away

    Scenario: A denied permission does not leave a toggle that lies
      Given I switch the toggle on
      When the operating system refuses
      Then the toggle stays off
      And a note explains that this can be changed in the Systemeinstellungen under "Mitteilungen"
      And the app does not ask again — macOS only asks once per user

    Scenario: Switching off needs no permission
      When I switch the toggle off
      Then the operating system is not asked

  Rule: The toggle governs both kinds

    Scenario: A disabled toggle suppresses both kinds of notifications
      Given I turned off "Desktop-Benachrichtigungen" in Einstellungen
      And both the backup and the Vermögenswerte reminder are overdue
      Then no OS notification is sent

    Scenario: Both kinds in one cycle stay visible side by side
      Given the backup reminder and a Vermögenswert both newly become overdue in the same check
      Then two separate notifications appear
      And neither replaces the other — they carry distinct notification ids

  Rule: Backup reminder — once per overdue episode

    Scenario: No notification while the app is completely empty
      Given neither Konten, Kontostände, Vermögenswerte, nor Fixposten exist
      Then no backup notification appears, regardless of whether an export ever happened

    Scenario: A notification fires as soon as the backup reminder newly becomes overdue
      Given at least one Konto, Kontostand, Vermögenswert, or Fixposten exists
      And either the last export is kBackupReminderRepeatDays (90, ~3 months) or longer ago, or there was
        never an export and the earliest recorded activity is kBackupReminderFirstDays (182, ~6 months) or
        longer ago
      And no notification has fired for this overdue state yet
      When the app starts or an action triggers a reload
      Then an OS notification appears with the same text as the Dashboard banner
      And the episode is marked as "notified"

    Scenario: No repeat notification while the episode stays unresolved
      Given a notification has already fired for the current backup overdue state
      When the app is restarted, or more time passes without an export
      Then no further notification appears for this episode

    Scenario: An export resolves the episode — the next overdue state notifies again
      Given a notification has already fired for the current backup overdue state
      When I export a backup
      Then the episode is reset
      And once kBackupReminderRepeatDays is reached again, exactly one notification appears again

  Rule: Vermögenswerte reminder — once per Vermögenswert and episode

    Scenario: A notification fires for newly overdue Vermögenswerte, bundled
      Given at least one Vermögenswert hasn't been re-evaluated for over kAssetReevaluationDays (182) days
      And no notification has fired for these Vermögenswerte yet
      Then a single OS notification appears with every affected name (like the Dashboard banner) — no
        notification flood, one message per check cycle, not one per Vermögenswert

    Scenario: Re-evaluating a Vermögenswert resolves its episode
      Given a notification has already fired for a Vermögenswert
      When I re-evaluate (update) its value
      Then its episode is reset
      And it triggers another notification at the earliest after kAssetReevaluationDays days again

    Scenario: Deleting a Vermögenswert removes its episode
      Given a notification has already fired for a Vermögenswert
      When I delete it
      Then its notification status is discarded (no data leak beyond the Vermögenswert's lifetime)

  Rule: Deliberate limits

    Scenario: Clicking the notification doesn't navigate within the app
      Given a notification is visible
      When I click it
      Then nothing else happens beyond the OS's typical focus/open of the window (no deep link)

    Scenario: No delivery while the app is closed
      Given the app isn't running
      Then no notification is sent even if a reminder becomes overdue in the meantime
      And the check catches up only at the next start resp. while the app is running again afterward (no
        background service, see AI_MASTER.md §2/§6)

    Scenario: A missing notification backend must never crash the app
      Given no notification daemon is available (e.g. a minimal Linux setup) or permission was denied
      Then the notification silently doesn't happen
      And every other app function stays unaffected

    Scenario: The Dashboard banners are the primary channel
      Given the toggle is off
      Then the backup and Vermögenswerte reminders still appear as banners on the Dashboard
      And the notification only ever duplicates them outside the window, it never replaces them
