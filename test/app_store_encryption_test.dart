import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
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
    tempDir = Directory.systemTemp.createTempSync('finanzgecko_store_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File storeFile() => File('${tempDir.path}/finanzgecko-data.json');
  File ratesFile() => File('${tempDir.path}/finanzgecko-rates.json');

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

  test('a non-envelope (plaintext) store file is quarantined, not adopted', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    tempDir.createSync(recursive: true);
    // A bare, unencrypted JSON blob is no longer a supported on-disk shape:
    // it must be preserved (quarantined) rather than silently trusted, and
    // the store starts from defaults.
    await storeFile().writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'baseCurrency': 'EUR',
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
        'meta': {'nextAccountId': 2, 'nextBalanceId': 1, 'nextAssetId': 1, 'nextSubscriptionId': 1},
      }),
    );

    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();

    expect(store.getAccounts(), isEmpty);
    final onDisk = jsonDecode(await storeFile().readAsString());
    expect(onDisk['cipherText'], isA<String>(), reason: 'store should have been rewritten as an envelope');
    final quarantined = tempDir.listSync().where((f) => f.path.contains('.unreadable-'));
    expect(quarantined, isNotEmpty);
  });

  test('cached rates go to a separate plaintext file, not the encrypted store', () async {
    final keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();

    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();
    await store.setCachedRate('USD_EUR_2026-01-31', 0.92);

    // Rates file exists, is readable plaintext JSON, and holds the rate.
    final rates = jsonDecode(await ratesFile().readAsString()) as Map<String, dynamic>;
    expect(rates['USD_EUR_2026-01-31'], 0.92);

    // A fresh store on the same dir reads the rate back.
    final reopened = AppStore(dataDirectory: tempDir);
    await reopened.ensureInitialized();
    expect(reopened.getCachedRate('USD_EUR_2026-01-31'), 0.92);
  });

  test('legacy in-store ratesCache is migrated into the standalone rates file', () async {
    // Build an encrypted store whose decrypted payload still carries an
    // in-database `ratesCache` (the pre-migration shape), using the same key
    // the store will read from the fake keychain.
    final cipher = AesGcm.with256bits();
    final key = await cipher.newSecretKey();
    final keyBytes = await key.extractBytes();
    final keychain = {'finanzgecko_dek': base64Encode(keyBytes)};
    _FakeSecureStorage(keychain).install();

    final payload = jsonEncode({
      'schemaVersion': 1,
      'baseCurrency': 'EUR',
      'accounts': [],
      'balances': [],
      'assets': [],
      'subscriptions': [],
      'ratesCache': {'CHF_EUR_2026-02-28': 1.04},
      'meta': {'nextAccountId': 1, 'nextBalanceId': 1, 'nextAssetId': 1, 'nextSubscriptionId': 1},
    });
    final box = await cipher.encrypt(utf8.encode(payload), secretKey: key);
    tempDir.createSync(recursive: true);
    await storeFile().writeAsString(
      jsonEncode({
        'v': 1,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );

    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();

    // The rate is readable, now lives in the standalone file, and has been
    // dropped from the (decrypted) database.
    expect(store.getCachedRate('CHF_EUR_2026-02-28'), 1.04);
    final rates = jsonDecode(await ratesFile().readAsString()) as Map<String, dynamic>;
    expect(rates['CHF_EUR_2026-02-28'], 1.04);
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
