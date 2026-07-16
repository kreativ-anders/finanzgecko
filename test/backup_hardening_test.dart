// Gherkin: gherkin/backup_restore.feature
import 'package:finanzgecko/data/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hardening for the backup export/import JSON contract at the [AppData] level
/// (no keychain needed). Store-level concerns — schema-version rejection,
/// encrypted round-trip — live in test/app_store_ops_test.dart.
void main() {
  const iso = '2026-01-15T00:00:00.000';

  Map<String, dynamic> fullBackup() => {
    'schemaVersion': 1,
    'baseCurrency': 'CHF',
    'accounts': [
      {
        'id': 1,
        'name': 'Girokonto',
        'bank': 'N26',
        'tag': 'Girokonto',
        'currency': 'EUR',
        'color': '#00C878',
        'archived': false,
        'createdAt': iso,
      },
    ],
    'balances': [
      {
        'id': 1,
        'accountId': 1,
        'period': '2026-01',
        'amountOriginal': 2500.0,
        'currencyOriginal': 'EUR',
        'rate': 1.0,
        'amountBase': 2500.0,
        'note': '',
        'enteredAt': iso,
      },
    ],
    'assets': [
      {'id': 1, 'name': 'MacBook', 'value': 1200.0, 'createdAt': iso, 'lastEvaluatedAt': iso},
    ],
    'subscriptions': [
      {
        'id': 1,
        'name': 'Gehalt',
        'interval': 'monthly',
        'amountOriginal': 3200.0,
        'currencyOriginal': 'EUR',
        'rate': 1.0,
        'amountBase': 3200.0,
        'createdAt': iso,
      },
    ],
  };

  test('a full backup round-trips through export -> import with every section intact', () {
    final parsed = AppData.fromDynamic(fullBackup())!;
    // Simulate: user exports, then re-imports the exported file.
    final reparsed = AppData.fromDynamic(parsed.toExportJson())!;
    expect(reparsed.baseCurrency, 'CHF');
    expect(reparsed.accounts.single.name, 'Girokonto');
    expect(reparsed.balances.single.amountBase, 2500.0);
    expect(reparsed.balances.single.period, '2026-01');
    expect(reparsed.assets.single.name, 'MacBook');
    expect(reparsed.subscriptions.single.interval, 'monthly');
  });

  test('one malformed balance does not cost the caller the rest of the backup', () {
    final backup = fullBackup();
    backup['balances'] = [
      ...(backup['balances'] as List),
      {'id': 2}, // missing required accountId/period -> skipped
      'not-a-map', // wrong type -> skipped
    ];
    final parsed = AppData.fromDynamic(backup)!;
    expect(parsed.balances, hasLength(1)); // the valid one survives
    expect(parsed.accounts, hasLength(1));
    expect(parsed.assets, hasLength(1));
    expect(parsed.subscriptions, hasLength(1));
  });

  test('unknown top-level keys are ignored, not fatal', () {
    final parsed = AppData.fromDynamic({...fullBackup(), 'somethingFromAnotherTool': 42})!;
    expect(parsed.accounts, hasLength(1));
  });

  test('a non-string baseCurrency falls back to EUR', () {
    final parsed = AppData.fromDynamic({...fullBackup(), 'baseCurrency': 123})!;
    expect(parsed.baseCurrency, 'EUR');
  });

  test('a missing schemaVersion defaults to the current version', () {
    final backup = fullBackup()..remove('schemaVersion');
    expect(AppData.fromDynamic(backup)!.schemaVersion, currentSchemaVersion);
  });
}
