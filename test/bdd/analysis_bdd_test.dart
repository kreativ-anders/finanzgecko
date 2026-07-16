// Gherkin: gherkin/executable/net_worth_projection.feature
// Quelle: lib/utils/analysis.dart (trendSlopePerMonth, projectionRate, monthsToYearEnd, isBalanceAnomaly)
import 'package:finanzgecko/utils/analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

void main() {
  runFeature('gherkin/executable/net_worth_projection.feature', (s) {
    s.step(r'die Monatswerte (.+)', (w, a) {
      w.data['values'] = [for (final n in a[0].split(',')) double.parse(n.trim())];
    });

    s.step(r'ist die Trendsteigung (-?\d+(?:\.\d+)?)', (w, a) {
      final values = (w.data['values'] as List).cast<double>();
      expect(trendSlopePerMonth(values), closeTo(double.parse(a[0]), 1e-9));
    });

    s.step(
      r'ich die Prognoserate mit Trend (-?\d+(?:\.\d+)?), Plan (-?\d+(?:\.\d+)?), (\d+) Punkten und Prior (\d+) berechne',
      (w, a) {
        w.data['rate'] = projectionRate(
          trendRate: double.parse(a[0]),
          planRate: double.parse(a[1]),
          trendPoints: int.parse(a[2]),
          priorStrength: double.parse(a[3]),
        );
      },
    );

    s.step(r'ist die Prognoserate (-?\d+(?:\.\d+)?)', (w, a) {
      expect(w.data['rate'] as double, closeTo(double.parse(a[0]), 1e-9));
    });

    s.step(r'sind es von "(.*)" (\d+) Monate bis Jahresende', (w, a) {
      expect(monthsToYearEnd(a[0]), int.parse(a[1]));
    });

    s.step(r'ist (\d+) gegenüber (\d+) eine Anomalie', (w, a) {
      expect(isBalanceAnomaly(double.parse(a[0]), double.parse(a[1])), isTrue);
    });

    s.step(r'ist (\d+) gegenüber (\d+) keine Anomalie', (w, a) {
      expect(isBalanceAnomaly(double.parse(a[0]), double.parse(a[1])), isFalse);
    });
  });
}
