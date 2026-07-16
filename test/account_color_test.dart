import 'package:finanzgecko/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAccountColor', () {
    test('a known bank yields its brand color (case-insensitive)', () {
      expect(resolveAccountColor(bank: 'DKB', tag: 'Girokonto'), bankColorHex('DKB'));
      expect(resolveAccountColor(bank: 'dkb', tag: 'Girokonto'), bankColorHex('DKB'));
      expect(resolveAccountColor(bank: 'Trade Republic', tag: 'Depot'), '#000000');
    });

    test('an empty or whitespace bank falls back to the Kontotyp color', () {
      expect(resolveAccountColor(bank: '', tag: 'Krypto'), tagColorHex('Krypto'));
      expect(resolveAccountColor(bank: '   ', tag: 'Bargeld'), tagColorHex('Bargeld'));
    });

    test('an unknown, non-empty bank throws', () {
      expect(() => resolveAccountColor(bank: 'Interactive Brokers', tag: 'Depot'), throwsFormatException);
      expect(() => resolveAccountColor(bank: 'Bitpanda', tag: 'Krypto'), throwsFormatException);
    });
  });
}
