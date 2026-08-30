import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'manual_rate_dialog.dart';

// INFO: dismissing without deciding yields RateFetchConsent.unset and persists nothing.
/// Asks once, when a foreign-currency amount actually needs a rate, whether api.frankfurter.dev may be called.
Future<RateFetchConsent> promptRateFetchConsent(
  BuildContext context, {
  required String from,
  required String to,
}) async {
  final result = await showDialog<RateFetchConsent>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Wechselkurse online abrufen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Für die Umrechnung von $from nach $to wird ein Wechselkurs benötigt. '
            'FinanzGecko kann ihn bei api.frankfurter.dev abrufen (EZB-Referenzkurse).',
          ),
          const SizedBox(height: 12),
          Text(
            'Dabei wird nur das Währungspaar und das Datum übertragen — keine Beträge, '
            'keine Kontodaten, nichts, was dich identifiziert. Abgerufene Kurse werden '
            'lokal zwischengespeichert.',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Ohne Abruf funktioniert alles weiter: FinanzGecko nutzt dann bereits '
            'gespeicherte Kurse und fragt dich sonst nach dem Kurs. Du kannst die '
            'Entscheidung jederzeit unter Einstellungen → Wechselkurse ändern.',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(RateFetchConsent.denied),
          child: noSelect(const Text('Nicht abrufen')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(RateFetchConsent.granted),
          child: noSelect(const Text('Kurse abrufen')),
        ),
      ],
    ),
  );
  return result ?? RateFetchConsent.unset;
}

/// The single rate-resolution path: consent if unset, then cache/network rate, then manual entry.
Future<double?> resolveRate(
  BuildContext context,
  AppState app, {
  required String from,
  required String to,
  required String dateISO,
}) async {
  if (from == to) return 1;

  if (app.rateFetchConsent == RateFetchConsent.unset) {
    final decision = await promptRateFetchConsent(context, from: from, to: to);
    if (decision != RateFetchConsent.unset) {
      await app.setRateFetchConsent(decision);
    }
    if (!context.mounted) return null;
  }

  final service = app.currencyService;
  final rate = (await service.getExchangeRate(from, to, dateISO))?.rate;
  if (rate != null) return rate;
  if (!context.mounted) return null;
  return promptManualRate(context, from: from, to: to, reason: service.lastFailure?.message);
}
