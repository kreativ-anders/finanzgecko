import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../utils/update_assets.dart';

enum UpdateCheckStatus { upToDate, updateAvailable, failed }

/// Result of a manual update check — see [UpdateService.checkForUpdate].
/// [failed] deliberately carries no error detail: the UI only ever shows a
/// generic "try again later" note (offline, rate-limited, GitHub down, repo
/// not yet public — none of that is actionable for the user).
///
/// [assets] maps release asset names to their download URLs, so the same
/// response can feed [UpdateService.downloadAndVerify] without a second
/// request. Empty when the release lists no assets — the UI then falls back to
/// opening the download page.
class UpdateCheckResult {
  const UpdateCheckResult._(this.status, {this.latestVersion, this.assets = const {}});

  const UpdateCheckResult.upToDate() : this._(UpdateCheckStatus.upToDate);

  const UpdateCheckResult.updateAvailable({required String latestVersion, Map<String, String> assets = const {}})
    : this._(UpdateCheckStatus.updateAvailable, latestVersion: latestVersion, assets: assets);

  const UpdateCheckResult.failed() : this._(UpdateCheckStatus.failed);

  final UpdateCheckStatus status;
  final String? latestVersion;
  final Map<String, String> assets;
}

/// Outcome of [UpdateService.downloadAndVerify].
///
/// [unavailable] and [failed] are deliberately separate: "this release has no
/// file for your system" is a permanent, explainable situation (a platform
/// build failed, or the release predates the checksums), while [failed] is the
/// usual transient network trouble. The UI says different things for each, and
/// both end up offering the download page.
enum UpdateDownloadStatus { verified, checksumMismatch, unavailable, failed }

class UpdateDownloadResult {
  const UpdateDownloadResult._(this.status, {this.filePath});

  const UpdateDownloadResult.verified({required String filePath})
    : this._(UpdateDownloadStatus.verified, filePath: filePath);

  const UpdateDownloadResult.checksumMismatch() : this._(UpdateDownloadStatus.checksumMismatch);

  const UpdateDownloadResult.unavailable() : this._(UpdateDownloadStatus.unavailable);

  const UpdateDownloadResult.failed() : this._(UpdateDownloadStatus.failed);

  final UpdateDownloadStatus status;

  /// Only set for [UpdateDownloadStatus.verified] — a file is never written
  /// before its checksum matched.
  final String? filePath;
}

/// Manual "check for updates" against the project's public GitHub Releases.
///
/// Still **no** silent or automatic updater: every network call here happens
/// because the user clicked, never on launch and never periodically (see
/// AI_MASTER.md §6). What the user gets after confirming is a *download*, not
/// an install: the file is fetched, checked against the release's published
/// `SHA256SUMS`, and only then saved where they chose. The app never replaces
/// itself and never executes the downloaded file on its own.
class UpdateService {
  UpdateService({http.Client? client, Set<String>? allowedAssetHosts})
    : _client = client ?? http.Client(),
      _allowedAssetHosts = allowedAssetHosts ?? _githubAssetHosts;

  final http.Client _client;

  /// Overridable only so tests can point at a fake host. Production always
  /// takes the default.
  final Set<String> _allowedAssetHosts;
  static const _apiBase = 'https://api.github.com/repos/kreativ-anders/finanzgecko';
  static const _requestTimeout = Duration(seconds: 8);

  /// Gap between two chunks, not a budget for the whole transfer — a 20 MB
  /// download over a slow line is fine, a stalled socket is not.
  static const _stallTimeout = Duration(seconds: 30);

  /// Ceiling for a downloaded release asset. The whole file is held in memory
  /// to hash it before anything touches disk, so an unbounded response is an
  /// out-of-memory crash waiting for a bad day. Releases are ~20 MB; 200 MB is
  /// far above anything this project ships and far below anything that hurts.
  static const int _maxAssetBytes = 200 * 1024 * 1024;

  /// Hosts a release asset may legitimately come from. The URLs handed to
  /// [downloadAndVerify] arrive inside the GitHub API response — trusted, but
  /// trusted is not validated, and this is the one place where a value from
  /// the network decides what the app connects to and writes to disk.
  static const Set<String> _githubAssetHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  Uri? _safeAssetUri(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || !_allowedAssetHosts.contains(uri.host)) return null;
    return uri;
  }

  /// Releases the underlying connection pool. Only meaningful for the default
  /// client — an injected one belongs to whoever injected it.
  void dispose() => _client.close();

  /// Never throws — any failure (offline, repo not public yet, malformed
  /// response, rate limiting) collapses to [UpdateCheckResult.failed] so the
  /// UI can show a single "try again later" note instead of an error dialog.
  Future<UpdateCheckResult> checkForUpdate({required String currentVersion}) async {
    try {
      final res = await _client
          .get(Uri.parse('$_apiBase/releases/latest'), headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(_requestTimeout);
      if (res.statusCode != 200) return const UpdateCheckResult.failed();

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tagName = data['tag_name'];
      if (tagName is! String) return const UpdateCheckResult.failed();

      final latest = _parseVersion(tagName);
      final current = _parseVersion(currentVersion);
      if (latest == null || current == null) return const UpdateCheckResult.failed();

      if (_compareVersions(latest, current) > 0) {
        return UpdateCheckResult.updateAvailable(latestVersion: tagName, assets: _parseAssets(data['assets']));
      }
      return const UpdateCheckResult.upToDate();
    } catch (_) {
      return const UpdateCheckResult.failed();
    }
  }

  /// Downloads [assetName] from [assets], verifies it against the release's
  /// `SHA256SUMS`, and only then writes it to [targetPath].
  ///
  /// Never throws — like [checkForUpdate], every failure collapses into a
  /// status the UI can phrase in one sentence.
  ///
  /// The order matters: the whole file is held in memory and hashed BEFORE
  /// anything touches [targetPath], so a corrupted or mismatching download
  /// never lands in the user's folder looking installable. ~20 MB in memory is
  /// an acceptable price for that.
  ///
  /// Note what this does and does not prove: `SHA256SUMS` is fetched over
  /// HTTPS but is not signed, so a matching digest shows the file arrived
  /// intact and belongs to that release — it is not proof of authorship.
  /// On macOS that guarantee comes from the notarised signature the OS checks
  /// at launch anyway.
  Future<UpdateDownloadResult> downloadAndVerify({
    required Map<String, String> assets,
    required String assetName,
    required String targetPath,
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      // Older releases predate the checksums file; without it we do not offer
      // an unverified download at all. A URL that is not an https GitHub
      // release host is treated the same way — unavailable, not attempted.
      final assetUri = _safeAssetUri(assets[assetName]);
      final checksumsUri = _safeAssetUri(assets[checksumsAssetName]);
      if (assetUri == null || checksumsUri == null) return const UpdateDownloadResult.unavailable();

      final sums = await _client.get(checksumsUri).timeout(_requestTimeout);
      if (sums.statusCode != 200) return const UpdateDownloadResult.failed();
      final expected = parseChecksums(sums.body)[assetName];
      if (expected == null) return const UpdateDownloadResult.unavailable();

      final response = await _client.send(http.Request('GET', assetUri)).timeout(_requestTimeout);
      if (response.statusCode != 200) return const UpdateDownloadResult.failed();

      final total = response.contentLength;
      if (total != null && total > _maxAssetBytes) return const UpdateDownloadResult.failed();

      // BytesBuilder rather than a growing List<int>: same result, far less
      // allocation churn on a ~20 MB stream. `copy: false` is safe because the
      // chunks handed over by the HTTP stream are not reused afterwards.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        builder.add(chunk);
        // A missing or lying Content-Length must not become unbounded memory.
        if (builder.length > _maxAssetBytes) return const UpdateDownloadResult.failed();
        onProgress?.call(builder.length, total);
      }
      final bytes = builder.takeBytes();

      final digest = hexEncode((await Sha256().hash(bytes)).bytes);
      if (!digestMatches(expected, digest)) return const UpdateDownloadResult.checksumMismatch();

      await File(targetPath).writeAsBytes(bytes, flush: true);
      return UpdateDownloadResult.verified(filePath: targetPath);
    } catch (_) {
      return const UpdateDownloadResult.failed();
    }
  }
}

/// Pulls `name` → `browser_download_url` out of the releases API payload.
/// Anything unexpected yields an empty map rather than an exception: a release
/// without usable assets is a fallback-to-website case, not an error.
Map<String, String> _parseAssets(Object? raw) {
  if (raw is! List) return const {};
  final result = <String, String>{};
  for (final entry in raw) {
    if (entry is! Map) continue;
    final name = entry['name'];
    final url = entry['browser_download_url'];
    if (name is String && url is String) result[name] = url;
  }
  return result;
}

/// Parses "v1.3.3", "1.3.3" or "1.3.3+9" into `[major, minor, patch]`. Build
/// metadata after "+" is ignored (not part of release ordering). Returns null
/// for anything that doesn't look like semver, rather than throwing.
List<int>? _parseVersion(String raw) {
  final withoutBuild = raw.trim().replaceFirst(RegExp('^v', caseSensitive: false), '').split('+').first;
  final parts = withoutBuild.split('.');
  if (parts.length != 3) return null;
  final nums = [for (final p in parts) int.tryParse(p)];
  if (nums.contains(null)) return null;
  return nums.cast<int>();
}

/// Positive if [a] is newer than [b], negative if older, 0 if equal.
int _compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final diff = a[i] - b[i];
    if (diff != 0) return diff;
  }
  return 0;
}
