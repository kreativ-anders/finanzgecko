import 'dart:io';

import 'package:path/path.dart' as p;

/// One-time copy of the pre-sandbox data files into the App-Sandbox container,
/// so an existing installation does not start empty once `$HOME` is virtualised.
///
/// Two invariants, both load-bearing: it **copies** (the original stays put as
/// the only fallback if anything here goes wrong), and it **never overwrites**
/// (a container that already holds data wins — a re-run, a downgrade, or an
/// already-imported backup must not be trampled). It does not touch the
/// encryption key.
///
/// **Temporary by design.** Introduced in v1.8 (2026-08). Removal — this file,
/// its test, the `run()` call in `AppStore`, and the `temporary-exception`
/// entitlement, together in one commit — is scheduled for Q3 2027. Deleting the
/// user's old files is a separate, later step.
///
/// Full rationale, the keychain assumption that cannot be verified in CI, and
/// the removal conditions: dev/ai/persistence.md and ROADMAP "Q3 2027".
class SandboxMigration {
  const SandboxMigration._();

  /// Filename dropped next to the copied data as a breadcrumb for support
  /// questions ("why does my container have data it never wrote?").
  static const String breadcrumbFilename = 'migrated-from-unsandboxed.txt';

  /// Recovers the real home directory from a sandboxed `$HOME`.
  ///
  /// Under the sandbox every API that would normally report the home directory
  /// — `$HOME`, `NSHomeDirectory()`, `getpwuid()` via most wrappers — reports
  /// the container instead. But the container path is built from the real home
  /// by a fixed rule, so the real home can simply be read back off the end of
  /// it. That avoids reaching for FFI to call `getpwuid` for one string.
  ///
  /// Returns `null` when [home] is not a container path, which is the normal
  /// case for an unsandboxed build and the signal that no migration applies.
  static String? realHomeFromContainerHome(String home, String bundleId) {
    final suffix = p.join('Library', 'Containers', bundleId, 'Data');
    final normalised = home.endsWith(p.separator) ? home.substring(0, home.length - 1) : home;
    if (!normalised.endsWith(suffix)) return null;
    final root = normalised.substring(0, normalised.length - suffix.length);
    if (root.isEmpty) return null;
    // Strip the separator that joined the two halves.
    return root.endsWith(p.separator) ? root.substring(0, root.length - 1) : root;
  }

  /// The pre-sandbox data directory for this installation, or `null` when the
  /// process is not running sandboxed (and therefore has nothing to migrate).
  static String? legacyDataDirectory({
    required String home,
    required String bundleId,
    required String legacyDirectoryName,
  }) {
    final realHome = realHomeFromContainerHome(home, bundleId);
    if (realHome == null) return null;
    return p.join(realHome, 'Library', 'Application Support', legacyDirectoryName);
  }

  /// Copies [filenames] from the pre-sandbox directory into [targetDirectory],
  /// if and only if the target holds none of them yet.
  ///
  /// Reading the source requires the entitlement
  /// `com.apple.security.temporary-exception.files.home-relative-path.read-write`
  /// scoped to `/Library/Application Support/de.finanzgecko.app/`. Without it
  /// every read below throws a permission error, which is caught and reported
  /// as [SandboxMigrationOutcome.failed] rather than crashing the startup path.
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

    // Rule 2: anything already present in the container wins.
    for (final name in filenames) {
      if (await File(p.join(targetDirectory.path, name)).exists()) {
        return SandboxMigrationOutcome.targetNotEmpty;
      }
    }

    final legacyDir = Directory(legacyPath);
    try {
      if (!await legacyDir.exists()) return SandboxMigrationOutcome.nothingToMigrate;
    } catch (_) {
      // Denied rather than absent — treat as a failure, not as "fresh install",
      // so the difference stays visible in the log instead of looking normal.
      return SandboxMigrationOutcome.failed;
    }

    var copiedAny = false;
    try {
      for (final name in filenames) {
        final source = File(p.join(legacyPath, name));
        if (!await source.exists()) continue;
        // copy(), not rename(): rename across the container boundary would
        // both fail on a different volume and violate rule 1.
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

/// Outcome of [SandboxMigration.run] — deliberately distinguishes "nothing to
/// do" from "could not do it", because those look identical to the user (an
/// empty app) but mean opposite things to whoever is debugging it.
enum SandboxMigrationOutcome {
  /// Not macOS, or not running sandboxed — the overwhelmingly common case.
  notApplicable,

  /// Sandboxed, but the container already holds data. No-op.
  targetNotEmpty,

  /// Sandboxed, container empty, and no pre-sandbox data exists either: a
  /// genuinely fresh install.
  nothingToMigrate,

  /// Data was copied into the container.
  migrated,

  /// Pre-sandbox data appears to exist but could not be read or copied —
  /// almost always a missing/mis-scoped temporary-exception entitlement.
  failed,
}
