import 'dart:io';

// INFO: pure and IO-free by design, so it stays testable — scenarios in gherkin/executable/update_assets.feature.

// WARNING: the same suffixes live in release.yml and docs/download.html (data-asset-suffix) — a rename breaks both.
/// File-name suffix of the release asset per platform.
String? updateAssetSuffixFor(String operatingSystem) => switch (operatingSystem) {
  'macos' => '-mac.dmg',
  'windows' => '-Setup.exe',
  'linux' => '-x86_64.AppImage',
  _ => null,
};

/// Suffix for the currently running platform, null where no release artifact exists.
String? get currentUpdateAssetSuffix => updateAssetSuffixFor(Platform.operatingSystem);

/// Picks the asset matching this platform from a release's asset names, null if none matches.
String? selectAssetName(Iterable<String> assetNames, String operatingSystem) {
  final suffix = updateAssetSuffixFor(operatingSystem);
  if (suffix == null) return null;
  for (final name in assetNames) {
    if (name.endsWith(suffix)) return name;
  }
  return null;
}

/// Parses a `SHA256SUMS` file into file name → lower-case hash.
// INFO: non-matching lines are skipped, so one foreign entry cannot block verification of the rest.
Map<String, String> parseChecksums(String content) {
  final result = <String, String>{};
  // split('\n') keeps the dart:convert import out; a leftover \r is dropped by the line's trim().
  for (final line in content.split('\n')) {
    final match = _checksumLine.firstMatch(line.trim());
    if (match == null) continue;
    result[match.group(2)!.trim()] = match.group(1)!.toLowerCase();
  }
  return result;
}

// A `*` before the file name marks sha256sum's binary mode and is not part of the name.
final RegExp _checksumLine = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');

/// Name of the checksum file the `release` job attaches to every release.
const String checksumsAssetName = 'SHA256SUMS';

/// Converts a hash into its hex representation.
// WARNING: without padLeft(2, '0') bytes below 0x10 emit one digit and every digest comparison fails.
String hexEncode(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Compares two hex digests case-insensitively.
// INFO: deliberately not constant-time — both digests are public, so no secret's timing can leak.
bool digestMatches(String expected, String actual) => expected.trim().toLowerCase() == actual.trim().toLowerCase();
