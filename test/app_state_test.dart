// Gherkin: gherkin/dashboard.feature, gherkin/balances_entries.feature, gherkin/subscriptions.feature, gherkin/notifications.feature
import 'dart:io';

import 'package:finanzgecko/constants.dart';
import 'package:finanzgecko/data/app_schema.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/services/notification_service.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records `show()` calls instead of touching a real OS notification center —
/// used to test the episode-based firing logic in [AppState] without any
/// platform dependency.
class _FakeNotificationService extends NotificationService {
  final List<String> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> show({required String title, required String body}) async {
    shown.add(body);
  }
}

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

  group('reminder notifications', () {
    test('backup: fires once when overdue, stays silent across a relaunch, fires again after export+new episode', () async {
      final store1 = AppStore(dataDirectory: tempDir);
      await store1.ensureInitialized();
      await store1.setLastExportAt(DateTime.now().subtract(const Duration(days: kBackupReminderDays + 1)));

      final fake1 = _FakeNotificationService();
      await AppState(store1, notificationService: fake1).init();
      expect(fake1.shown, hasLength(1));
      expect(fake1.shown.single, contains('Zeit für ein neues Backup'));

      // Reopening the app (fresh AppState/AppStore over the same directory)
      // must not refire while the episode is unresolved.
      final fake2 = _FakeNotificationService();
      final state2 = AppState(AppStore(dataDirectory: tempDir), notificationService: fake2);
      await state2.init();
      expect(fake2.shown, isEmpty);

      // Exporting resolves the episode; a fresh overdue period fires again.
      await state2.markExported();
      await state2.store.setLastExportAt(DateTime.now().subtract(const Duration(days: kBackupReminderDays + 1)));
      final fake3 = _FakeNotificationService();
      final state3 = AppState(AppStore(dataDirectory: tempDir), notificationService: fake3);
      await state3.init();
      expect(fake3.shown, hasLength(1));
    });

    test('backup: disabled toggle suppresses the notification even while overdue', () async {
      final store = AppStore(dataDirectory: tempDir);
      await store.ensureInitialized();
      await store.setLastExportAt(DateTime.now().subtract(const Duration(days: kBackupReminderDays + 1)));
      await store.setNotificationsEnabled(false);

      final fake = _FakeNotificationService();
      await AppState(store, notificationService: fake).init();
      expect(fake.shown, isEmpty);
    });

    test('assets: fires once (bundled), stays silent across a relaunch, fires again after re-evaluation', () async {
      final past = DateTime.now().subtract(const Duration(days: kAssetReevaluationDays + 1)).toIso8601String();
      final backup = {
        'schemaVersion': currentSchemaVersion,
        'baseCurrency': 'EUR',
        'accounts': <Map<String, dynamic>>[],
        'balances': <Map<String, dynamic>>[],
        'assets': [
          {'id': 1, 'name': 'Auto', 'value': 1000, 'createdAt': past, 'lastEvaluatedAt': past},
        ],
        'subscriptions': <Map<String, dynamic>>[],
      };

      final store1 = AppStore(dataDirectory: tempDir);
      await store1.ensureInitialized();
      await store1.importAllData(backup);
      // Isolate the asset notification from the (unrelated) backup reminder,
      // which would otherwise also fire on a never-exported fresh store.
      await store1.setLastExportAt(DateTime.now());

      final fake1 = _FakeNotificationService();
      await AppState(store1, notificationService: fake1).init();
      expect(fake1.shown, hasLength(1));
      expect(fake1.shown.single, contains('Auto'));

      final fake2 = _FakeNotificationService();
      final state2 = AppState(AppStore(dataDirectory: tempDir), notificationService: fake2);
      await state2.init();
      expect(fake2.shown, isEmpty, reason: 'still the same unresolved episode');

      await state2.updateAsset(1, value: 1200);

      final fake3 = _FakeNotificationService();
      final state3 = AppState(AppStore(dataDirectory: tempDir), notificationService: fake3);
      await state3.init();
      expect(fake3.shown, isEmpty, reason: 'freshly re-evaluated, no longer overdue');
    });
  });
}
