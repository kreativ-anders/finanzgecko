// Gherkin: gherkin/backup_restore.feature, gherkin/accounts.feature, gherkin/subscriptions.feature, gherkin/assets.feature
import 'package:finanzgecko/constants.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake of the flutter_secure_storage channel (same approach as the
/// other store tests) so [AppStore.ensureInitialized] can fetch its key.
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

Map<String, dynamic> _account(
  int id, {
  String name = 'Konto',
  String bank = '',
  String tag = 'giro',
  String color = '#00c878',
}) => {
  'id': id,
  'name': name,
  'bank': bank,
  'tag': tag,
  'currency': 'EUR',
  'color': color,
  'archived': false,
  'createdAt': DateTime.now().toIso8601String(),
};

Map<String, dynamic> _backup({int schemaVersion = 1, String baseCurrency = 'EUR', List<dynamic> accounts = const []}) =>
    {
      'schemaVersion': schemaVersion,
      'baseCurrency': baseCurrency,
      'accounts': accounts,
      'balances': <dynamic>[],
      'assets': <dynamic>[],
      'subscriptions': <dynamic>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory store: no disk I/O, so these run fast and don't need a temp dir.
  // Disk persistence itself is covered by app_store_encryption_test.dart.
  Future<AppStore> bootStore() async {
    _FakeSecureStorage(<String, String>{}).install();
    final store = AppStore(persistToDisk: false);
    await store.ensureInitialized();
    return store;
  }

  group('importAllData', () {
    test('rejects a backup from a newer schema version and leaves data intact', () async {
      final store = await bootStore();
      await store.addAccount(name: 'Behalten', tag: 'giro', color: '#00c878');

      await expectLater(
        store.importAllData(_backup(schemaVersion: 999, accounts: [_account(1)])),
        throwsA(isA<Exception>()),
      );
      expect(store.getAccounts().map((a) => a.name), ['Behalten']);
    });

    test('replaces all data and recomputes id counters past the imported max', () async {
      final store = await bootStore();
      await store.addAccount(name: 'Alt', tag: 'giro', color: '#00c878');

      await store.importAllData(
        _backup(
          baseCurrency: 'USD',
          accounts: [_account(5, name: 'Importiert')],
        ),
      );

      expect(store.getAccounts().map((a) => a.name), ['Importiert']);
      expect(store.baseCurrency, 'USD');
      final fresh = await store.addAccount(name: 'Neu', tag: 'giro', color: '#00c878');
      expect(fresh.id, greaterThan(5), reason: 'next id must clear the imported max');
    });

    test('skips malformed entries within an otherwise valid backup', () async {
      final store = await bootStore();
      await store.importAllData(
        _backup(
          accounts: [
            _account(1, name: 'Gut'),
            {'name': 'Kein-ID'}, // missing id -> skipped
          ],
        ),
      );
      expect(store.getAccounts().map((a) => a.name), ['Gut']);
    });

    test('rejects an account with an unknown bank and leaves data intact', () async {
      final store = await bootStore();
      await store.addAccount(name: 'Behalten', tag: 'giro', color: '#00c878');

      await expectLater(
        store.importAllData(_backup(accounts: [_account(1, bank: 'Interactive Brokers')])),
        throwsA(isA<Exception>()),
      );
      expect(store.getAccounts().map((a) => a.name), ['Behalten']);
    });

    test('normalizes a known bank to its brand color, ignoring the file color', () async {
      final store = await bootStore();
      await store.importAllData(_backup(accounts: [_account(1, bank: 'DKB', color: '#ffffff')]));
      expect(store.getAccounts().single.color, bankColorHex('DKB'));
    });

    test('an empty bank keeps the Kontotyp fallback color', () async {
      final store = await bootStore();
      await store.importAllData(_backup(accounts: [_account(1, bank: '', tag: 'Depot')]));
      expect(store.getAccounts().single.color, tagColorHex('Depot'));
    });
  });

  group('balances', () {
    test('upsertBalance updates in place for the same account + period', () async {
      final store = await bootStore();
      final acc = await store.addAccount(name: 'Giro', tag: 'giro', color: '#00c878');
      await store.upsertBalance(
        accountId: acc.id,
        period: '2025-01',
        amountOriginal: 100,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 100,
      );
      await store.upsertBalance(
        accountId: acc.id,
        period: '2025-01',
        amountOriginal: 200,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 200,
      );

      final list = store.getBalancesForAccount(acc.id);
      expect(list.length, 1, reason: 'same period should overwrite, not duplicate');
      expect(list.single.amountBase, 200);
    });
  });

  group('accounts', () {
    test('archive hides from the active list but keeps it findable; restore reverses it', () async {
      final store = await bootStore();
      final acc = await store.addAccount(name: 'Konto', tag: 'giro', color: '#00c878');

      await store.archiveAccount(acc.id);
      expect(store.getAccounts().where((a) => a.id == acc.id), isEmpty);
      expect(store.getAccounts(includeArchived: true).map((a) => a.id), contains(acc.id));
      expect(store.getAccount(acc.id)?.archived, isTrue);

      await store.restoreAccount(acc.id);
      expect(store.getAccount(acc.id)?.archived, isFalse);
      expect(store.getAccounts().map((a) => a.id), contains(acc.id));
    });
  });

  group('assets', () {
    test('updateAsset refreshes lastEvaluatedAt only when the value changes', () async {
      final store = await bootStore();
      final asset = await store.addAsset(name: 'Auto', value: 1000);
      final original = asset.lastEvaluatedAt!;

      final afterName = await store.updateAsset(asset.id, name: 'Wagen');
      expect(afterName.lastEvaluatedAt, original, reason: 'name-only edit must not count as a re-evaluation');

      final afterValue = await store.updateAsset(asset.id, value: 1200);
      expect(afterValue.lastEvaluatedAt!.isBefore(original), isFalse, reason: 'value edit refreshes the timestamp');
    });
  });

  group('subscriptions', () {
    test('updateSubscription with partial fields keeps the rest', () async {
      final store = await bootStore();
      final sub = await store.addSubscription(
        name: 'Alt',
        interval: 'monthly',
        amountOriginal: 10,
        currencyOriginal: 'EUR',
        rate: 1,
        amountBase: 10,
      );

      final updated = await store.updateSubscription(sub.id, name: 'Neu');
      expect(updated.name, 'Neu');
      expect(updated.interval, 'monthly');
      expect(updated.amountBase, 10);
    });
  });
}
