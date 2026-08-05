import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/app_store.dart';

/// Where a rate came from — mirrors the "Quelle" wording in
/// `gherkin/currency_exchange.feature`.
enum RateSource { identity, live, cache }

class RateResult {
  final double rate;
  final RateSource source;

  const RateResult({required this.rate, required this.source});
}

/// Why no rate could be produced.
///
/// Exists because every failure used to collapse into a bare `null`, so the
/// manual-rate dialog claimed "(offline?)" even when the real cause was a
/// missing opt-in or a rejected response — undiagnosable from the outside.
/// [message] sitzt bewusst **im Enum** und nicht in einer Extension: eine
/// Extension ist nur sichtbar, wo ihre Datei direkt importiert wird, und der
/// einzige Aufrufer (`ui/widgets/rate_consent_dialog.dart`) kennt den Typ nur
/// indirekt über `AppState`. Als Enum-Getter funktioniert es überall.
enum RateFailure {
  /// Rate lookups aren't allowed (opt-in `unset`/`denied`) and nothing cached.
  notAllowed(
    'Der Online-Abruf von Wechselkursen ist nicht erlaubt (Einstellungen → Wechselkurse), '
        'und für dieses Währungspaar liegt kein gespeicherter Kurs vor.',
  ),

  /// Allowed, but the request failed (no connection, timeout, HTTP error,
  /// unparsable answer) and nothing cached.
  requestFailed(
    'Der Wechselkurs konnte nicht abgerufen werden (keine Verbindung oder Störung der API), '
        'und für dieses Währungspaar liegt kein gespeicherter Kurs vor.',
  );

  const RateFailure(this.message);

  /// Shown to the user above the manual-rate field.
  final String message;
}

/// Exchange rates via the free Frankfurter.app API (ECB reference rates).
/// Rates are cached in the app store so the app keeps working offline with
/// the last known rate.
class CurrencyService {
  CurrencyService(this._store);

  final AppStore _store;
  static const _apiBase = 'https://api.frankfurter.dev/v1';

  /// How long a live rate lookup waits before falling back to the cache —
  /// governs how long entries_view/subscriptions_view block on a slow or
  /// unreachable connection before offering the offline/manual-rate path.
  static const _requestTimeout = Duration(seconds: 10);

  String _cacheKey(String from, String to, String dateStr) => '${from}_${to}_$dateStr';

  /// Whether the user has allowed rate lookups (Einstellungen → Wechselkurse,
  /// asked once at the first real rate need). Read through here so callers
  /// have a single source of truth.
  bool get mayFetchRates => _store.mayFetchRates;

  /// Live reachability probe for Einstellungen → "Hilfe" (debug info) —
  /// separate from [getExchangeRate]'s cache-fallback path so it reflects
  /// the connection right now rather than "was there ever a successful call".
  /// Hits the cheapest endpoint (currency list, no params) with a short
  /// timeout instead of reusing a real conversion request.
  ///
  /// Returns null when the abruf hasn't been allowed — the caller then shows
  /// "nicht geprüft" instead of a misleading "nicht erreichbar". This probe is
  /// never triggered by merely opening a view; Einstellungen → Hilfe renders
  /// the stored state and only calls this from an explicit button.
  Future<bool?> isApiReachable({Duration timeout = const Duration(seconds: 3)}) async {
    if (!mayFetchRates) return null;
    try {
      final res = await http.get(Uri.parse('$_apiBase/currencies')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Last reason [getExchangeRate] came back empty, for the manual-rate dialog.
  ///
  /// Diagnostic only — set on every failing lookup and never read for control
  /// flow. Safe because rate lookups happen strictly sequentially inside one
  /// save operation (see `resolveRate`), which reads it immediately after.
  RateFailure? lastFailure;

  /// dateStr must be "YYYY-MM-DD". Returns null only if neither the API nor
  /// the cache can supply a rate; [lastFailure] then says why and the caller
  /// asks the user for a manual rate.
  Future<RateResult?> getExchangeRate(String from, String to, String dateStr) async {
    if (from == to) {
      lastFailure = null;
      return const RateResult(rate: 1, source: RateSource.identity);
    }

    final key = _cacheKey(from, to, dateStr);

    RateResult? fromCache(RateFailure failure) {
      final cached = _store.getCachedRate(key);
      if (cached != null) {
        lastFailure = null;
        return RateResult(rate: cached, source: RateSource.cache);
      }
      lastFailure = failure;
      return null;
    }

    // Opt-in gate. Deliberately enforced *here* rather than only at the call
    // sites: this is the one place that opens a socket, so no future caller can
    // forget the check. Without consent the local cache is still fair game — it
    // is a file on this machine, reading it contacts nobody.
    if (!mayFetchRates) {
      debugPrint('CurrencyService: Abruf $from→$to übersprungen (Zustimmung: ${_store.rateFetchConsent.name}).');
      return fromCache(RateFailure.notAllowed);
    }

    try {
      final uri = Uri.parse('$_apiBase/$dateStr?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}');
      final res = await http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate is! num) throw Exception('Kein Kurs in der Antwort enthalten');
      final rateD = rate.toDouble();
      // Ein Kurs <= 0 (oder NaN/Infinity) ist keine gültige Antwort und würde
      // sonst gecacht und in `Balance.rate`/`Subscription.rate` geschrieben —
      // entries_view muss dort bereits `rate != 0` abfangen. Lieber hier als
      // Fehlschlag behandeln (Cache/manuelle Eingabe greift), denn die
      // manuelle Eingabe validiert dieselbe Bedingung seit jeher.
      if (!rateD.isFinite || rateD <= 0) throw Exception('Unplausibler Kurs in der Antwort: $rateD');

      // Caching is best-effort and must never cost the user a rate we already
      // hold: a failing write to finanzgecko-rates.json (read-only directory,
      // full disk) previously landed in the outer catch and turned a perfectly
      // good live rate into "kein Wechselkurs verfügbar".
      try {
        await _store.setCachedRate(key, rateD);
      } catch (err) {
        debugPrint('CurrencyService: Kurs $from→$to abgerufen, aber Cache-Schreiben fehlgeschlagen: $err');
      }

      lastFailure = null;
      return RateResult(rate: rateD, source: RateSource.live);
    } catch (err) {
      debugPrint('CurrencyService: Abruf $from→$to für $dateStr fehlgeschlagen: $err');
      return fromCache(RateFailure.requestFailed);
    }
  }
}
