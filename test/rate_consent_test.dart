// Gherkin: gherkin/currency_exchange.feature
//
// Covers the exchange-rate-fetch opt-in (issue #16) — deliberately WITHOUT
// network access: only the gate (`AppStore.mayFetchRates`,
// `CurrencyService.getExchangeRate`) is tested, i.e. the decision *whether*
// a call may happen, not the call itself. Written after a case where it was
// unclear whether the gate or the HTTP request was the cause.
import 'dart:io';

import 'package:finanzgecko/constants.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/services/currency_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    _FakeSecureStorage({}).install();
    tempDir = await Directory.systemTemp.createTemp('finanzgecko-consent-');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<AppStore> openStore() async {
    final store = AppStore(dataDirectory: tempDir);
    await store.ensureInitialized();
    return store;
  }

  group('Zustimmung zum Kursabruf', () {
    test('Standard ist "unset" und zählt als nicht erlaubt', () async {
      final store = await openStore();
      expect(store.rateFetchConsent, RateFetchConsent.unset);
      expect(store.mayFetchRates, isFalse);
    });

    test('"granted" öffnet das Gate sofort, ohne Neuladen', () async {
      final store = await openStore();
      await store.setRateFetchConsent(RateFetchConsent.granted);
      // The actual point: the gate must drop immediately after setting it,
      // not only after a reload or app restart.
      expect(store.mayFetchRates, isTrue);
      expect(CurrencyService(store).mayFetchRates, isTrue);
    });

    test('"denied" schließt das Gate wieder', () async {
      final store = await openStore();
      await store.setRateFetchConsent(RateFetchConsent.granted);
      await store.setRateFetchConsent(RateFetchConsent.denied);
      expect(store.mayFetchRates, isFalse);
    });

    test('Entscheidung übersteht einen Neustart', () async {
      final first = await openStore();
      await first.setRateFetchConsent(RateFetchConsent.granted);

      final second = await openStore();
      expect(second.rateFetchConsent, RateFetchConsent.granted);
      expect(second.mayFetchRates, isTrue, reason: 'Nach dem Neustart darf die Zustimmung nicht verloren gehen');
    });

    test('Alte Datei ohne den Schlüssel ergibt "unset", nicht stillschweigend "granted"', () async {
      final store = await openStore();
      final json = store.exportAllData();
      expect(
        json.containsKey('rateFetchConsent'),
        isFalse,
        reason: 'Zustimmung ist kein Teil des Backups — sie gilt pro Installation',
      );
      expect(store.rateFetchConsent, RateFetchConsent.unset);
    });
  });

  group('CurrencyService respektiert das Gate', () {
    test('gleiche Währung braucht weder Zustimmung noch Netz', () async {
      final service = CurrencyService(await openStore());
      final result = await service.getExchangeRate('EUR', 'EUR', '2026-08-05');
      expect(result?.rate, 1);
      expect(result?.source, RateSource.identity);
      expect(service.lastFailure, isNull);
    });

    test('ohne Zustimmung und ohne Cache: kein Kurs, Grund "notAllowed"', () async {
      final service = CurrencyService(await openStore());
      final result = await service.getExchangeRate('USD', 'EUR', '2026-08-05');
      expect(result, isNull);
      expect(service.lastFailure, RateFailure.notAllowed);
    });

    test('ohne Zustimmung, aber mit Cache: gecachter Kurs, kein Netzaufruf', () async {
      final store = await openStore();
      await store.setCachedRate('USD_EUR_2026-08-05', 0.86843);
      final service = CurrencyService(store);
      final result = await service.getExchangeRate('USD', 'EUR', '2026-08-05');
      expect(result?.rate, 0.86843);
      expect(result?.source, RateSource.cache);
      expect(service.lastFailure, isNull, reason: 'Der Cache reicht, es liegt kein Fehler vor');
    });

    test('Erreichbarkeitsprüfung meldet null statt zu pingen, solange nicht erlaubt', () async {
      final service = CurrencyService(await openStore());
      expect(await service.isApiReachable(), isNull);
    });
  });
}
