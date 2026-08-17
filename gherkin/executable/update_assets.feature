# Source: lib/utils/update_assets.dart
# Implementation: lib/utils/update_assets.dart
# Executable: test/bdd/update_assets_bdd_test.dart (Runner: test/support/gherkin_runner.dart)
@executable @settings
Feature: Pick the update file per platform and check it against the checksum

  # The manual update check (see gherkin/settings.feature) downloads, after confirmation, exactly the
  # file that belongs to the running operating system, and compares it against the SHA256SUMS file
  # published in the release. Both are pure logic and pinned down here without network and without a
  # filesystem. The suffixes match release.yml and docs/download.html.
  #
  # Free-text descriptions are deliberately comments here: the runner
  # (test/support/gherkin_runner.dart) only accepts comments, tags, and steps
  # under "Feature:" and throws on anything else.

  Scenario: macOS gets the disk image
    When I pick the asset for "macos" from "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage"
    Then the chosen asset is "FinanzGecko-1.7.0-mac.dmg"

  Scenario: Windows gets the installer
    When I pick the asset for "windows" from "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage"
    Then the chosen asset is "FinanzGecko-1.7.0-Setup.exe"

  Scenario: Linux gets the AppImage
    When I pick the asset for "linux" from "FinanzGecko-1.7.0-Setup.exe, FinanzGecko-1.7.0-mac.dmg, FinanzGecko-1.7.0-x86_64.AppImage"
    Then the chosen asset is "FinanzGecko-1.7.0-x86_64.AppImage"

  # The SHA256SUMS file sits in the same release and must never be offered as an update.
  Scenario: The checksums file is never picked as an update
    When I pick the asset for "macos" from "SHA256SUMS, FinanzGecko-1.7.0-mac.dmg"
    Then the chosen asset is "FinanzGecko-1.7.0-mac.dmg"

  # No guessing: better no download at all and the fallback to the download page.
  Scenario: If the platform's asset is missing, none is picked
    When I pick the asset for "windows" from "FinanzGecko-1.7.0-mac.dmg, SHA256SUMS"
    Then no asset is picked

  Scenario: An unknown platform picks no asset
    When I pick the asset for "fuchsia" from "FinanzGecko-1.7.0-mac.dmg"
    Then no asset is picked

  Scenario: A checksums file gets split into file name and hash
    When I parse the checksums "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111  FinanzGecko-1.7.0-mac.dmg"
    Then the hash for "FinanzGecko-1.7.0-mac.dmg" equals "aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"

  # The asterisk marks binary mode in sha256sum and isn't part of the name.
  Scenario: The binary-mode marker isn't part of the file name
    When I parse the checksums "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222 *FinanzGecko-1.7.0-Setup.exe"
    Then the hash for "FinanzGecko-1.7.0-Setup.exe" equals "bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"

  Scenario: Unusable lines get skipped instead of failing
    When I parse the checksums "### Kommentar\nzu kurz  x.dmg\ncccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333  FinanzGecko-1.7.0-mac.dmg"
    Then the result contains exactly 1 entry
    And the hash for "FinanzGecko-1.7.0-mac.dmg" equals "cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333"

  Scenario: An unknown file name yields no hash
    When I parse the checksums "dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444  FinanzGecko-1.7.0-mac.dmg"
    Then there is no hash for "FinanzGecko-1.7.0-Setup.exe"

  # Bytes below 0x10 must stay two digits, otherwise the digest is too short and every comparison fails.
  Scenario: Small byte values keep the leading zero
    When I hex-encode the bytes "0, 1, 15, 16, 255"
    Then the hex representation is "00010f10ff"

  Scenario: Case doesn't matter for the digest
    When I compare digest "ABCDEF1234" with "abcdef1234"
    Then the digests match

  Scenario: A differing digest is detected
    When I compare digest "abcdef1234" with "abcdef1235"
    Then the digests do not match
