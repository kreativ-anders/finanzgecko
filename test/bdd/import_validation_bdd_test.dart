// Gherkin: gherkin/executable/import_validation.feature
// Source: lib/data/import_validation.dart (dropInvalidImportEntries, importedBaseCurrency)
import 'package:finanzgecko/data/import_validation.dart';
import 'package:finanzgecko/models/account.dart';
import 'package:finanzgecko/models/asset.dart';
import 'package:finanzgecko/models/balance.dart';
import 'package:finanzgecko/models/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

final DateTime _date = DateTime(2025, 1, 15);

List<T> _list<T>(World w, String key) => (w.data[key] ??= <T>[]) as List<T>;

void main() {
  runFeature('gherkin/executable/import_validation.feature', (s) {
    void addBalance(World w, List<String> a, {String currency = 'EUR'}) {
      _list<Balance>(w, 'balances').add(
        Balance(
          id: int.parse(a[0]),
          accountId: int.parse(a[1]),
          period: a[2],
          amountOriginal: double.parse(a[3]),
          currencyOriginal: currency,
          rate: 1,
          amountBase: double.parse(a[3]),
          note: '',
          enteredAt: _date,
        ),
      );
    }

    // Registered first: the runner takes the first matching pattern, and the shorter one below would match too.
    s.step(
      r'an imported Kontostand (\d+) for Konto (\d+) in period "(.*)" with amount "(.*)" in currency "(.*)"',
      (w, a) => addBalance(w, a, currency: a[4]),
    );

    s.step(r'an imported Kontostand (\d+) for Konto (\d+) in period "(.*)" with amount "(.*)"', addBalance);

    s.step(r'an imported Konto (\d+) of Kontotyp "(.*)" in currency "(.*)"', (w, a) {
      _list<Account>(w, 'accounts').add(
        Account(
          id: int.parse(a[0]),
          name: 'Konto ${a[0]}',
          bank: '',
          tag: a[1],
          currency: a[2],
          color: '#00c878',
          archived: false,
          createdAt: _date,
        ),
      );
    });

    s.step(r'an imported Fixposten (\d+) with interval "(.*)" and amount "(.*)"', (w, a) {
      _list<Subscription>(w, 'subscriptions').add(
        Subscription(
          id: int.parse(a[0]),
          name: 'Fixposten ${a[0]}',
          interval: a[1],
          amountOriginal: double.parse(a[2]),
          currencyOriginal: 'EUR',
          rate: 1,
          amountBase: double.parse(a[2]),
          createdAt: _date,
        ),
      );
    });

    s.step(r'an imported Vermögenswert (\d+) with value "(.*)"', (w, a) {
      _list<Asset>(w, 'assets').add(
        Asset(
          id: int.parse(a[0]),
          name: 'Wert ${a[0]}',
          value: double.parse(a[1]),
          createdAt: _date,
          lastEvaluatedAt: _date,
        ),
      );
    });

    s.step(r'the imported entries are checked', (w, a) {
      w.data['result'] = dropInvalidImportEntries((
        accounts: _list<Account>(w, 'accounts'),
        balances: _list<Balance>(w, 'balances'),
        assets: _list<Asset>(w, 'assets'),
        subscriptions: _list<Subscription>(w, 'subscriptions'),
      ));
    });

    ImportedEntries result(World w) => w.data['result']! as ImportedEntries;

    s.step(r'(\d+) Kontostände remain', (w, a) => expect(result(w).balances, hasLength(int.parse(a[0]))));
    s.step(r'(\d+) Konten remain', (w, a) => expect(result(w).accounts, hasLength(int.parse(a[0]))));
    s.step(r'(\d+) Fixposten remain', (w, a) => expect(result(w).subscriptions, hasLength(int.parse(a[0]))));
    s.step(r'(\d+) Vermögenswerte remain', (w, a) => expect(result(w).assets, hasLength(int.parse(a[0]))));

    s.step(r'the remaining Kontostand has amount "(.*)"', (w, a) {
      expect(result(w).balances.single.amountOriginal, double.parse(a[0]));
    });

    s.step(r'the imported Basiswährung "(.*)" is checked', (w, a) {
      w.data['base'] = importedBaseCurrency(a[0]);
    });

    s.step(r'the Basiswährung to adopt is "(.*)"', (w, a) => expect(w.data['base'], a[0]));
    s.step(r'no Basiswährung is adopted', (w, a) => expect(w.data['base'], isNull));
  });
}
