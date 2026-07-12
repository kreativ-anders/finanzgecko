import 'dart:convert';
import 'dart:io';

import 'package:finanzgecko/data/app_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fakes the flutter_secure_storage platform channel with an in-memory map,
/// so tests exercise the real AES-GCM envelope logic in [AppStore] without
/// needing a real OS keychain. Sharing one [values] map across two
/// [AppStore] instances simulates "the same machine/user" (second instance
/// retrieves the same key); using a fresh map simulates a different
/// keychain (e.g. wrong machine, or a corrupted/inaccessible key).
class _FakeSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;

  static const MethodChannel _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
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
    tempDir = Directory.systemTemp.createTempSync('finanzgecko_store_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File storeFile() => File('${tempDir.path}/app-data.json');

  test('persisted store file is an encrypted envelope, not plaintext JSON', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();
    await store.addAccount(name: 'Girokonto', tag: 'giro', color: '#00c878');

    final onDisk = jsonDecode(await storeFile().readAsString());
    expect(onDisk, isA<Map>());
    expect(onDisk['nonce'], isA<String>());
    expect(onDisk['cipherText'], isA<String>());
    expect(onDisk['mac'], isA<String>());
    expect(jsonEncode(onDisk), isNot(contains('Girokonto')));
  });

  test('data survives across restarts using the same keychain-backed key', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    final first = AppStore(dataDirectory: tempDir);
    await first.ensureInitialized();
    await first.addAccount(name: 'Tagesgeld', tag: 'save', color: '#00c878');

    final second = AppStore(dataDirectory: tempDir);
    await second.ensureInitialized();

    expect(second.getAccounts().map((a) => a.name), contains('Tagesgeld'));
  });

  test('legacy plaintext file is read once, then transparently re-encrypted', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    tempDir.createSync(recursive: true);
    await storeFile().writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'baseCurrency': 'EUR',
        'defaultSubscriptionInterval': 'monthly',
        'accounts': [
          {
            'id': 1,
            'name': 'Altes Konto',
            'bank': '',
            'tag': 'giro',
            'currency': 'EUR',
            'color': '#00c878',
            'archived': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        'balances': [],
        'assets': [],
        'subscriptions': [],
        'ratesCache': {},
        'meta': {'nextAccountId': 2, 'nextBalanceId': 1, 'nextAssetId': 1, 'nextSubscriptionId': 1},
      }),
    );

    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();

    expect(store.getAccounts().map((a) => a.name), contains('Altes Konto'));

    final onDisk = jsonDecode(await storeFile().readAsString());
    expect(onDisk['nonce'], isA<String>());
    expect(onDisk['cipherText'], isA<String>());
  });

  test('a tampered envelope is quarantined and the store falls back to defaults', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    final first = AppStore(dataDirectory: tempDir);
    await first.ensureInitialized();
    await first.addAccount(name: 'Wird zerstoert', tag: 'giro', color: '#00c878');

    final envelope = jsonDecode(await storeFile().readAsString()) as Map<String, dynamic>;
    envelope['mac'] = base64Encode(List<int>.filled(16, 0)); // corrupt the auth tag
    await storeFile().writeAsString(jsonEncode(envelope));

    final second = AppStore(dataDirectory: tempDir);
    await second.ensureInitialized();

    expect(second.getAccounts(), isEmpty);
    final quarantined = tempDir.listSync().where((f) => f.path.contains('.unreadable-'));
    expect(quarantined, isNotEmpty);
  });
}
