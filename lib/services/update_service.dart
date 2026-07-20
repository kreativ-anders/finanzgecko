import 'dart:convert';

import 'package:http/http.dart' as http;

enum UpdateCheckStatus { upToDate, updateAvailable, failed }

/// Result of a manual update check — see [UpdateService.checkForUpdate].
/// [failed] deliberately carries no error detail: the UI only ever shows a
/// generic "try again later" note (offline, rate-limited, GitHub down, repo
/// not yet public — none of that is actionable for the user). Deliberately
/// no release URL here: the UI links to the project's own download page
/// (one-click per-OS buttons), not GitHub's raw release/asset listing.
class UpdateCheckResult {
  const UpdateCheckResult._(this.status, {this.latestVersion});

  const UpdateCheckResult.upToDate() : this._(UpdateCheckStatus.upToDate);

  const UpdateCheckResult.updateAvailable({required String latestVersion})
    : this._(UpdateCheckStatus.updateAvailable, latestVersion: latestVersion);

  const UpdateCheckResult.failed() : this._(UpdateCheckStatus.failed);

  final UpdateCheckStatus status;
  final String? latestVersion;
}

/// Manual "check for updates" against the project's public GitHub Releases —
/// deliberately no silent/automatic auto-updater (no code-signing certificate
/// for macOS/Windows to make an in-place binary swap trustworthy, see
/// AI_MASTER.md §6). A user-triggered check only ever reads the latest
/// release tag and links out to the download page; it never downloads or
/// executes anything itself.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _apiBase = 'https://api.github.com/repos/kreativ-anders/finanzgecko';
  static const _requestTimeout = Duration(seconds: 8);

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
        return UpdateCheckResult.updateAvailable(latestVersion: tagName);
      }
      return const UpdateCheckResult.upToDate();
    } catch (_) {
      return const UpdateCheckResult.failed();
    }
  }
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
