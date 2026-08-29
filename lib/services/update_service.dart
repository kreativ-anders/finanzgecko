import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../utils/update_assets.dart';

enum UpdateCheckStatus { upToDate, updateAvailable, failed }

/// Result of a manual update check — see [UpdateService.checkForUpdate].
// INFO: [failed] carries no error detail — no cause (offline, rate limit, GitHub down) is actionable.
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
// INFO: [unavailable] means permanently no file for this platform; [failed] is transient network trouble.
enum UpdateDownloadStatus { verified, checksumMismatch, unavailable, failed }

class UpdateDownloadResult {
  const UpdateDownloadResult._(this.status, {this.filePath});

  const UpdateDownloadResult.verified({required String filePath})
    : this._(UpdateDownloadStatus.verified, filePath: filePath);

  const UpdateDownloadResult.checksumMismatch() : this._(UpdateDownloadStatus.checksumMismatch);

  const UpdateDownloadResult.unavailable() : this._(UpdateDownloadStatus.unavailable);

  const UpdateDownloadResult.failed() : this._(UpdateDownloadStatus.failed);

  final UpdateDownloadStatus status;

  /// Only set for [UpdateDownloadStatus.verified] — a file is never written before its checksum matched.
  final String? filePath;
}

/// Manual "check for updates" against the project's public GitHub Releases.
// INFO: every network call here happens on a user click — no automatic updater, see dev/ai/platform.md.
class UpdateService {
  UpdateService({http.Client? client, Set<String>? allowedAssetHosts})
    : _client = client ?? http.Client(),
      _allowedAssetHosts = allowedAssetHosts ?? _githubAssetHosts;

  final http.Client _client;

  /// Overridable only so tests can point at a fake host; production takes the default.
  final Set<String> _allowedAssetHosts;
  static const _apiBase = 'https://api.github.com/repos/kreativ-anders/finanzgecko';
  static const _requestTimeout = Duration(seconds: 8);

  /// Gap between two chunks, not a budget for the whole transfer.
  static const _stallTimeout = Duration(seconds: 30);

  /// Ceiling for a download held whole in memory before hashing — an unbounded response would be an OOM.
  static const int _maxAssetBytes = 200 * 1024 * 1024;

  /// Hosts a release asset may legitimately come from.
  // WARNING: these URLs arrive from the network; without this check they decide what the app writes to disk.
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

  /// Releases the underlying connection pool; an injected client belongs to whoever injected it.
  void dispose() => _client.close();

  /// Never throws — any failure collapses to [UpdateCheckResult.failed] for one "try again later" note.
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

  /// Downloads [assetName], verifies it against the release's `SHA256SUMS`, then writes it to [targetPath].
  // WARNING: hash first, write second — reordering leaves an unverified file sitting in the user's folder.
  // INFO: `SHA256SUMS` is unsigned, so a match proves integrity, not authorship; see dev/ai/platform.md.
  Future<UpdateDownloadResult> downloadAndVerify({
    required Map<String, String> assets,
    required String assetName,
    required String targetPath,
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      // INFO: missing checksums or a rejected asset URL means unavailable — never an unverified download.
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

      // INFO: `copy: false` is safe — the HTTP stream's chunks are not reused after being handed over.
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

/// Pulls `name` → `browser_download_url` out of the releases API payload; anything odd yields an empty map.
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

/// Parses "v1.3.3", "1.3.3" or "1.3.3+9" into `[major, minor, patch]`; null for anything non-semver.
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
