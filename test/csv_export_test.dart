import 'package:finanzgecko/models/account.dart';
import 'package:finanzgecko/models/balance.dart';
import 'package:finanzgecko/utils/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account acc(int id, String name, {String bank = 'Bank', String tag = 'Girokonto', String currency = 'EUR'}) => Account(
    id: id,
    name: name,
    bank: bank,
    tag: tag,
    currency: currency,
    color: '#00C878',
    archived: false,
    createdAt: DateTime(2026, 1, 1),
  );

  Balance bal(int id, int accountId, String period, double amountOriginal, {String currency = 'EUR', double rate = 1}) =>
      Balance(
        id: id,
        accountId: accountId,
        period: period,
        amountOriginal: amountOriginal,
        currencyOriginal: currency,
        rate: rate,
        amountBase: amountOriginal * rate,
        note: '',
        enteredAt: DateTime(2026, 1, 1),
      );

  test('header + rows use semicolon delimiter and comma decimals', () {
    final csv = buildBalancesCsv([acc(1, 'Giro')], [bal(1, 1, '2026-01', 1234.5)], baseCurrency: 'EUR');
    final lines = csv.trim().split('\n');
    expect(lines.first, 'Monat;Konto;Bank;Kontotyp;Währung;Betrag (Original);Kurs;Betrag (EUR)');
    expect(lines[1], '2026-01;Giro;Bank;Girokonto;EUR;1234,50;1,0000;1234,50');
  });

  test('rows are sorted by period, then account name', () {
    final csv = buildBalancesCsv(
      [acc(1, 'Zebra'), acc(2, 'Alpha')],
      [bal(10, 1, '2026-02', 1), bal(11, 2, '2026-01', 2), bal(12, 1, '2026-01', 3)],
      baseCurrency: 'EUR',
    );
    final lines = csv.trim().split('\n');
    expect(lines[1], startsWith('2026-01;Alpha'));
    expect(lines[2], startsWith('2026-01;Zebra'));
    expect(lines[3], startsWith('2026-02;Zebra'));
  });

  test('fields containing the delimiter are quoted', () {
    final csv = buildBalancesCsv([acc(1, 'Haus; Hof')], [bal(1, 1, '2026-01', 1)], baseCurrency: 'EUR');
    expect(csv, contains('"Haus; Hof"'));
  });

  test('a balance whose account is gone renders as (gelöscht)', () {
    final csv = buildBalancesCsv([], [bal(1, 99, '2026-01', 5)], baseCurrency: 'EUR');
    expect(csv, contains('2026-01;(gelöscht)'));
  });
}
