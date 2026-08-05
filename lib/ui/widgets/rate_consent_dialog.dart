import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'manual_rate_dialog.dart';

/// Asks once, at the moment a foreign-currency amount actually needs a rate,
/// whether the app may contact api.frankfurter.dev.
///
/// Shown only from the two places that genuinely need a rate (Einträge and
/// Fixposten while saving) — never from merely opening a view, and never from
/// Einstellungen, where a surprise dialog would be baffling. The decision is
/// stored and can be reversed under Einstellungen → Wechselkurse.
///
/// Returns the user's choice, or [RateFetchConsent.unset] if the dialog was
/// dismissed without deciding — the caller then treats it as "not now" and
/// falls back to the manual rate, without persisting anything.
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

/// The single rate-resolution path for every screen that stores a
/// foreign-currency amount (Einträge, Fixposten anlegen/bearbeiten).
///
/// Order: ask for consent if that has never happened *and* a foreign currency
/// is actually involved → try [CurrencyService.getExchangeRate] (network only
/// when granted, local cache always) → fall back to a manually entered rate.
/// Returns null if the user cancels the manual dialog too; callers treat that
/// exactly as before, i.e. "not saved".
///
/// Same-currency amounts never trigger the question — nothing has to be
/// converted, so there is nothing to ask about.
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
    // Dismissed without choosing: don't persist anything, just continue on the
    // offline path. The question comes back the next time a rate is needed.
    if (decision != RateFetchConsent.unset) {
      await app.setRateFetchConsent(decision);
    }
    if (!context.mounted) return null;
  }

  final rate = (await app.currencyService.getExchangeRate(from, to, dateISO))?.rate;
  if (rate != null) return rate;
  if (!context.mounted) return null;
  return promptManualRate(context, from: from, to: to);
}
