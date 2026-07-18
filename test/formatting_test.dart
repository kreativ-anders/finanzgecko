import 'package:finanzgecko/utils/formatting.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseInputNumber', () {
    test('returns null for empty or whitespace input', () {
      expect(parseInputNumber(''), isNull);
      expect(parseInputNumber('   '), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(parseInputNumber('abc'), isNull);
    });

    test('parses a plain integer', () {
      expect(parseInputNumber('1234'), 1234);
    });

    test('parses a bare decimal point (legacy prefill format)', () {
      expect(parseInputNumber('1234.56'), closeTo(1234.56, 1e-9));
      expect(parseInputNumber('100.5'), closeTo(100.5, 1e-9));
    });

    test('parses full German notation', () {
      expect(parseInputNumber('1.234,56'), closeTo(1234.56, 1e-9));
      expect(parseInputNumber('1.234.567,89'), closeTo(1234567.89, 1e-9));
      expect(parseInputNumber('12.345,6'), closeTo(12345.6, 1e-9));
    });

    test('treats a lone dot before exactly 3 digits as a thousands separator', () {
      // Documented rule: amounts here never carry 3 decimals, so "1.234" is 1234, not 1.234.
      expect(parseInputNumber('1.234'), 1234);
      expect(parseInputNumber('1.000'), 1000);
    });

    test('keeps a lone dot before non-3-digit groups as a decimal point', () {
      expect(parseInputNumber('5.00'), closeTo(5.0, 1e-9));
      expect(parseInputNumber('5.5'), closeTo(5.5, 1e-9));
    });

    test('handles negatives', () {
      expect(parseInputNumber('-50'), -50);
      expect(parseInputNumber('-1.234,56'), closeTo(-1234.56, 1e-9));
    });
  });

  group('fmtInputNumber round-trips through parseInputNumber', () {
    test('trims trailing zeros and uses German separators', () {
      expect(fmtInputNumber(12345.6), '12.345,6');
      expect(fmtInputNumber(1000), '1.000');
      expect(fmtInputNumber(0.5), '0,5');
    });

    test('a formatted value parses back to the original', () {
      for (final v in [0.0, 5.5, 1234.56, 1000000.0, -42.25]) {
        expect(parseInputNumber(fmtInputNumber(v)), closeTo(v, 1e-9), reason: 'value $v');
      }
    });
  });

  group('fmtPercent', () {
    test('formats with one decimal and a German comma', () {
      expect(fmtPercent(7.3), '7,3%');
      expect(fmtPercent(1234.5), '1.234,5%');
    });

    test('keeps the negative sign', () {
      expect(fmtPercent(-2.5), '-2,5%');
    });
  });

  group('fmtMoneyRounded / fmtSignedMoneyRounded', () {
    test('rounds to whole units — no decimal separator', () {
      final s = fmtMoneyRounded(1721.67, 'EUR');
      expect(s.contains(','), isFalse, reason: 'cents dropped: $s');
      expect(s.contains('1.722'), isTrue, reason: 'rounded + German grouping: $s');
    });

    test('signed variant prefixes + only for non-negative values', () {
      expect(fmtSignedMoneyRounded(1355.61, 'EUR').startsWith('+'), isTrue);
      final neg = fmtSignedMoneyRounded(-1355.61, 'EUR');
      expect(neg.startsWith('+'), isFalse);
      expect(neg.contains('-'), isTrue);
      expect(neg.contains('1.356'), isTrue);
    });
  });

  group('periodLabel', () {
    test('maps YYYY-MM to a German short month + year', () {
      expect(periodLabel('2025-01'), 'Jan 2025');
      expect(periodLabel('2025-03'), 'Mär 2025');
      expect(periodLabel('2025-12'), 'Dez 2025');
    });
  });

  group('lastDayOfMonthISO', () {
    test('handles 30/31-day months', () {
      expect(lastDayOfMonthISO('2025-01'), '2025-01-31');
      expect(lastDayOfMonthISO('2025-04'), '2025-04-30');
      expect(lastDayOfMonthISO('2025-12'), '2025-12-31');
    });

    test('handles February in leap and non-leap years', () {
      expect(lastDayOfMonthISO('2024-02'), '2024-02-29');
      expect(lastDayOfMonthISO('2025-02'), '2025-02-28');
    });
  });

  group('colorFromHex', () {
    test('adds full opacity to a 6-digit hex', () {
      expect(colorFromHex('#00c878'), const Color(0xFF00C878));
      expect(colorFromHex('00c878'), const Color(0xFF00C878));
    });

    test('falls back to the brand green on unparseable input', () {
      expect(colorFromHex('#xyz123'), const Color(0xFF00C878));
    });
  });

  group('daysSince', () {
    test('is 0 for now and counts whole elapsed days', () {
      expect(daysSince(DateTime.now()), 0);
      expect(daysSince(DateTime.now().subtract(const Duration(days: 10))), 10);
    });
  });
}
