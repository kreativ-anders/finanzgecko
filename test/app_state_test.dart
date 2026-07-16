// Gherkin: gherkin/dashboard.feature, gherkin/balances_entries.feature, gherkin/subscriptions.feature
import 'dart:io';

import 'package:finanzgecko/constants.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake of the flutter_secure_storage platform channel — same
/// approach as app_store_encryption_test.dart, so AppState's real AppStore
/// runs against a temp dir without needing an OS keychain.
class _FakeSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;

  static const MethodChannel _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'read':
          return values[(call.arguments as Map)['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          values[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          values.remove((call.arguments as Map)['key'] as String);
          return null;
        case 'readAll':
          return values;
        case 'deleteAll':
          values.clear();
          return null;
        case 'containsKey':
          return values.containsKey((call.arguments as Map)['key'] as String);
        default:
          return null;
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('finanzgecko_appstate_test_');
    _FakeSecureStorage(<String, String>{}).install();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<AppState> newState() async {
    final state = AppState(AppStore(dataDirectory: tempDir));
    await state.init();
    return state;
  }

  group('interval month factors (pure)', () {
    test('monthly is the identity factor', () {
      expect(intervalMonthFactor('monthly'), 1);
    });

    test('yearly is one twelfth', () {
      expect(intervalMonthFactor('yearly'), closeTo(1 / 12, 1e-9));
    });

    test('unknown interval falls back to 1', () {
      expect(intervalMonthFactor('does-not-exist'), 1);
    });
  });

  group('subscription totals', () {
    test('sums income and expenses on a monthly basis', () async {
      final state = await newState();
      // Monthly income of 200.
      await state.addSubscription(
        name: 'Gehalt',
        interval: 'monthly',
        amountOriginal: 200,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 200,
      );
      // Yearly income of 1200 -> 100/month.
      await state.addSubscription(
        name: 'Bonus',
        interval: 'yearly',
        amountOriginal: 1200,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 1200,
      );
      // Monthly expense of 50.
      await state.addSubscription(
        name: 'Streaming',
        interval: 'monthly',
        amountOriginal: 50,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: -50,
      );

      final totals = state.computeSubscriptionTotals();
      expect(totals.totalIncome, closeTo(300, 1e-9));
      expect(totals.totalExpense, closeTo(50, 1e-9));
      expect(totals.net, closeTo(250, 1e-9));
    });

    test('monthlyEquivalent scales a yearly amount to one month', () async {
      final state = await newState();
      await state.addSubscription(
        name: 'Versicherung',
        interval: 'yearly',
        amountOriginal: 1200,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: -1200,
      );

      expect(state.monthlyEquivalent(state.subscriptions.single), closeTo(-100, 1e-9));
    });

    test('totals are zero with no subscriptions', () async {
      final state = await newState();
      final totals = state.computeSubscriptionTotals();
      expect(totals.totalIncome, 0);
      expect(totals.totalExpense, 0);
      expect(totals.net, 0);
    });
  });

  group('backup reminder', () {
    test('flags "never exported" on a fresh store', () async {
      final state = await newState();
      final reminder = state.getBackupReminder();
      expect(reminder.overdue, isTrue);
      expect(reminder.message, contains('Noch nie'));
    });

    test('clears once an export is recorded', () async {
      final state = await newState();
      await state.markExported();
      expect(state.getBackupReminder().overdue, isFalse);
    });
  });

  group('balance lookups', () {
    test('previousBalance returns the most recent entry strictly before a period', () async {
      final state = await newState();
      final acc = await state.addAccount(name: 'Giro', tag: 'Girokonto', currency: 'EUR', color: '#00c878');
      for (final period in ['2024-01', '2024-02', '2024-05']) {
        await state.upsertBalance(
          accountId: acc.id,
          period: period,
          amountOriginal: 100,
          currencyOriginal: 'EUR',
          rate: 1,
          amountBase: 100,
        );
      }

      final prev = state.previousBalance(acc.id, '2024-05');
      expect(prev?.period, '2024-02');
      expect(state.previousBalance(acc.id, '2024-01'), isNull);
    });

    test('latestBalanceForAccount returns the newest period', () async {
      final state = await newState();
      final acc = await state.addAccount(name: 'Giro', tag: 'Girokonto', currency: 'EUR', color: '#00c878');
      await state.upsertBalance(
        accountId: acc.id,
        period: '2024-01',
        amountOriginal: 100,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 100,
      );
      await state.upsertBalance(
        accountId: acc.id,
        period: '2024-07',
        amountOriginal: 300,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 300,
      );

      expect(state.latestBalanceForAccount(acc.id)?.period, '2024-07');
      expect(state.latestBalanceForAccount(9999), isNull);
    });
  });

  group('asset reminder', () {
    test('a freshly added asset is not overdue and yields no reminder', () async {
      final state = await newState();
      await state.addAsset(name: 'Auto', value: 15000);
      expect(state.assets.single, isNotNull);
      expect(state.isAssetOverdue(state.assets.single), isFalse);
      expect(state.getAssetReminder(), isNull);
    });
  });

  group('settings', () {
    test('setBaseCurrency updates in-memory state', () async {
      final state = await newState();
      expect(state.baseCurrency, 'EUR');
      await state.setBaseCurrency('USD');
      expect(state.baseCurrency, 'USD');
    });
  });
}
