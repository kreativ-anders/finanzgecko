// Gherkin: gherkin/data_security.feature
import 'dart:io';

import 'package:finanzgecko/data/sandbox_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Covers the one-time pre-sandbox migration. The path arithmetic is pure and
/// tested directly; the copy behaviour runs against real temp directories,
/// because the two rules that matter ("never overwrite", "never delete the
/// original") are statements about the filesystem, and asserting them against
/// a mock would prove nothing.
void main() {
  const bundleId = 'de.finanzgecko.app';
  const dataFile = 'finanzgecko-data.json';
  const ratesFile = 'finanzgecko-rates.json';

  group('realHomeFromContainerHome', () {
    test('recovers the real home from a container path', () {
      expect(
        SandboxMigration.realHomeFromContainerHome(
          '/Users/manuel/Library/Containers/de.finanzgecko.app/Data',
          bundleId,
        ),
        '/Users/manuel',
      );
    });

    test('tolerates a trailing separator', () {
      expect(
        SandboxMigration.realHomeFromContainerHome(
          '/Users/manuel/Library/Containers/de.finanzgecko.app/Data/',
          bundleId,
        ),
        '/Users/manuel',
      );
    });

    // The unsandboxed case. Returning null here is what makes the whole
    // migration a no-op for every non-macOS and every pre-sandbox build.
    test('returns null for a plain home directory', () {
      expect(SandboxMigration.realHomeFromContainerHome('/Users/manuel', bundleId), isNull);
    });

    test('returns null for a different app\'s container', () {
      expect(
        SandboxMigration.realHomeFromContainerHome('/Users/manuel/Library/Containers/com.example.other/Data', bundleId),
        isNull,
      );
    });
  });

  group('legacyDataDirectory', () {
    test('points at the pre-sandbox location', () {
      expect(
        SandboxMigration.legacyDataDirectory(
          home: '/Users/manuel/Library/Containers/de.finanzgecko.app/Data',
          bundleId: bundleId,
          legacyDirectoryName: bundleId,
        ),
        '/Users/manuel/Library/Application Support/de.finanzgecko.app',
      );
    });

    test('is null when not sandboxed', () {
      expect(
        SandboxMigration.legacyDataDirectory(home: '/Users/manuel', bundleId: bundleId, legacyDirectoryName: bundleId),
        isNull,
      );
    });
  });

  group('run', () {
    late Directory root;
    late Directory legacyDir;
    late Directory container;
    late String fakeHome;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fg-sandbox-migration');
      // Source: the pre-sandbox directory, named after the application id.
      legacyDir = Directory(p.join(root.path, 'Library', 'Application Support', bundleId));
      // Target: inside the container AND under the new macOS directory name.
      // The two names differing is the case that matters — the rename away from
      // the ".app" suffix rides along on this same copy.
      container = Directory(p.join(root.path, 'Library', 'Containers', bundleId, 'Data'));
      fakeHome = container.path;
      await legacyDir.create(recursive: true);
      await container.create(recursive: true);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<SandboxMigrationOutcome> run() => SandboxMigration.run(
      targetDirectory: container,
      home: fakeHome,
      bundleId: bundleId,
      legacyDirectoryName: bundleId,
      filenames: const [dataFile, ratesFile],
    );

    test('copies pre-sandbox data into the container', () async {
      await File(p.join(legacyDir.path, dataFile)).writeAsString('{"envelope":1}');
      await File(p.join(legacyDir.path, ratesFile)).writeAsString('{"EUR":1}');

      expect(await run(), SandboxMigrationOutcome.migrated);
      expect(await File(p.join(container.path, dataFile)).readAsString(), '{"envelope":1}');
      expect(await File(p.join(container.path, ratesFile)).readAsString(), '{"EUR":1}');
    });

    // Rule 1. This is the assertion that makes the change recoverable: if the
    // copy is ever subtly wrong, the user still has the original.
    test('leaves the original files untouched', () async {
      await File(p.join(legacyDir.path, dataFile)).writeAsString('{"envelope":1}');

      await run();

      expect(await File(p.join(legacyDir.path, dataFile)).exists(), isTrue);
      expect(await File(p.join(legacyDir.path, dataFile)).readAsString(), '{"envelope":1}');
    });

    // Rule 2. Covers the second launch, and the user who already restored a
    // backup into the container before the migration ever ran.
    test('never overwrites data already in the container', () async {
      await File(p.join(legacyDir.path, dataFile)).writeAsString('{"old":true}');
      await File(p.join(container.path, dataFile)).writeAsString('{"newer":true}');

      expect(await run(), SandboxMigrationOutcome.targetNotEmpty);
      expect(await File(p.join(container.path, dataFile)).readAsString(), '{"newer":true}');
    });

    test('reports a genuinely fresh install as nothing to migrate', () async {
      expect(await run(), SandboxMigrationOutcome.nothingToMigrate);
    });

    test('leaves a breadcrumb naming the old location', () async {
      await File(p.join(legacyDir.path, dataFile)).writeAsString('{}');

      await run();

      final note = File(p.join(container.path, SandboxMigration.breadcrumbFilename));
      expect(await note.exists(), isTrue);
      expect(await note.readAsString(), contains(legacyDir.path));
    });

    test('is a no-op when the home directory is not a container', () async {
      await File(p.join(legacyDir.path, dataFile)).writeAsString('{}');

      final outcome = await SandboxMigration.run(
        targetDirectory: container,
        home: root.path,
        bundleId: bundleId,
        legacyDirectoryName: bundleId,
        filenames: const [dataFile, ratesFile],
      );

      expect(outcome, SandboxMigrationOutcome.notApplicable);
      expect(await File(p.join(container.path, dataFile)).exists(), isFalse);
    });
  }, skip: !Platform.isMacOS ? 'SandboxMigration.run is macOS-only by design' : null);
}
