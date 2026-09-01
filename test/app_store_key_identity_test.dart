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
const String _appStoreFilename = 'finanzgecko-data-appstore.json';

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

  File appStoreFile() => File('${tempDir.path}${Platform.pathSeparator}$_appStoreFilename');

  Future<AppStore> openStore({bool appStoreChannel = false, bool ignoreForeignData = false}) async {
    final store = AppStore(
      dataDirectory: tempDir,
      appStoreChannel: appStoreChannel,
      ignoreForeignData: ignoreForeignData,
    );
    await store.ensureInitialized();
    return store;
  }

  List<String> siblingNames() => tempDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toList();

  /// Simulates a different machine: same folder, but a freshly generated
  /// key in the (fake) key store.
  void replaceMachineKey() => keychain.remove(_keyName);

  group('keyId im Envelope', () {
    test('wird geschrieben, ohne die Envelope-Version anzuheben', () async {
      final store = await openStore();
      await store.setBaseCurrency('CHF');

      final decoded = jsonDecode(await storeFile().readAsString()) as Map<String, dynamic>;
      expect(decoded['keyId'], isA<String>());
      expect(decoded['v'], 1, reason: 'Ein Versionsbump würde ältere App-Versionen die Datei nicht mehr lesen lassen');
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
      final siblings = siblingNames();
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

  // The two macOS builds share one container but not one key, so they must not share one file either —
  // dev/ai/persistence.md "Channel switch". Everything here runs on an injected channel flag, since
  // kIsMacAppStore is compile-time and always false under `flutter test`.
  group('Kanalwechsel zwischen DMG- und App-Store-Build', () {
    test('der Store-Build schreibt in eine eigene Datei und lässt die des anderen Kanals liegen', () async {
      final dmg = await openStore();
      await dmg.setBaseCurrency('CHF');
      final bytesBefore = await storeFile().readAsBytes();

      // The store build keeps its key in a different keychain, so it never finds the DMG build's.
      replaceMachineKey();

      final store = await openStore(appStoreChannel: true, ignoreForeignData: true);
      await store.setBaseCurrency('USD');

      expect(appStoreFile().existsSync(), isTrue, reason: 'Der Store-Build braucht eine eigene Datei');
      expect(await storeFile().readAsBytes(), bytesBefore, reason: 'Die Datei des anderen Kanals bleibt unberührt');
      expect(
        siblingNames().where((n) => n.contains('unreadable') || n.contains('foreign')),
        isEmpty,
        reason: 'Was nicht am eigenen Pfad liegt, wandert auch nicht in Quarantäne',
      );
    });

    test('ohne Zustimmung endet der erste Start des Store-Builds in ForeignKeyDataException', () async {
      final dmg = await openStore();
      await dmg.setBaseCurrency('CHF');
      replaceMachineKey();

      await expectLater(openStore(appStoreChannel: true), throwsA(isA<ForeignKeyDataException>()));
      expect(appStoreFile().existsSync(), isFalse, reason: 'Vor der Entscheidung des Nutzers wird nichts angelegt');
    });

    test('ein Backup-Import beim Start ersetzt den Umweg über eine leere App', () async {
      final dmg = await openStore();
      await dmg.setBaseCurrency('CHF');
      final backup = dmg.exportAllData();
      final bytesBefore = await storeFile().readAsBytes();
      replaceMachineKey();

      final store = await openStore(appStoreChannel: true, ignoreForeignData: true);
      await store.importAllData(backup);

      expect(store.baseCurrency, 'CHF');
      expect(await storeFile().readAsBytes(), bytesBefore, reason: 'Der Import fasst die fremde Datei nicht an');
    });

    test('eine Datei mit dem eigenen Schlüssel wird einmalig unter den neuen Namen übernommen', () async {
      // The case of a store build that ran before the channel-specific name existed: same key, classic name.
      final earlier = await openStore();
      await earlier.setBaseCurrency('NOK');

      final adopted = await openStore(appStoreChannel: true);

      expect(adopted.baseCurrency, 'NOK', reason: 'Die eigenen Daten dürfen bei der Umbenennung nicht verloren gehen');
      expect(storeFile().existsSync(), isTrue, reason: 'Kopieren, nicht verschieben — ältere Builds lesen den Namen');
    });

    test('der DMG-Build sichert eine fremde Datei am eigenen Pfad, bevor er leer startet', () async {
      final dmg = await openStore();
      await dmg.setBaseCurrency('CHF');
      replaceMachineKey();

      final restarted = await openStore(ignoreForeignData: true);

      expect(restarted.baseCurrency, 'EUR', reason: 'Der Neustart beginnt mit den Standardwerten');
      expect(
        siblingNames().where((n) => n.contains('.foreign-')),
        isNotEmpty,
        reason: 'Am eigenen Pfad wird überschrieben — vorher muss eine Kopie liegen',
      );
    });
  });
}
