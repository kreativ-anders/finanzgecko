import 'dart:io';

/// Pure, UI- and network-free logic around a release's update files: which
/// release asset belongs to this platform, and does a downloaded file match
/// the published checksum.
///
/// Deliberately without network and file access so that both stay testable
/// without a running OS — the scenarios live in
/// `gherkin/executable/update_assets.feature`.

/// File-name suffix of the release asset per platform.
///
/// **Coupled in three places** — the same suffixes appear in the artifact
/// names in `.github/workflows/release.yml` and as `data-asset-suffix` in
/// `docs/download.html`. If a file name changes there, all three have to be
/// updated together; otherwise the update flow no longer finds the asset and
/// silently falls back to the download page.
String? updateAssetSuffixFor(String operatingSystem) => switch (operatingSystem) {
  'macos' => '-mac.dmg',
  'windows' => '-Setup.exe',
  'linux' => '-x86_64.AppImage',
  _ => null,
};

/// Suffix for the currently running platform (null wherever no release
/// artifact exists).
String? get currentUpdateAssetSuffix => updateAssetSuffixFor(Platform.operatingSystem);

/// Picks the asset matching this platform from a release's asset names.
///
/// Null if none matches — e.g. because a platform build failed or the platform
/// is unknown. The caller then opens the download page instead of guessing a
/// wrong file.
String? selectAssetName(Iterable<String> assetNames, String operatingSystem) {
  final suffix = updateAssetSuffixFor(operatingSystem);
  if (suffix == null) return null;
  for (final name in assetNames) {
    if (name.endsWith(suffix)) return name;
  }
  return null;
}

/// Parses a `SHA256SUMS` file in `sha256sum`'s standard format
/// (`<64 hex chars><whitespace>[*]<file name>`, one line per file) into
/// file name → lower-case hash.
///
/// Non-matching lines are skipped rather than thrown on: the file comes from a
/// release, not from user input, and a single foreign entry must not prevent
/// the remaining files from being verified.
Map<String, String> parseChecksums(String content) {
  final result = <String, String>{};
  // split('\n') instead of LineSplitter: a leftover \r is dropped by the
  // line's trim() anyway, which saves the dart:convert import.
  for (final line in content.split('\n')) {
    final match = _checksumLine.firstMatch(line.trim());
    if (match == null) continue;
    result[match.group(2)!.trim()] = match.group(1)!.toLowerCase();
  }
  return result;
}

/// A `*` before the file name marks binary mode in `sha256sum` and is not part
/// of the name.
final RegExp _checksumLine = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');

/// Name of the checksum file the `release` job attaches to every release.
const String checksumsAssetName = 'SHA256SUMS';

/// Converts a hash into its hex representation.
///
/// `padLeft(2, '0')` is the crucial part here: without it every byte below
/// 0x10 would be emitted as a single digit, the digest would be too short and
/// EVERY comparison would fail — a bug that would only surface for certain
/// files and therefore slips through easily. Hence specified separately below.
String hexEncode(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Compares two hex digests case-insensitively.
///
/// Deliberately NOT a constant-time comparison: a public checksum is held
/// against one just computed locally: there is no secret whose timing could
/// leak anything.
bool digestMatches(String expected, String actual) => expected.trim().toLowerCase() == actual.trim().toLowerCase();
