import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hardwires the Gherkin spec into the test pipeline: `flutter test` FAILS if
/// the features drift from the code or the tests. This runs in the same
/// pipeline as everything else (incl. the release `test`-gate), so the
/// `gherkin/` folder can no longer live an isolated life next to the code.
///
/// Three invariants:
///  1. Every `gherkin/*.feature` has a `# Quelle:` header and every source path
///     it names still exists — a feature can't reference dead code.
///  2. Every test that declares coverage does so with a marker of the form
///     `// [G]herkin: gherkin/<x>.feature` that points to a real feature file —
///     test→feature links can't rot.
///  3. Exactly the features on [featuresWithoutUnitTest] have no covering test.
///     A newly uncovered feature, or a now-covered one, fails here and forces
///     either a test (with the marker) or a conscious edit of this allow-list.
void main() {
  // Features that are intentionally UI-/integration-only for now (no unit
  // test). Adding coverage for one — or adding a new untested feature — must
  // update this set, on purpose.
  const featuresWithoutUnitTest = {
    'gherkin/currency_exchange.feature',
    'gherkin/window_and_navigation.feature',
  };

  // Built at runtime so this test can never self-match its own doc comment.
  final marker = RegExp('//\\s*${'Gherkin'}:\\s*(.+)');

  String basename(String path) => path.split(RegExp(r'[\\/]')).last;

  String posix(String path) => path.replaceAll('\\', '/');

  // Recursive: also catches executable specs in gherkin/executable/.
  final featureFiles = Directory('gherkin')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.feature'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final featurePaths = {for (final f in featureFiles) posix(f.path)};

  // Recursive: also catches BDD tests in test/bdd/.
  final testFiles = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart') && basename(f.path) != 'gherkin_sync_test.dart')
      .toList();

  // feature-path -> test files that claim to cover it; plus a flat list of all
  // (test, ref) pairs for the "points to a real feature" check.
  final coverage = <String, Set<String>>{};
  final annotationRefs = <(String, String)>[];
  for (final t in testFiles) {
    for (final line in t.readAsLinesSync()) {
      final m = marker.firstMatch(line);
      if (m == null) continue;
      for (final ref in m.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        annotationRefs.add((basename(t.path), ref));
        coverage.putIfAbsent(ref, () => <String>{}).add(basename(t.path));
      }
    }
  }

  test('es gibt Feature-Dateien', () {
    expect(featureFiles, isNotEmpty);
  });

  group('1) "# Quelle:" verweist nur auf existierenden Code', () {
    for (final f in featureFiles) {
      test(basename(f.path), () {
        final header = f.readAsLinesSync().firstWhere(
          (l) => l.trimLeft().startsWith('# Quelle:'),
          orElse: () => '',
        );
        expect(header, isNotEmpty, reason: '${basename(f.path)} braucht einen "# Quelle:"-Header.');
        final paths = header
            .replaceFirst(RegExp(r'^\s*#\s*Quelle:\s*'), '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final path in paths) {
          expect(File(path).existsSync(), isTrue, reason: '$path (aus ${basename(f.path)}) existiert nicht mehr.');
        }
      });
    }
  });

  test('2) jede Test→Feature-Verlinkung zeigt auf eine existierende Feature-Datei', () {
    for (final (testFile, ref) in annotationRefs) {
      expect(featurePaths, contains(ref), reason: '$testFile verlinkt unbekanntes Feature "$ref".');
    }
  });

  test('3) genau die erlaubten Features sind ohne Unit-Test', () {
    final uncovered = featurePaths.difference(coverage.keys.toSet());
    expect(
      uncovered,
      featuresWithoutUnitTest,
      reason:
          'Abweichung. Features ohne Test = $uncovered.\n'
          'Entweder einen Test mit der Zeile "// ' 'Gherkin: <feature>" ergänzen '
          'oder featuresWithoutUnitTest in diesem Test bewusst anpassen.',
    );
    expect(
      featuresWithoutUnitTest.difference(featurePaths),
      isEmpty,
      reason: 'featuresWithoutUnitTest nennt nicht-existierende Feature-Dateien.',
    );
  });

  test('4) jede Feature-Datei ist in AI_MASTER.md indexiert', () {
    final master = File('AI_MASTER.md').readAsStringSync();
    for (final f in featureFiles) {
      expect(
        master.contains(basename(f.path)),
        isTrue,
        reason: '${basename(f.path)} fehlt in AI_MASTER.md (Feature-Übersicht in Abschnitt 8).',
      );
    }
  });
}
