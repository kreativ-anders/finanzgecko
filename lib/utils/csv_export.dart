import '../constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';

/// One file of the CSV export: its fixed file name and its content.
typedef CsvExportFile = ({String fileName, String content});

/// Builds the CSV export as one table per domain — Konten, Kontostände,
/// Fixposten, Vermögenswerte — instead of a single wide sheet.
///
/// Why split: the Konto master data (Bank, Kontotyp) belongs to the Konto, not
/// to the month, and repeating it in every monthly row is what made the old
/// single-file export awkward to pivot. `Konto-ID` is the join column between
/// Konten and Kontostände; it survives two Konten sharing a name, which the
/// name alone does not.
///
/// Deliberately narrow: every amount appears exactly once, in the currency it
/// was entered in — no rate, no converted second amount, no derived column.
/// Everything the receiving spreadsheet can do itself (monthly equivalents,
/// sums, currency conversion) stays out, so each table reads like the view it
/// comes from. Also lossy and read-only — there is no CSV re-import, the JSON
/// backup is the only round-trip. See dev/ai/state-and-models.md.
///
/// Pass [accounts] including archived ones so historical rows keep their names.
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

/// Konto master data — one row per Konto, sorted by name like the Konten view.
/// Archived Konten are included (their historical Kontostände would otherwise
/// point at nothing) but not marked as such.
String buildAccountsCsv(List<Account> accounts) {
  final rows = [...accounts]..sort((a, b) => a.name.compareTo(b.name));
  final buffer = StringBuffer()..writeln(_row(['Konto-ID', 'Konto', 'Bank', 'Kontotyp']));
  for (final a in rows) {
    buffer.writeln(_row(['${a.id}', _guarded(a.name), _guarded(a.bank), a.tag]));
  }
  return buffer.toString();
}

/// The recorded Kontostände — one row per Konto and Monat, sorted by Monat,
/// then Konto name. Master data lives in [buildAccountsCsv]; what stays here is
/// what actually varies per month. The Betrag is the amount as entered, in the
/// Konto's own currency — see the currency caveat on [buildCsvExports].
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
        // Keeps an orphaned row readable instead of dropping it; the ID column
        // still points at the Konto that once was.
        _guarded(acc?.name ?? '(gelöscht)'),
        b.currencyOriginal,
        _dec(b.amountOriginal, 2),
      ]),
    );
  }
  return buffer.toString();
}

/// Fixposten — Einnahmen first, then Ausgaben, each sorted by name, mirroring
/// the Fixposten view. The Betrag is per [Subscription.interval], not per
/// month: converting the intervals into a comparable monthly figure is the
/// app's job (`AppState.monthlyEquivalent`), and a spreadsheet that needs it
/// can derive it from the Intervall column.
String buildSubscriptionsCsv(List<Subscription> subscriptions) {
  final income = subscriptions.where((s) => s.amountOriginal > 0).toList()..sort((a, b) => a.name.compareTo(b.name));
  final expense = subscriptions.where((s) => s.amountOriginal <= 0).toList()..sort((a, b) => a.name.compareTo(b.name));

  final buffer = StringBuffer()..writeln(_row(['Fixposten', 'Art', 'Intervall', 'Währung', 'Betrag']));
  for (final s in [...income, ...expense]) {
    buffer.writeln(
      _row([
        _guarded(s.name),
        // Redundant with the sign of the amount, on purpose: it makes the CSV
        // filterable/pivotable without writing a formula first.
        s.amountOriginal > 0 ? 'Einnahme' : 'Ausgabe',
        intervalLabel(s.interval),
        s.currencyOriginal,
        _dec(s.amountOriginal, 2),
      ]),
    );
  }
  return buffer.toString();
}

/// Vermögenswerte — one row per Sachwert, sorted by name like the
/// Vermögenswerte view. Sachwerte carry no own currency, so their value is
/// always the base currency.
String buildAssetsCsv(List<Asset> assets, {required String baseCurrency}) {
  final rows = [...assets]..sort((a, b) => a.name.compareTo(b.name));
  final buffer = StringBuffer()..writeln(_row(['Vermögenswert', 'Wert ($baseCurrency)']));
  for (final a in rows) {
    buffer.writeln(_row([_guarded(a.name), _dec(a.value, 2)]));
  }
  return buffer.toString();
}

/// Joins one row, quoting each field per RFC 4180 where needed. Delimiter is
/// ';' and decimals use a comma, matching the German defaults.
String _row(List<String> fields) => fields.map(_csvField).join(';');

String _dec(double value, int decimals) => value.toStringAsFixed(decimals).replaceAll('.', ',');

/// Quotes a CSV field only when it contains a delimiter, quote, or line break;
/// internal quotes are doubled.
String _csvField(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Guards against CSV/spreadsheet formula injection: if the value starts with
/// `=`, `+`, `-`, or `@`, spreadsheet apps (Excel/LibreOffice) read it as the
/// start of a formula/DDE command when the CSV is opened, so a leading `'`
/// neutralizes it. Applied only to the free-text columns a user (or an
/// imported backup) fully controls — Konto-Name, Bank, Fixposten- und
/// Vermögenswert-Name — never to the app-generated numeric/enum columns
/// (Kontotyp, Intervall, Währung, Beträge), whose legitimate values (e.g. a
/// negative amount) must stay unprefixed so spreadsheet formulas like SUM()
/// keep working on them. Quoting itself happens once, in [_csvField] via [_row].
String _guarded(String value) {
  const triggerChars = '=+-@';
  return value.isNotEmpty && triggerChars.contains(value[0]) ? "'$value" : value;
}
