// Gherkin: gherkin/data_security.feature
import 'package:finanzgecko/data/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _account(int id, {String name = 'Konto'}) => {
  'id': id,
  'name': name,
  'bank': '',
  'tag': 'giro',
  'currency': 'EUR',
  'color': '#00c878',
  'archived': false,
  'createdAt': DateTime.now().toIso8601String(),
};

void main() {
  group('AppData.fromDynamic', () {
    test('returns null for non-map input', () {
      expect(AppData.fromDynamic('nope'), isNull);
      expect(AppData.fromDynamic(<dynamic>[]), isNull);
      expect(AppData.fromDynamic(null), isNull);
    });

    test('fills defaults for an empty map', () {
      final data = AppData.fromDynamic(<String, dynamic>{})!;
      expect(data.baseCurrency, 'EUR');
      expect(data.accounts, isEmpty);
      expect(data.schemaVersion, currentSchemaVersion);
      expect(data.nextAccountId, 1);
    });

    test('skips malformed list entries but keeps valid ones', () {
      final data = AppData.fromDynamic({
        'accounts': [
          _account(1, name: 'Gut'),
          {'name': 'Kein-ID'}, // missing required id -> skipped
          'not-a-map', // wrong type -> skipped
        ],
      })!;
      expect(data.accounts.map((a) => a.name), ['Gut']);
    });

    test('reads id counters from the meta block', () {
      final data = AppData.fromDynamic({
        'meta': {'nextAccountId': 7, 'nextBalanceId': 3},
      })!;
      expect(data.nextAccountId, 7);
      expect(data.nextBalanceId, 3);
    });

    test('parses only numeric legacy ratesCache entries', () {
      final data = AppData.fromDynamic({
        'ratesCache': {'USD_EUR_2025-01-31': 0.92, 'bad': 'x'},
      })!;
      expect(data.ratesCache['USD_EUR_2025-01-31'], 0.92);
      expect(data.ratesCache.containsKey('bad'), isFalse);
    });
  });

  group('serialization', () {
    test('toJson no longer embeds the rate cache', () {
      final data = AppData.defaults()..ratesCache['USD_EUR'] = 0.9;
      expect(data.toJson().containsKey('ratesCache'), isFalse);
    });

    test('toExportJson excludes internal-only state', () {
      final json = AppData.defaults().toExportJson();
      expect(json.containsKey('meta'), isFalse);
      expect(json.containsKey('window'), isFalse);
      expect(json.containsKey('ratesCache'), isFalse);
      expect(json.containsKey('exportedAt'), isTrue);
      expect(json.containsKey('accounts'), isTrue);
    });

    test('toExportJson omits the derived account color, keeping bank + tag', () {
      final parsed = AppData.fromDynamic({
        'accounts': [_account(1)], // _account carries a color
      })!;
      final acc = (parsed.toExportJson()['accounts'] as List).single as Map;
      expect(acc.containsKey('color'), isFalse, reason: 'color is derived from the bank on import');
      expect(acc.containsKey('bank'), isTrue);
      expect(acc.containsKey('tag'), isTrue);
    });

    test('round-trips accounts through toJson -> fromDynamic', () {
      final original = AppData.defaults();
      final parsed = AppData.fromDynamic({
        ...original.toJson(),
        'accounts': [_account(5, name: 'Wieder da')],
      })!;
      expect(parsed.accounts.single.id, 5);
      expect(parsed.accounts.single.name, 'Wieder da');
    });
  });
}
