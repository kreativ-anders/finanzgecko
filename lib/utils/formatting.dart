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

/// [value] is a plain percentage number (7.3, not 0.073); negative sign is
/// added automatically, positive sign is left to the caller (matches fmtMoney).
String fmtPercent(double value) => '${NumberFormat('#,##0.0', 'de_DE').format(value)}%';

/// Formats a number for prefilling an editable amount field: German grouping
/// and decimal separators (matching fmtMoney's look), trailing zeros trimmed.
/// Stays a plain numeric string (no currency symbol) so it round-trips
/// through [parseInputNumber].
String fmtInputNumber(double value) => NumberFormat('#,##0.##', 'de_DE').format(value);

/// Parses text typed into an amount field. Accepts German notation
/// ("1.234,56") as well as a bare decimal point ("1234.56", what older
/// versions of this app used to prefill fields with) so existing habits and
/// values keep working. A lone dot followed by exactly 3 digits is treated
/// as a thousands separator (financial amounts here never carry 3 decimal
/// places), not a decimal point.
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

Color colorFromHex(String hex) {
  var clean = hex.replaceFirst('#', '');
  if (clean.length == 6) clean = 'FF$clean';
  final value = int.tryParse(clean, radix: 16);
  return value != null ? Color(value) : const Color(0xFF00C878);
}

int daysSince(DateTime date) => DateTime.now().difference(date).inDays;
