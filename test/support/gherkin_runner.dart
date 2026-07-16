import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tiny, dependency-free Gherkin runner so `.feature` files are actually
/// EXECUTED by `flutter test` (not just documented). It parses one feature and
/// runs each `Scenario` as a Flutter `test`, matching every step line against a
/// registry of step definitions that call real `lib/` code.
///
/// Deliberately minimal: Feature / Background / Rule / Scenario + steps
/// (Given/When/Then/And/But). Tags (`@…`) and comments (`#…`) are ignored.
/// `Scenario Outline`, `Examples` and data tables are NOT supported — keep
/// executable features to plain scenarios (enumerate cases as separate ones).
///
/// Usage (see test/bdd/*_bdd_test.dart):
/// ```
/// void main() => runFeature('gherkin/executable/x.feature', (s) {
///   s.step(r'ich X mit "(.*)" tue', (w, a) { w.data['r'] = doX(a[0]); });
///   s.step(r'ist das Ergebnis "(.*)"', (w, a) => expect(w.data['r'], a[0]));
/// });
/// ```
typedef StepBody = FutureOr<void> Function(World world, List<String> args);

/// Per-scenario shared state, so one step can hand values to the next.
class World {
  final Map<String, Object?> data = <String, Object?>{};
}

class _StepDef {
  final RegExp pattern;
  final StepBody body;
  _StepDef(this.pattern, this.body);
}

class StepRegistry {
  // Private so the public class doesn't expose the private _StepDef type
  // (library_private_types_in_public_api). runFeature (same file) reads it.
  final List<_StepDef> _defs = [];

  /// Registers a step. [pattern] is a regex for the step text WITHOUT its
  /// Gherkin keyword; capture groups become the `args` list.
  void step(String pattern, StepBody body) => _defs.add(_StepDef(RegExp('^$pattern\$'), body));
}

class _Scenario {
  final String name;
  final List<String> steps;
  _Scenario(this.name, this.steps);
}

final _keyword = RegExp(r'^(Given|When|Then|And|But)\s+');

/// Parses [featurePath] and runs its scenarios against the registry built by
/// [define]. Background steps run before each scenario's steps.
void runFeature(String featurePath, void Function(StepRegistry) define) {
  final registry = StepRegistry();
  define(registry);

  var featureName = featurePath;
  final background = <String>[];
  final scenarios = <_Scenario>[];
  List<String>? current;

  for (final raw in File(featurePath).readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('@')) continue;
    if (line.startsWith('Feature:')) {
      featureName = line.substring('Feature:'.length).trim();
      current = null;
    } else if (line.startsWith('Rule:')) {
      current = null;
    } else if (line.startsWith('Background:')) {
      current = background;
    } else if (line.startsWith('Scenario Outline:')) {
      throw StateError('Scenario Outline wird vom Runner nicht unterstützt: "$line"');
    } else if (line.startsWith('Scenario:')) {
      final s = _Scenario(line.substring('Scenario:'.length).trim(), <String>[]);
      scenarios.add(s);
      current = s.steps;
    } else if (_keyword.hasMatch(line)) {
      (current ?? background).add(line.replaceFirst(_keyword, '').trim());
    } else {
      throw StateError('Nicht unterstützte Gherkin-Zeile in $featurePath: "$line"');
    }
  }

  group(featureName, () {
    for (final scenario in scenarios) {
      test(scenario.name, () async {
        final world = World();
        for (final text in [...background, ...scenario.steps]) {
          _StepDef? def;
          Match? match;
          for (final d in registry._defs) {
            final m = d.pattern.firstMatch(text);
            if (m != null) {
              def = d;
              match = m;
              break;
            }
          }
          if (def == null) {
            fail('Kein Step-Def für: "$text"  (Szenario "${scenario.name}", $featurePath)');
          }
          final args = [for (var i = 1; i <= match!.groupCount; i++) match.group(i) ?? ''];
          await def.body(world, args);
        }
      });
    }
  });
}
