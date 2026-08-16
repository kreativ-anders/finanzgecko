// Gherkin: gherkin/settings.feature
import 'package:finanzgecko/models/account.dart';
import 'package:finanzgecko/models/asset.dart';
import 'package:finanzgecko/models/balance.dart';
import 'package:finanzgecko/models/subscription.dart';
import 'package:finanzgecko/utils/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account acc(
    int id,
    String name, {
    String bank = 'Bank',
    String tag = 'Girokonto',
    String currency = 'EUR',
    bool archived = false,
  }) => Account(
    id: id,
    name: name,
    bank: bank,
    tag: tag,
    currency: currency,
    color: '#00C878',
    archived: archived,
    createdAt: DateTime(2026, 1, 1),
  );

  Balance bal(
    int id,
    int accountId,
    String period,
    double amountOriginal, {
    String currency = 'EUR',
    double rate = 1,
  }) => Balance(
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

  Subscription sub(
    int id,
    String name,
    double amountOriginal, {
    String interval = 'monthly',
    String currency = 'EUR',
    double rate = 1,
  }) => Subscription(
    id: id,
    name: name,
    interval: interval,
    amountOriginal: amountOriginal,
    currencyOriginal: currency,
    rate: rate,
    amountBase: amountOriginal * rate,
    createdAt: DateTime(2026, 1, 1),
  );

  Asset asset(int id, String name, double value) =>
      Asset(id: id, name: name, value: value, createdAt: DateTime(2026, 1, 1), lastEvaluatedAt: DateTime(2026, 3, 4));

  List<String> lines(String csv) => csv.trim().split('\n');

  group('Konten', () {
    test('header + rows sorted by name', () {
      final csv = buildAccountsCsv([acc(1, 'Giro'), acc(7, 'Altes Depot', bank: 'ING', tag: 'Depot', archived: true)]);
      expect(lines(csv).first, 'Konto-ID;Konto;Bank;Kontotyp');
      expect(lines(csv)[1], '7;Altes Depot;ING;Depot');
      expect(lines(csv)[2], '1;Giro;Bank;Girokonto');
    });

    test('name/bank starting with a formula-trigger char get neutralized', () {
      final csv = buildAccountsCsv([acc(1, '=cmd|calc', bank: '+1; Bank')]);
      expect(lines(csv)[1], "1;'=cmd|calc;\"'+1; Bank\";Girokonto");
    });
  });

  group('Kontostände', () {
    test('header + rows use semicolon delimiter and comma decimals', () {
      final csv = buildBalancesCsv([acc(1, 'Giro')], [bal(1, 1, '2026-01', 1234.5)]);
      expect(lines(csv).first, 'Monat;Konto-ID;Konto;Währung;Betrag');
      expect(lines(csv)[1], '2026-01;1;Giro;EUR;1234,50');
    });

    test('no Konto master data is repeated per row', () {
      final csv = buildBalancesCsv([acc(1, 'Giro', bank: 'DKB', tag: 'Girokonto')], [bal(1, 1, '2026-01', 1)]);
      expect(csv, isNot(contains('DKB')));
      expect(csv, isNot(contains('Girokonto')));
    });

    test('the amount stays in the currency it was entered in, without a rate', () {
      final csv = buildBalancesCsv([acc(1, 'US-Aktien')], [bal(1, 1, '2026-01', 12000, currency: 'USD', rate: 0.87)]);
      expect(lines(csv)[1], '2026-01;1;US-Aktien;USD;12000,00');
    });

    test('rows are sorted by period, then account name', () {
      final csv = buildBalancesCsv(
        [acc(1, 'Zebra'), acc(2, 'Alpha')],
        [bal(10, 1, '2026-02', 1), bal(11, 2, '2026-01', 2), bal(12, 1, '2026-01', 3)],
      );
      expect(lines(csv)[1], startsWith('2026-01;2;Alpha'));
      expect(lines(csv)[2], startsWith('2026-01;1;Zebra'));
      expect(lines(csv)[3], startsWith('2026-02;1;Zebra'));
    });

    test('fields containing the delimiter are quoted', () {
      final csv = buildBalancesCsv([acc(1, 'Haus; Hof')], [bal(1, 1, '2026-01', 1)]);
      expect(csv, contains('"Haus; Hof"'));
    });

    test('a balance whose account is gone renders as (gelöscht) but keeps its id', () {
      final csv = buildBalancesCsv([], [bal(1, 99, '2026-01', 5)]);
      expect(csv, contains('2026-01;99;(gelöscht)'));
    });

    test('a negative amount is not treated as a formula trigger', () {
      final csv = buildBalancesCsv([acc(1, 'Giro')], [bal(1, 1, '2026-01', -5)]);
      expect(lines(csv)[1], endsWith(';-5,00'));
    });
  });

  group('Fixposten', () {
    test('header + row with interval label and the amount per interval', () {
      final csv = buildSubscriptionsCsv([sub(1, 'Versicherung', -120, interval: 'yearly')]);
      expect(lines(csv).first, 'Fixposten;Art;Intervall;Währung;Betrag');
      // -120 per year, NOT converted to a monthly -10: the Intervall column
      // carries that information instead.
      expect(lines(csv)[1], 'Versicherung;Ausgabe;Jährlich;EUR;-120,00');
    });

    test('Einnahmen come before Ausgaben, each sorted by name', () {
      final csv = buildSubscriptionsCsv([
        sub(1, 'Miete', -900),
        sub(2, 'Gehalt', 3000),
        sub(3, 'Abo', -10),
        sub(4, 'Dividende', 20),
      ]);
      expect(lines(csv).skip(1).map((l) => l.split(';').first).toList(), ['Dividende', 'Gehalt', 'Abo', 'Miete']);
    });

    test('a foreign-currency Fixposten keeps its original amount and currency', () {
      final csv = buildSubscriptionsCsv([sub(1, 'Hosting', -20, currency: 'USD', rate: 0.9)]);
      expect(lines(csv)[1], 'Hosting;Ausgabe;Monatlich;USD;-20,00');
    });

    test('a name starting with a formula-trigger char gets neutralized', () {
      final csv = buildSubscriptionsCsv([sub(1, '@import', -1)]);
      expect(lines(csv)[1], startsWith("'@import;"));
    });
  });

  group('Vermögenswerte', () {
    test('header + rows sorted by name', () {
      final csv = buildAssetsCsv([asset(1, 'Fahrrad', 1200), asset(2, 'Auto', 8000)], baseCurrency: 'EUR');
      expect(lines(csv).first, 'Vermögenswert;Wert (EUR)');
      expect(lines(csv)[1], 'Auto;8000,00');
      expect(lines(csv)[2], 'Fahrrad;1200,00');
    });

    test('the base currency drives the value header', () {
      final csv = buildAssetsCsv([], baseCurrency: 'CHF');
      expect(lines(csv).first, 'Vermögenswert;Wert (CHF)');
    });

    test('a name starting with a formula-trigger char gets neutralized', () {
      final csv = buildAssetsCsv([asset(1, '-Oldtimer', 1)], baseCurrency: 'EUR');
      expect(lines(csv)[1], "'-Oldtimer;1,00");
    });
  });

  group('Bündel', () {
    test('one file per domain, each with the export date in its name', () {
      final files = buildCsvExports(
        accounts: [acc(1, 'Giro')],
        balances: [bal(1, 1, '2026-01', 1)],
        subscriptions: [sub(1, 'Miete', -900)],
        assets: [asset(1, 'Auto', 8000)],
        baseCurrency: 'EUR',
        dateStamp: '2026-08-16',
      );
      expect(files.map((f) => f.fileName).toList(), [
        'finanzgecko-konten-2026-08-16.csv',
        'finanzgecko-kontostaende-2026-08-16.csv',
        'finanzgecko-fixposten-2026-08-16.csv',
        'finanzgecko-vermoegenswerte-2026-08-16.csv',
      ]);
      for (final f in files) {
        expect(lines(f.content), hasLength(2));
      }
    });

    test('empty data still yields four files with headers only', () {
      final files = buildCsvExports(
        accounts: [],
        balances: [],
        subscriptions: [],
        assets: [],
        baseCurrency: 'EUR',
        dateStamp: '2026-08-16',
      );
      expect(files, hasLength(4));
      // A header-only file is still a readable table, not a 0-byte puzzle.
      for (final f in files) {
        expect(lines(f.content), hasLength(1));
      }
    });
  });
}
