# Source: lib/data/backup_crypto.dart, lib/constants.dart, lib/ui/widgets/backup_passphrase_dialog.dart
# Implementation: lib/data/backup_crypto.dart
# Executable: test/bdd/backup_file_limits_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @backup
Feature: Limits on backup passwords and on the key derivation read from a backup

  # A password-protected backup names its own key-derivation parameters, so an import reads them from an
  # untrusted file: they are bounded before any work starts. Every backup this app has written uses
  # 200,000 iterations and passes unchanged. On export, a new password needs at least 8 characters,
  # since the file is meant to travel to clouds and USB sticks. Older backups protected with a shorter
  # password still import.
  #
  # Free-text descriptions are deliberately comments here: the runner
  # (test/support/gherkin_runner.dart) only accepts comments, tags, and steps
  # under "Feature:" and throws on anything else.

  Scenario: A password with 8 characters may protect an export
    When I check the new backup password "abcdefgh"
    Then the password is accepted

  Scenario: A password with 7 characters may not protect an export
    When I check the new backup password "abcdefg"
    Then the password is rejected

  # Characters, not UTF-16 units: "ä" and an emoji each count once.
  Scenario: Umlauts and emoji count as one character each
    When I check the new backup password "äöü😀abc"
    Then the password is rejected

  Scenario: A backup written by this app decrypts with its password
    Given a backup protected with password "richtig-lang"
    When I decrypt it with password "richtig-lang"
    Then the backup content is restored

  Scenario: An older backup with a short password still imports
    Given a backup protected with password "kurz"
    When I decrypt it with password "kurz"
    Then the backup content is restored

  Scenario: A backup claiming too few iterations is rejected before deriving a key
    Given a backup protected with password "richtig-lang"
    And its iteration count is changed to 99999
    When I decrypt it with password "richtig-lang"
    Then it is rejected as an unsupported backup format

  # Without the ceiling, this count would freeze the app for minutes before failing.
  Scenario: A backup claiming too many iterations is rejected before deriving a key
    Given a backup protected with password "richtig-lang"
    And its iteration count is changed to 10000001
    When I decrypt it with password "richtig-lang"
    Then it is rejected as an unsupported backup format

  Scenario: A backup claiming a negative iteration count is rejected
    Given a backup protected with password "richtig-lang"
    And its iteration count is changed to -1
    When I decrypt it with password "richtig-lang"
    Then it is rejected as an unsupported backup format

  Scenario: A backup with an empty salt is rejected
    Given a backup protected with password "richtig-lang"
    And its salt is emptied
    When I decrypt it with password "richtig-lang"
    Then it is rejected as an unsupported backup format
