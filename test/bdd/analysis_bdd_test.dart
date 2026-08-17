// Gherkin: gherkin/executable/net_worth_projection.feature
// Source: lib/utils/analysis.dart (trendSlopePerMonth, projectionRate, monthsToYearEnd, isBalanceAnomaly)
import 'package:finanzgecko/utils/analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

void main() {
  runFeature('gherkin/executable/net_worth_projection.feature', (s) {
    s.step(r'the monthly values (.+)', (w, a) {
      w.data['values'] = [for (final n in a[0].split(',')) double.parse(n.trim())];
    });

    s.step(r'the trend slope is (-?\d+(?:\.\d+)?)', (w, a) {
      final values = (w.data['values'] as List).cast<double>();
      expect(trendSlopePerMonth(values), closeTo(double.parse(a[0]), 1e-9));
    });

    s.step(
      r'I compute the projection rate with trend (-?\d+(?:\.\d+)?), plan (-?\d+(?:\.\d+)?), (\d+) points, and prior (\d+)',
      (w, a) {
        w.data['rate'] = projectionRate(
          trendRate: double.parse(a[0]),
          planRate: double.parse(a[1]),
          trendPoints: int.parse(a[2]),
          priorStrength: double.parse(a[3]),
        );
      },
    );

    s.step(r'the projection rate is (-?\d+(?:\.\d+)?)', (w, a) {
      expect(w.data['rate'] as double, closeTo(double.parse(a[0]), 1e-9));
    });

    s.step(r'it is (\d+) months? from "(.*)" to year end', (w, a) {
      expect(monthsToYearEnd(a[1]), int.parse(a[0]));
    });

    s.step(r'(\d+) against (\d+) is an anomaly', (w, a) {
      expect(isBalanceAnomaly(double.parse(a[0]), double.parse(a[1])), isTrue);
    });

    s.step(r'(\d+) against (\d+) is not an anomaly', (w, a) {
      expect(isBalanceAnomaly(double.parse(a[0]), double.parse(a[1])), isFalse);
    });
  });
}
