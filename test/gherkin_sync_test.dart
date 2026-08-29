import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hardwires the Gherkin spec into the test pipeline: `flutter test` FAILS if
/// the features drift from the code or the tests. This runs in the same
/// pipeline as everything else (incl. the release `test`-gate), so the
/// `gherkin/` folder can no longer live an isolated life next to the code.
///
/// Three invariants:
///  1. Every `gherkin/*.feature` has a `# Source:` header and every source path
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
    // currency_exchange has been covered by test/rate_consent_test.dart since
    // the opt-in (issue #16) — but only the gate part (is a fetch allowed?),
    // not the HTTP call itself, which remains UI/integration territory.
    'gherkin/window.feature',
    'gherkin/navigation.feature',
  };

  // Built at runtime so this test can never self-match its own doc comment.
  final marker = RegExp('//\\s*${'Gherkin'}:\\s*(.+)');

  String basename(String path) => path.split(RegExp(r'[\\/]')).last;

  String posix(String path) => path.replaceAll('\\', '/');

  // Recursive: also catches executable specs in gherkin/executable/.
  final featureFiles =
      Directory(
          'gherkin',
        ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.feature')).toList()
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

  test('there are feature files', () {
    expect(featureFiles, isNotEmpty);
  });

  group('1) "# Source:" only points at existing code', () {
    for (final f in featureFiles) {
      test(basename(f.path), () {
        final header = f.readAsLinesSync().firstWhere((l) => l.trimLeft().startsWith('# Source:'), orElse: () => '');
        expect(header, isNotEmpty, reason: '${basename(f.path)} needs a "# Source:" header.');
        final paths = header
            .replaceFirst(RegExp(r'^\s*#\s*Source:\s*'), '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final path in paths) {
          expect(File(path).existsSync(), isTrue, reason: '$path (from ${basename(f.path)}) no longer exists.');
        }
      });
    }
  });

  test('2) every test→feature link points at an existing feature file', () {
    for (final (testFile, ref) in annotationRefs) {
      expect(featurePaths, contains(ref), reason: '$testFile links to an unknown feature "$ref".');
    }
  });

  test('3) exactly the allowed features have no unit test', () {
    final uncovered = featurePaths.difference(coverage.keys.toSet());
    expect(
      uncovered,
      featuresWithoutUnitTest,
      reason:
          'Mismatch. Features without a test = $uncovered.\n'
          'Either add a test with the line "// '
          'Gherkin: <feature>" '
          'or deliberately adjust featuresWithoutUnitTest in this test.',
    );
    expect(
      featuresWithoutUnitTest.difference(featurePaths),
      isEmpty,
      reason: 'featuresWithoutUnitTest names feature files that don\'t exist.',
    );
  });

  test('4) every feature file is indexed in dev/ai/testing.md', () {
    final master = File('dev/ai/testing.md').readAsStringSync();
    for (final f in featureFiles) {
      expect(
        master.contains(basename(f.path)),
        isTrue,
        reason: '${basename(f.path)} is missing from dev/ai/testing.md (feature overview table).',
      );
    }
  });

  test('5) every feature has a # Implementation: (regeneration target) from # Source:', () {
    for (final f in featureFiles) {
      final lines = f.readAsLinesSync();
      String headerValue(String key) {
        final line = lines.firstWhere((l) => l.trimLeft().startsWith(key), orElse: () => '');
        return line.isEmpty ? '' : line.trim().substring(key.length).trim();
      }

      final impl = headerValue('# Implementation:');
      final source = headerValue('# Source:').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
      final where = basename(f.path);
      expect(impl, isNotEmpty, reason: '$where needs a header line "# Implementation: <file>" (regeneration target).');
      expect(File(impl).existsSync(), isTrue, reason: '$where: implementation "$impl" doesn\'t exist.');
      expect(source, contains(impl), reason: '$where: "$impl" must also be listed in "# Source:".');
    }
  });
}
