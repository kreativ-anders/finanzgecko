import 'dart:io';

import 'package:path/path.dart' as p;

/// One-time copy of the pre-sandbox data files into the App-Sandbox container.
///
/// WARNING: it copies and never overwrites — the original is the only fallback, and a filled container wins.
/// INFO: files only, never the key — a sandboxed build reads the legacy keychain entry unchanged (2026-08-13).
/// TODO: remove this file, its test, the `AppStore` call and the temporary-exception entitlement, from Q3 2027.
/// INFO: rationale and removal conditions in dev/ai/persistence.md and ROADMAP "Q3 2027".
class SandboxMigration {
  const SandboxMigration._();

  /// Breadcrumb dropped next to the copied data, for support questions.
  static const String breadcrumbFilename = 'migrated-from-unsandboxed.txt';

  /// Recovers the real home directory from a sandboxed `$HOME`.
  ///
  /// INFO: every home-reporting API returns the container under the sandbox, so the real home is read back off it.
  /// INFO: `null` means [home] is not a container path — the normal, unsandboxed case, and no migration applies.
  static String? realHomeFromContainerHome(String home, String bundleId) {
    final suffix = p.join('Library', 'Containers', bundleId, 'Data');
    final normalised = home.endsWith(p.separator) ? home.substring(0, home.length - 1) : home;
    if (!normalised.endsWith(suffix)) return null;
    final root = normalised.substring(0, normalised.length - suffix.length);
    if (root.isEmpty) return null;
    // Strip the separator that joined the two halves.
    return root.endsWith(p.separator) ? root.substring(0, root.length - 1) : root;
  }

  /// The pre-sandbox data directory, or `null` when the process is not running sandboxed.
  static String? legacyDataDirectory({
    required String home,
    required String bundleId,
    required String legacyDirectoryName,
  }) {
    final realHome = realHomeFromContainerHome(home, bundleId);
    if (realHome == null) return null;
    return p.join(realHome, 'Library', 'Application Support', legacyDirectoryName);
  }

  /// Copies [filenames] into [targetDirectory], if and only if the target holds none of them yet.
  ///
  /// WARNING: without the home-relative-path temporary-exception entitlement every read below reports `failed`.
  static Future<SandboxMigrationOutcome> run({
    required Directory targetDirectory,
    required String home,
    required String bundleId,
    required String legacyDirectoryName,
    required List<String> filenames,
  }) async {
    if (!Platform.isMacOS) return SandboxMigrationOutcome.notApplicable;

    final legacyPath = legacyDataDirectory(home: home, bundleId: bundleId, legacyDirectoryName: legacyDirectoryName);
    if (legacyPath == null) return SandboxMigrationOutcome.notApplicable;

    for (final name in filenames) {
      if (await File(p.join(targetDirectory.path, name)).exists()) {
        return SandboxMigrationOutcome.targetNotEmpty;
      }
    }

    final legacyDir = Directory(legacyPath);
    try {
      if (!await legacyDir.exists()) return SandboxMigrationOutcome.nothingToMigrate;
    } catch (_) {
      // Denied rather than absent: reporting a fresh install here would hide the difference in the log.
      return SandboxMigrationOutcome.failed;
    }

    var copiedAny = false;
    try {
      for (final name in filenames) {
        final source = File(p.join(legacyPath, name));
        if (!await source.exists()) continue;
        // copy(), not rename(): a cross-volume rename fails, and the original must stay put.
        await source.copy(p.join(targetDirectory.path, name));
        copiedAny = true;
      }
    } catch (_) {
      return SandboxMigrationOutcome.failed;
    }

    if (!copiedAny) return SandboxMigrationOutcome.nothingToMigrate;

    try {
      await File(p.join(targetDirectory.path, breadcrumbFilename)).writeAsString(
        'Diese Daten wurden einmalig aus dem früheren Speicherort übernommen:\n'
        '$legacyPath\n\n'
        'Die Dateien dort wurden NICHT gelöscht und dienen weiterhin als Rückfalloption.\n',
      );
    } catch (_) {
      // A missing breadcrumb is cosmetic; the copy above is what matters.
    }

    return SandboxMigrationOutcome.migrated;
  }
}

/// Outcome of [SandboxMigration.run]; "nothing to do" and "could not do it" look alike to the user.
enum SandboxMigrationOutcome {
  /// Not macOS, or not running sandboxed — the overwhelmingly common case.
  notApplicable,

  /// Sandboxed, but the container already holds data. No-op.
  targetNotEmpty,

  /// Sandboxed, container empty, and no pre-sandbox data either: a genuinely fresh install.
  nothingToMigrate,

  /// Data was copied into the container.
  migrated,

  /// Pre-sandbox data exists but could not be read or copied — usually a mis-scoped entitlement.
  failed,
}
