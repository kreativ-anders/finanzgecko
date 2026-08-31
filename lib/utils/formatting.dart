import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';

String fmtMoney(double value, String currency) {
  try {
    return NumberFormat.simpleCurrency(locale: 'de_DE', name: currency).format(value);
  } catch (_) {
    return '${value.toStringAsFixed(2)} $currency';
  }
}

/// [value] is a plain percentage number (7.3, not 0.073); a positive sign is left to the caller.
String fmtPercent(double value) => '${NumberFormat('#,##0.0', 'de_DE').format(value)}%';

/// [fmtMoney] with an explicit leading "+" for non-negative values, so a delta reads unambiguously.
String fmtSignedMoney(double value, String currency) => '${value >= 0 ? '+' : ''}${fmtMoney(value, currency)}';

/// [fmtMoney] rounded to whole currency units, for estimates where cents would be false precision.
String fmtMoneyRounded(double value, String currency) {
  try {
    return NumberFormat.simpleCurrency(locale: 'de_DE', name: currency, decimalDigits: 0).format(value);
  } catch (_) {
    return '${value.toStringAsFixed(0)} $currency';
  }
}

/// [fmtMoneyRounded] with an explicit leading "+" for non-negative values.
String fmtSignedMoneyRounded(double value, String currency) =>
    '${value >= 0 ? '+' : ''}${fmtMoneyRounded(value, currency)}';

/// Formats a number for prefilling an editable amount field, so it round-trips through [parseInputNumber].
String fmtInputNumber(double value) => NumberFormat('#,##0.##', 'de_DE').format(value);

/// Parses text typed into an amount field: German notation ("1.234,56") and a bare "1234.56".
// INFO: a lone dot before exactly 3 digits is a thousands separator — amounts here never have 3 decimals.
double? parseInputNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains(',')) {
    return double.tryParse(trimmed.replaceAll('.', '').replaceAll(',', '.'));
  }
  final dotParts = trimmed.split('.');
  if (dotParts.length > 1 && dotParts.last.length == 3) {
    return double.tryParse(dotParts.join());
  }
  return double.tryParse(trimmed);
}

/// Splits an arithmetic expression into number/operator tokens for [evaluateInputExpression].
/// A `-` counts as part of a number (a sign) at the start or right after another operator, and as the
/// binary minus operator everywhere else. Returns null for any character outside `[0-9.,+\-*/ ]`.
List<String>? _tokenizeExpression(String trimmed) {
  final tokens = <String>[];
  final buf = StringBuffer();
  var expectOperand = true;
  for (var i = 0; i < trimmed.length; i++) {
    final c = trimmed[i];
    if (c == ' ' || c == '\t') continue;
    final isBinaryOperator = (c == '+' || c == '*' || c == '/' || c == '-') && !expectOperand;
    if (isBinaryOperator) {
      if (buf.isEmpty) return null;
      tokens.add(buf.toString());
      tokens.add(c);
      buf.clear();
      expectOperand = true;
    } else if (c == '-' && expectOperand) {
      buf.write(c);
    } else if (RegExp(r'[0-9.,]').hasMatch(c)) {
      buf.write(c);
      expectOperand = false;
    } else {
      return null;
    }
  }
  if (buf.isEmpty) return null;
  tokens.add(buf.toString());
  return tokens;
}

/// Evaluates a simple arithmetic expression typed into an amount field (e.g. "1300,12 +5201.75"), so
/// several sub-amounts (e.g. depot + cash of the same broker) can be combined into one Kontostand without
/// a separate calculator. Operands use [parseInputNumber]'s notation; `*`/`/` bind tighter than `+`/`-`,
/// evaluated left to right within each precedence level (no parentheses). A superset of [parseInputNumber]:
/// a plain number with no operator evaluates the same as calling that directly.
/// Returns null for anything that isn't a valid expression (stray characters, an unparseable operand, a
/// dangling operator, or division by zero) — the caller must not silently save 0 or a garbage result.
double? evaluateInputExpression(String raw) {
  final tokens = _tokenizeExpression(raw.trim());
  if (tokens == null) return null;

  final numbers = <double>[];
  final operators = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    if (i.isEven) {
      final n = parseInputNumber(tokens[i]);
      if (n == null) return null;
      numbers.add(n);
    } else {
      operators.add(tokens[i]);
    }
  }

  // Pass 1: fold * and / into the running operand, left to right.
  final terms = <double>[numbers.first];
  final termOperators = <String>[];
  for (var i = 0; i < operators.length; i++) {
    final op = operators[i];
    final next = numbers[i + 1];
    if (op == '*' || op == '/') {
      if (op == '/' && next == 0) return null;
      final last = terms.removeLast();
      terms.add(op == '*' ? last * next : last / next);
    } else {
      termOperators.add(op);
      terms.add(next);
    }
  }

  // Pass 2: fold + and - left to right.
  var result = terms.first;
  for (var i = 0; i < termOperators.length; i++) {
    result = termOperators[i] == '+' ? result + terms[i + 1] : result - terms[i + 1];
  }
  return result;
}

/// "2025-03" -> "Mär 2025"
String periodLabel(String period) {
  final parts = period.split('-');
  final month = int.parse(parts[1]);
  return '${kMonthLabels[month - 1]} ${parts[0]}';
}

/// Last calendar day of "YYYY-MM" as "YYYY-MM-DD".
String lastDayOfMonthISO(String period) {
  final parts = period.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final lastDay = DateTime.utc(year, month + 1, 0);
  return lastDay.toIso8601String().substring(0, 10);
}

String currentPeriod() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String todayISO() => DateTime.now().toIso8601String().substring(0, 10);

/// German day.month.year, e.g. "03.06.2026" — the app-wide date display format.
String fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

Color? _tryColorFromHex(String hex) {
  var clean = hex.replaceFirst('#', '');
  if (clean.length == 6) clean = 'FF$clean';
  final value = int.tryParse(clean, radix: 16);
  return value != null ? Color(value) : null;
}

/// Falls back to the app's primary brand color ([kPrimaryHex]) for unparseable input.
Color colorFromHex(String hex) => _tryColorFromHex(hex) ?? _tryColorFromHex(kPrimaryHex)!;

int daysSince(DateTime date) => DateTime.now().difference(date).inDays;
