import '../constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';

/// One file of the CSV export: its fixed file name and its content.
typedef CsvExportFile = ({String fileName, String content});

/// Builds the CSV export as one table per domain; pass [accounts] including archived ones.
// INFO: deliberately narrow, lossy and without re-import — the rationale is in dev/ai/analysis.md.
List<CsvExportFile> buildCsvExports({
  required List<Account> accounts,
  required List<Balance> balances,
  required List<Subscription> subscriptions,
  required List<Asset> assets,
  required String baseCurrency,
  required String dateStamp,
}) => [
  (fileName: 'finanzgecko-konten-$dateStamp.csv', content: buildAccountsCsv(accounts)),
  (fileName: 'finanzgecko-kontostaende-$dateStamp.csv', content: buildBalancesCsv(accounts, balances)),
  (fileName: 'finanzgecko-fixposten-$dateStamp.csv', content: buildSubscriptionsCsv(subscriptions)),
  (fileName: 'finanzgecko-vermoegenswerte-$dateStamp.csv', content: buildAssetsCsv(assets, baseCurrency: baseCurrency)),
];

/// Konto master data, one row per Konto sorted by name; archived Konten are included but not marked.
String buildAccountsCsv(List<Account> accounts) {
  final rows = [...accounts]..sort((a, b) => a.name.compareTo(b.name));
  final buffer = StringBuffer()..writeln(_row(['Konto-ID', 'Konto', 'Bank', 'Kontotyp']));
  for (final a in rows) {
    buffer.writeln(_row(['${a.id}', _guarded(a.name), _guarded(a.bank), a.tag]));
  }
  return buffer.toString();
}

/// The recorded Kontostände, one row per Konto and Monat; Betrag is as entered, in the Konto's currency.
String buildBalancesCsv(List<Account> accounts, List<Balance> balances) {
  final accountsById = {for (final a in accounts) a.id: a};
  final rows = [...balances]
    ..sort((a, b) {
      final byPeriod = a.period.compareTo(b.period);
      if (byPeriod != 0) return byPeriod;
      final an = accountsById[a.accountId]?.name ?? '';
      final bn = accountsById[b.accountId]?.name ?? '';
      return an.compareTo(bn);
    });

  final buffer = StringBuffer()..writeln(_row(['Monat', 'Konto-ID', 'Konto', 'Währung', 'Betrag']));
  for (final b in rows) {
    final acc = accountsById[b.accountId];
    buffer.writeln(
      _row([
        b.period,
        '${b.accountId}',
        // Keeps an orphaned row readable; the ID column still points at the Konto that once was.
        _guarded(acc?.name ?? '(gelöscht)'),
        b.currencyOriginal,
        _dec(b.amountOriginal, 2),
      ]),
    );
  }
  return buffer.toString();
}

/// Fixposten — Einnahmen first, then Ausgaben, each sorted by name.
// INFO: Betrag is per interval, not per month; the Intervall column lets a spreadsheet derive the monthly figure.
String buildSubscriptionsCsv(List<Subscription> subscriptions) {
  final income = subscriptions.where((s) => s.amountOriginal > 0).toList()..sort((a, b) => a.name.compareTo(b.name));
  final expense = subscriptions.where((s) => s.amountOriginal <= 0).toList()..sort((a, b) => a.name.compareTo(b.name));

  final buffer = StringBuffer()..writeln(_row(['Fixposten', 'Art', 'Intervall', 'Währung', 'Betrag']));
  for (final s in [...income, ...expense]) {
    buffer.writeln(
      _row([
        _guarded(s.name),
        // Redundant with the amount's sign on purpose: it makes the CSV filterable without a formula first.
        s.amountOriginal > 0 ? 'Einnahme' : 'Ausgabe',
        intervalLabel(s.interval),
        s.currencyOriginal,
        _dec(s.amountOriginal, 2),
      ]),
    );
  }
  return buffer.toString();
}

/// Vermögenswerte, one row per Sachwert sorted by name; Sachwerte carry no own currency.
String buildAssetsCsv(List<Asset> assets, {required String baseCurrency}) {
  final rows = [...assets]..sort((a, b) => a.name.compareTo(b.name));
  final buffer = StringBuffer()..writeln(_row(['Vermögenswert', 'Wert ($baseCurrency)']));
  for (final a in rows) {
    buffer.writeln(_row([_guarded(a.name), _dec(a.value, 2)]));
  }
  return buffer.toString();
}

/// Joins one row, quoting per RFC 4180; the ';' delimiter and decimal comma match the German defaults.
String _row(List<String> fields) => fields.map(_csvField).join(';');

String _dec(double value, int decimals) => value.toStringAsFixed(decimals).replaceAll('.', ',');

/// Quotes a CSV field only when it contains a delimiter, quote or line break; internal quotes are doubled.
String _csvField(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Prefixes a leading `=`, `+`, `-` or `@` with `'` so a spreadsheet cannot read the value as a formula.
// WARNING: free-text columns only — prefixing the numeric columns would break SUM() on negative amounts.
String _guarded(String value) {
  const triggerChars = '=+-@';
  return value.isNotEmpty && triggerChars.contains(value[0]) ? "'$value" : value;
}
