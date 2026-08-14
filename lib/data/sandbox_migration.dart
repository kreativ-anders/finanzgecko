import 'dart:io';

import 'package:path/path.dart' as p;

/// One-time move of the data files from the pre-sandbox location into the
/// App-Sandbox container.
///
/// ## Why this exists
///
/// Enabling `com.apple.security.app-sandbox` virtualises `$HOME`: what used to
/// be `/Users/x` becomes `/Users/x/Library/Containers/de.finanzgecko.app/Data`.
/// `AppStore.resolveDataDirectory()` is unchanged and still correct — it simply
/// resolves under a different root. The consequence is that an existing
/// installation's `finanzgecko-data.json` is suddenly *outside* what the app
/// can see, and the app would start with an empty database. Not because the
/// data was lost, but because the sandbox is doing exactly its job.
///
/// ## The two rules this code follows
///
/// 1. **It copies, it never moves and never deletes.** The pre-sandbox file
///    stays where it is, untouched. It costs ~45 KB and it is the only fallback
///    that works when everything else here fails.
/// 2. **It never overwrites.** If the container already holds a data file, this
///    is a no-op — a second run, a downgrade-then-upgrade, or a user who
///    already imported a backup must not be trampled.
///
/// ## THIS IS TEMPORARY — planned removal
///
/// Deliberate technical debt with a defined end, not a permanent feature.
/// Introduced in **v1.8** (2026-08). It is dead weight for everyone who
/// installs v1.8 or later fresh, and every release makes it deader.
///
/// **Remove the whole file, its test, the `run()` call in `AppStore`, and the
/// `temporary-exception.files.home-relative-path.read-write` entitlement in
/// `Release.entitlements`/`DebugProfile.entitlements` — together, in one
/// commit — once both hold:**
///
///  - at least a year has passed (ROADMAP schedules this for **Q3 2027**), and
///  - no support request has mentioned pre-sandbox data for several releases.
///
/// Removing the entitlement is the actual prize: it is the only thing letting
/// this app read anything outside its container, so dropping it strictly
/// shrinks what the sandbox permits.
///
/// **Deleting the old files is a separate, later step and must not be folded
/// into the release that first copies them** — a copy that turns out subtly
/// wrong is only recoverable while the original still exists. When that step
/// comes, prefer telling the user where the leftovers are over deleting
/// unasked; the directory also holds their `pre-import-*` / `pre-reset-*`
/// safety backups, which this migration intentionally does not copy.
///
/// ## What this deliberately does NOT do
///
/// It does not touch the encryption key. Keychain item ACLs are bound to the
/// app's code signing identity, and sandboxing does not change that identity —
/// same Developer ID, same bundle ID, so the existing legacy-keychain item is
/// expected to remain readable. If that expectation turns out to be wrong the
/// copied file cannot be decrypted, and the correct outcome is the loud,
/// explicit failure `AppStore` already raises for an unreadable key, followed
/// by the user importing a backup — NOT a silent empty start. Verify this on a
/// real signed build before shipping; it is the one assumption here that
/// cannot be tested in CI (see AI_MASTER §4.1).
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
