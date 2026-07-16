// Generates a realistic demo backup (`demo/finanzgecko-demo.json`) that can be
// imported via "Backup importieren…" to populate the app for screenshots.
//
//   dart run tool/generate_demo_data.dart
//
// The dataset is anchored to the CURRENT month (19 months of history back from
// today) so it always looks current — no stale months, no update-reminder.
// The committed `demo/finanzgecko-demo.json` is one such run (anchored to
// 2026-07). Shape matches the backup/import format (see templates/README.md).
//
// The data-building is a pure function [buildDemoBackup] so it can be validated
// by `flutter test` (see test/tooling_test.dart) — the CLI only writes it out.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Builds the demo backup map (same shape as a "Backup exportieren"). [now]
/// anchors the most recent month; defaults to the real current month.
Map<String, dynamic> buildDemoBackup({DateTime? now}) {
  final ref = now ?? DateTime.now();
  final periods = [for (var i = 18; i >= 0; i--) DateTime(ref.year, ref.month - i, 1)];

  String pkey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  String lastDayIso(DateTime d) {
    final lastDay = DateTime(d.year, d.month + 1, 0).day;
    return '${pkey(d)}-${lastDay.toString().padLeft(2, '0')}T18:00:00.000';
  }

  final created = DateTime(periods.first.year, periods.first.month - 1, 20).toIso8601String();
  final recentEval = lastDayIso(DateTime(ref.year, ref.month - 1, 1));
  double r2(double v) => (v * 100).roundToDouble() / 100;
  double noise(int i, double amp, double phase) => amp * sin(i * 1.3 + phase);

  // Real kBanks entries so the import derives each bank's brand color (DKB blau,
  // ING orange, Trade Republic schwarz, …); Krypto/Bargeld have no institution
  // and fall back to the Kontotyp color. No `color` here — like a real backup,
  // it's derived on import (see Account.toExportJson / resolveAccountColor).
  final accountsMeta = [
    {'id': 1, 'name': 'Girokonto', 'bank': 'DKB', 'tag': 'Girokonto', 'currency': 'EUR'},
    {'id': 2, 'name': 'Tagesgeld', 'bank': 'ING', 'tag': 'Tagesgeld', 'currency': 'EUR'},
    {'id': 3, 'name': 'ETF-Depot', 'bank': 'Scalable Capital', 'tag': 'Depot', 'currency': 'EUR'},
    {'id': 4, 'name': 'US-Aktien', 'bank': 'Trade Republic', 'tag': 'Depot', 'currency': 'USD'},
    {'id': 5, 'name': 'Krypto', 'bank': '', 'tag': 'Krypto', 'currency': 'EUR'},
    {'id': 6, 'name': 'Bargeld', 'bank': '', 'tag': 'Bargeld', 'currency': 'EUR'},
  ];
  final accounts = <Map<String, dynamic>>[
    for (final m in accountsMeta) {...m, 'archived': false, 'createdAt': created},
  ];

  // Deterministic trajectories over the 19-month index (0..18).
  double giro(int i) => 2600 + noise(i, 350, 1) + 20 * i;
  double tagesgeld(int i) => 9000 + 620 * i + noise(i, 250, 2);
  double depot(int i) {
    final base = 16000 + 780 * i;
    final dip = (i == 5 || i == 6) ? -0.11 * base : (i == 7 ? -0.05 * base : 0.0);
    return base + dip + noise(i, 300, 3);
  }

  double usOrig(int i) {
    final base = 6000 + 300 * i;
    final dip = (i == 5 || i == 6) ? -0.12 * base : 0.0;
    return base + dip + noise(i, 180, 1);
  }

  double usRate(int i) => 0.94 - 0.0022 * i + 0.004 * sin(i * 0.9); // USD->EUR, ~0.90–0.94
  const kryptoVals = [
    3500, 4200, 3900, 5200, 6100, 5200, 4300, 4800, 6400, 7200, //
    6600, 7800, 8600, 7400, 8200, 9100, 8700, 9600, 10400,
  ];
  double bargeld(int i) => 480 + noise(i, 120, 0);

  final balances = <Map<String, dynamic>>[];
  var bid = 1;
  for (var i = 0; i < periods.length; i++) {
    final per = pkey(periods[i]);
    final ent = lastDayIso(periods[i]);
    void add(int accId, double amountOriginal, double rate) {
      final currency = accounts[accId - 1]['currency'] as String;
      final roundedRate = r2(rate);
      balances.add({
        'id': bid++,
        'accountId': accId,
        'period': per,
        'amountOriginal': r2(amountOriginal),
        'currencyOriginal': currency,
        'rate': roundedRate,
        // Kept consistent with the stored (rounded) rate: amountBase = amountOriginal × rate.
        'amountBase': r2(r2(amountOriginal) * roundedRate),
        'note': '',
        'enteredAt': ent,
      });
    }

    add(1, giro(i), 1);
    add(2, tagesgeld(i), 1);
    add(3, depot(i), 1);
    add(4, usOrig(i), usRate(i));
    add(5, kryptoVals[i].toDouble(), 1);
    add(6, bargeld(i), 1);
  }

  final assets = <Map<String, dynamic>>[
    {'id': 1, 'name': 'VW Golf', 'value': 12500.0, 'createdAt': created, 'lastEvaluatedAt': recentEval},
    {'id': 2, 'name': 'MacBook Pro', 'value': 1750.0, 'createdAt': created, 'lastEvaluatedAt': recentEval},
    {'id': 3, 'name': 'E-Bike', 'value': 2200.0, 'createdAt': created, 'lastEvaluatedAt': recentEval},
  ];

  final subs = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Gehalt', 'interval': 'monthly', 'amountOriginal': 3400.0},
    {'id': 2, 'name': 'Miete', 'interval': 'monthly', 'amountOriginal': -1250.0},
    {'id': 3, 'name': 'Krankenversicherung', 'interval': 'monthly', 'amountOriginal': -280.0},
    {'id': 4, 'name': 'Strom & Internet', 'interval': 'monthly', 'amountOriginal': -95.0},
    {'id': 5, 'name': 'Handyvertrag', 'interval': 'monthly', 'amountOriginal': -29.0},
    {'id': 6, 'name': 'Fitnessstudio', 'interval': 'monthly', 'amountOriginal': -39.0},
    {'id': 7, 'name': 'Streaming-Abos', 'interval': 'monthly', 'amountOriginal': -32.0},
    {'id': 8, 'name': 'Dividende ETF', 'interval': 'quarterly', 'amountOriginal': 140.0},
  ];
  for (final s in subs) {
    s['currencyOriginal'] = 'EUR';
    s['rate'] = 1.0;
    s['amountBase'] = s['amountOriginal'];
    s['createdAt'] = created;
  }

  return {
    'schemaVersion': 1,
    'exportedAt': ref.toIso8601String(),
    'baseCurrency': 'EUR',
    'accounts': accounts,
    'balances': balances,
    'assets': assets,
    'subscriptions': subs,
  };
}

void main() {
  final backup = buildDemoBackup();
  final file = File('demo/finanzgecko-demo.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(backup));
  final balances = backup['balances'] as List;
  stdout.writeln('Wrote ${file.path} — ${balances.length} Kontostände.');
}
