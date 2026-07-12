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
