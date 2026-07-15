import 'package:finanzgecko/utils/analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthsBetweenPeriods', () {
    test('same month is zero', () {
      expect(monthsBetweenPeriods('2026-06', '2026-06'), 0);
    });

    test('within a year', () {
      expect(monthsBetweenPeriods('2026-01', '2026-06'), 5);
    });

    test('across a year boundary', () {
      expect(monthsBetweenPeriods('2025-11', '2026-02'), 3);
    });

    test('negative when b precedes a', () {
      expect(monthsBetweenPeriods('2026-06', '2026-01'), -5);
    });
  });

  group('monthsToYearEnd', () {
    test('mid-year counts to December', () {
      expect(monthsToYearEnd('2026-06'), 6);
    });

    test('January', () {
      expect(monthsToYearEnd('2026-01'), 11);
    });

    test('December projects a full year rather than zero', () {
      expect(monthsToYearEnd('2026-12'), 12);
    });
  });

  group('trendSlopePerMonth', () {
    test('null with fewer than two points', () {
      expect(trendSlopePerMonth([]), isNull);
      expect(trendSlopePerMonth([100]), isNull);
    });

    test('perfect linear series recovers the slope', () {
      expect(trendSlopePerMonth([100, 200, 300, 400]), closeTo(100, 1e-9));
    });

    test('flat series has zero slope', () {
      expect(trendSlopePerMonth([500, 500, 500]), closeTo(0, 1e-9));
    });

    test('declining series has negative slope', () {
      expect(trendSlopePerMonth([300, 200, 100]), closeTo(-100, 1e-9));
    });
  });

  group('projectionRate', () {
    test('null when neither basis available', () {
      expect(projectionRate(planRate: null, trendRate: null, trendPoints: 5), isNull);
    });

    test('uses trend alone when no plan', () {
      expect(projectionRate(planRate: null, trendRate: 200, trendPoints: 5), 200);
    });

    test('uses plan alone when no trend', () {
      expect(projectionRate(planRate: 150, trendRate: null, trendPoints: 0), 150);
    });

    test('blends with decaying prior weight', () {
      // trendPoints == priorStrength -> equal weight -> simple average.
      expect(projectionRate(planRate: 100, trendRate: 300, trendPoints: 3, priorStrength: 3), closeTo(200, 1e-9));
    });

    test('trend dominates as history grows', () {
      final rate = projectionRate(planRate: 100, trendRate: 300, trendPoints: 24, priorStrength: 3)!;
      // Weight on trend = 24/27 -> closer to 300 than to the midpoint.
      expect(rate, greaterThan(250));
    });
  });

  group('contributionMarketSplit', () {
    test('positive market when growth beats contributions', () {
      final s = contributionMarketSplit(delta: 1000, monthlyNet: 600, monthGap: 1);
      expect(s.contributions, 600);
      expect(s.market, 400);
    });

    test('scales contributions by the month gap', () {
      final s = contributionMarketSplit(delta: 1000, monthlyNet: 600, monthGap: 2);
      expect(s.contributions, 1200);
      expect(s.market, closeTo(-200, 1e-9));
    });
  });

  group('isBalanceAnomaly', () {
    test('flags a 10x jump (extra digit)', () {
      expect(isBalanceAnomaly(22000, 2200), isTrue);
    });

    test('flags a 10x drop (missing digit)', () {
      expect(isBalanceAnomaly(220, 2200), isTrue);
    });

    test('allows an ordinary move', () {
      expect(isBalanceAnomaly(2400, 2200), isFalse);
      expect(isBalanceAnomaly(4000, 2200), isFalse);
    });

    test('no basis when either side is zero', () {
      expect(isBalanceAnomaly(0, 2200), isFalse);
      expect(isBalanceAnomaly(2200, 0), isFalse);
    });
  });

  group('computeNetWorthStats', () {
    test('null with fewer than two points', () {
      expect(computeNetWorthStats([(period: '2026-01', total: 100)]), isNull);
    });

    test('best, worst, average, and up-share', () {
      final stats = computeNetWorthStats([
        (period: '2026-01', total: 1000),
        (period: '2026-02', total: 1500), // +500
        (period: '2026-03', total: 1200), // -300
        (period: '2026-04', total: 1400), // +200
      ])!;
      expect(stats.best.period, '2026-02');
      expect(stats.best.delta, 500);
      expect(stats.worst.period, '2026-03');
      expect(stats.worst.delta, -300);
      expect(stats.averageChange, closeTo(400 / 3, 1e-9));
      expect(stats.monthsUp, 2);
      expect(stats.changeCount, 3);
      expect(stats.upShare, closeTo(2 / 3, 1e-9));
      expect(stats.totalGrowth, 400); // 1400 - 1000
      expect(stats.startPeriod, '2026-01');
      expect(stats.peak, 1500); // high was Feb, not the last month
      expect(stats.peakPeriod, '2026-02');
      expect(stats.current, 1400);
      expect(stats.drawdownFromPeak, closeTo((1500 - 1400) / 1500, 1e-9));
    });

    test('drawdown is zero at an all-time high', () {
      final stats = computeNetWorthStats([(period: '2026-01', total: 1000), (period: '2026-02', total: 1200)])!;
      expect(stats.peak, 1200);
      expect(stats.current, 1200);
      expect(stats.drawdownFromPeak, 0);
    });
  });

  group('periodsForRange', () {
    final all = ['2024-11', '2024-12', '2025-06', '2026-01', '2026-07'];
    final now = DateTime(2026, 7, 15);

    test('ytd keeps only the current calendar year', () {
      expect(periodsForRange(all, HistoryRange.ytd, now: now), ['2026-01', '2026-07']);
    });

    test('lastYear keeps only the previous calendar year', () {
      expect(periodsForRange(all, HistoryRange.lastYear, now: now), ['2025-06']);
    });

    test('twelveMonths keeps the rolling last 12 months', () {
      // Cutoff is 2025-08; 2025-06 and earlier drop out.
      expect(periodsForRange(all, HistoryRange.twelveMonths, now: now), ['2026-01', '2026-07']);
    });

    test('all keeps everything', () {
      expect(periodsForRange(all, HistoryRange.all, now: now), all);
    });
  });

  group('availableRanges', () {
    test('only Alle when there is no data', () {
      expect(availableRanges([], now: DateTime(2026, 7, 15)), [HistoryRange.all]);
    });

    test('hides presets identical to Alle (first year of use)', () {
      // All data sits in the current year and within 12 months, so ytd and
      // twelveMonths both equal Alle and are hidden.
      final ranges = availableRanges(['2026-05', '2026-06', '2026-07'], now: DateTime(2026, 7, 15));
      expect(ranges, [HistoryRange.all]);
    });

    test('shows distinct presets once history spans years', () {
      final ranges = availableRanges(['2024-11', '2025-06', '2026-01', '2026-07'], now: DateTime(2026, 7, 15));
      expect(ranges, contains(HistoryRange.ytd));
      expect(ranges, contains(HistoryRange.lastYear));
      expect(ranges.last, HistoryRange.all);
    });
  });

  group('defaultRange', () {
    test('prefers Dieses Jahr when available', () {
      expect(defaultRange([HistoryRange.ytd, HistoryRange.all]), HistoryRange.ytd);
    });

    test('falls back to Alle when ytd is not offered', () {
      expect(defaultRange([HistoryRange.lastYear, HistoryRange.all]), HistoryRange.all);
    });
  });
}
