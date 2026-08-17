// Gherkin: gherkin/data_security.feature
//
// Covers the key fingerprint (`keyId`) in the envelope and, above all, the
// case it exists for: a data file that belongs to a *different* installation.
// The dangerous part isn't detecting that — it's guaranteeing that nothing
// gets written or moved in that case, or a file synced via the cloud would
// get replaced by an empty one when opened on the second machine.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

const String _keyName = 'finanzgecko_dek';
const String _storeFilename = 'finanzgecko-data.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Map<String, String> keychain;

  setUp(() async {
    keychain = <String, String>{};
    _FakeSecureStorage(keychain).install();
    tempDir = await Directory.systemTemp.createTemp('finanzgecko-keyid-');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File storeFile() => File('${tempDir.path}${Platform.pathSeparator}$_storeFilename');

  Future<AppStore> openStore() async {
    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();
    return store;
  }

  /// Simulates a different machine: same folder, but a freshly generated
  /// key in the (fake) key store.
  void replaceMachineKey() => keychain.remove(_keyName);

  group('keyId im Envelope', () {
    test('wird geschrieben, ohne die Envelope-Version anzuheben', () async {
      final store = await openStore();
      await store.setBaseCurrency('CHF');

      final decoded = jsonDecode(await storeFile().readAsString()) as Map<String, dynamic>;
      expect(decoded['keyId'], isA<String>());
      expect(
        decoded['v'],
        1,
        reason: 'Ein Versionsbump würde ältere App-Versionen die Datei nicht mehr lesen lassen',
      );
      // Exactly the fields an older version knows about are still there, unchanged.
      expect(decoded.keys, containsAll(<String>['v', 'nonce', 'cipherText', 'mac']));
    });

    test('ist stabil über Neustarts hinweg, solange der Schlüssel derselbe ist', () async {
      final first = await openStore();
      await first.setBaseCurrency('CHF');
      final keyIdBefore = (jsonDecode(await storeFile().readAsString()) as Map)['keyId'];

      final second = await openStore();
      await second.setBaseCurrency('USD');
      final keyIdAfter = (jsonDecode(await storeFile().readAsString()) as Map)['keyId'];

      expect(keyIdAfter, keyIdBefore);
      expect(second.baseCurrency, 'USD');
    });
  });

  group('Datei von einem anderen Rechner', () {
    test('führt zu ForeignKeyDataException statt zu Quarantäne und Leerstart', () async {
      final store = await openStore();
      await store.setBaseCurrency('CHF');
      final bytesBefore = await storeFile().readAsBytes();

      replaceMachineKey();

      await expectLater(openStore(), throwsA(isA<ForeignKeyDataException>()));

      // The actual point of the feature: the file is left untouched.
      expect(await storeFile().readAsBytes(), bytesBefore, reason: 'Die Datei darf nicht überschrieben werden');
      final siblings = tempDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toList();
      expect(
        siblings.where((n) => n.contains('unreadable')),
        isEmpty,
        reason: 'Eine intakte fremde Datei darf nicht in Quarantäne wandern',
      );
    });

    test('lässt sich nach Rückkehr des ursprünglichen Schlüssels wieder öffnen', () async {
      final store = await openStore();
      await store.setBaseCurrency('CHF');
      final originalKey = keychain[_keyName];

      replaceMachineKey();
      await expectLater(openStore(), throwsA(isA<ForeignKeyDataException>()));

      keychain[_keyName] = originalKey!;
      final reopened = await openStore();
      expect(reopened.baseCurrency, 'CHF', reason: 'Nichts darf zwischenzeitlich zerstört worden sein');
    });
  });

  group('Rückwärtskompatibilität', () {
    test('Datei ohne keyId (vor diesem Feature geschrieben) wird normal geladen', () async {
      // First let a key be generated, then hand-write an envelope in the old
      // format — same key, but without keyId.
      final store = await openStore();
      await store.setBaseCurrency('CHF');
      final key = SecretKey(base64Decode(keychain[_keyName]!));

      final payload = jsonEncode({
        'schemaVersion': 1,
        'baseCurrency': 'NOK',
        'accounts': <dynamic>[],
        'balances': <dynamic>[],
        'assets': <dynamic>[],
        'subscriptions': <dynamic>[],
      });
      final box = await AesGcm.with256bits().encrypt(utf8.encode(payload), secretKey: key);
      await storeFile().writeAsString(
        jsonEncode({
          'v': 1,
          'nonce': base64Encode(box.nonce),
          'cipherText': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      );

      final legacy = await openStore();
      expect(legacy.baseCurrency, 'NOK');
    });

    test('keyFingerprint ist deterministisch und verrät den Schlüssel nicht', () async {
      final key = SecretKey(List<int>.filled(32, 7));
      final a = await AppStore.keyFingerprint(key);
      final b = await AppStore.keyFingerprint(key);
      expect(a, b);
      expect(base64Decode(a).length, 8);
      expect(a, isNot(contains(base64Encode(List<int>.filled(32, 7)))));

      final other = await AppStore.keyFingerprint(SecretKey(List<int>.filled(32, 8)));
      expect(other, isNot(a));
    });
  });
}
