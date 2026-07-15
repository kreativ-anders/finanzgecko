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
  final rows = [...balances]..sort((a, b) {
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
        b.period,
        acc?.name ?? '(gelöscht)',
        acc?.bank ?? '',
        acc?.tag ?? '',
        b.currencyOriginal,
        dec(b.amountOriginal, 2),
        dec(b.rate, 4),
        dec(b.amountBase, 2),
      ].map(_csvField).join(';'),
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
