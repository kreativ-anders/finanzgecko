import '../models/account.dart';
import '../models/balance.dart';

/// Builds a German-locale-friendly CSV of every recorded Kontostand — one row
/// per Konto+Monat — for spreadsheet analysis (Excel/Numbers). The delimiter
/// is ';' and decimals use a comma, matching the German defaults; fields that
/// contain the delimiter, a quote, or a newline are quoted per RFC 4180.
///
/// This is a deliberately lossy, read-only export (there is no CSV re-import) —
/// distinct from the JSON backup, which round-trips the full app state. Pass
/// [accounts] including archived ones so historical rows keep their names.
String buildBalancesCsv(List<Account> accounts, List<Balance> balances, {required String baseCurrency}) {
  final accountsById = {for (final a in accounts) a.id: a};
  final rows = [...balances]
    ..sort((a, b) {
      final byPeriod = a.period.compareTo(b.period);
      if (byPeriod != 0) return byPeriod;
      final an = accountsById[a.accountId]?.name ?? '';
      final bn = accountsById[b.accountId]?.name ?? '';
      return an.compareTo(bn);
    });

  String dec(double v, int decimals) => v.toStringAsFixed(decimals).replaceAll('.', ',');

  final buffer = StringBuffer()
    ..writeln(
      [
        'Monat',
        'Konto',
        'Bank',
        'Kontotyp',
        'Währung',
        'Betrag (Original)',
        'Kurs',
        'Betrag ($baseCurrency)',
      ].map(_csvField).join(';'),
    );
  for (final b in rows) {
    final acc = accountsById[b.accountId];
    buffer.writeln(
      [
        _csvField(b.period),
        _csvUserField(acc?.name ?? '(gelöscht)'),
        _csvUserField(acc?.bank ?? ''),
        _csvField(acc?.tag ?? ''),
        _csvField(b.currencyOriginal),
        _csvField(dec(b.amountOriginal, 2)),
        _csvField(dec(b.rate, 4)),
        _csvField(dec(b.amountBase, 2)),
      ].join(';'),
    );
  }
  return buffer.toString();
}

/// Quotes a CSV field only when it contains a delimiter, quote, or line break;
/// internal quotes are doubled.
String _csvField(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Same RFC-4180 quoting as [_csvField], plus a guard against CSV/spreadsheet
/// formula injection: if the value starts with `=`, `+`, `-`, or `@`,
/// spreadsheet apps (Excel/LibreOffice) read it as the start of a
/// formula/DDE command when the CSV is opened. Applied only to the free-text
/// columns a user (or an imported backup) fully controls — Konto-Name and
/// Bank — never to the app-generated numeric/enum columns (Kontotyp,
/// Währung, Beträge), whose legitimate values (e.g. a negative amount) must
/// stay unprefixed so spreadsheet formulas like SUM() keep working on them.
String _csvUserField(String value) {
  const triggerChars = '=+-@';
  final guarded = value.isNotEmpty && triggerChars.contains(value[0]) ? "'$value" : value;
  return _csvField(guarded);
}
