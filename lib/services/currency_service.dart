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
/// missing opt-in or a rejected response. [message] sits **in the enum**, not
/// in an extension: an extension is only visible where its file is imported
/// directly, and the only caller knows the type indirectly via `AppState`.
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
  CurrencyService(this._store, {http.Client? client}) : _client = client ?? http.Client();

  final AppStore _store;

  /// Injectable so the rate path can be exercised without a network, and
  /// long-lived so repeated lookups reuse one connection instead of opening a
  /// socket per call.
  final http.Client _client;

  static const _apiBase = 'https://api.frankfurter.dev/v1';

  /// How long a live rate lookup waits before falling back to the cache — i.e.
  /// how long a save blocks on a slow connection before offering the
  /// offline/manual-rate path.
  static const _requestTimeout = Duration(seconds: 10);

  String _cacheKey(String from, String to, String dateStr) => '${from}_${to}_$dateStr';

  /// Diagnostics stay in debug builds. `debugPrint` is NOT stripped from a
  /// release build — it writes to the OS log. Currency pairs are financial
  /// data, and an app whose promise is that nothing leaves the machine should
  /// not narrate them to a shared system log.
  void _log(String message) {
    if (kDebugMode) debugPrint('CurrencyService: $message');
  }

  /// Releases the connection pool. See [AppState.dispose].
  void dispose() => _client.close();

  /// Whether the user has allowed rate lookups (Einstellungen → Wechselkurse).
  /// Read through here so callers have a single source of truth.
  bool get mayFetchRates => _store.mayFetchRates;

  /// Live reachability probe for Einstellungen → "Hilfe" — separate from
  /// [getExchangeRate]'s cache-fallback path so it reflects the connection
  /// right now rather than "was there ever a successful call". Hits the
  /// cheapest endpoint with a short timeout.
  ///
  /// Returns null when fetching hasn't been allowed — the caller then shows
  /// "nicht geprüft" instead of a misleading "nicht erreichbar". Never
  /// triggered by merely opening a view; only by an explicit button.
  Future<bool?> isApiReachable({Duration timeout = const Duration(seconds: 3)}) async {
    if (!mayFetchRates) return null;
    try {
      final res = await _client.get(Uri.parse('$_apiBase/currencies')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Last reason [getExchangeRate] came back empty, for the manual-rate dialog.
  ///
  /// Diagnostic only, never read for control flow. Safe because rate lookups
  /// happen strictly sequentially inside one save (see `resolveRate`).
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

    // Opt-in gate, enforced *here* rather than at the call sites: this is the
    // one place that opens a socket, so no future caller can forget it. The
    // local cache stays fair game — reading a file on this machine contacts
    // nobody.
    if (!mayFetchRates) {
      _log('Abruf $from→$to übersprungen (Zustimmung: ${_store.rateFetchConsent.name}).');
      return fromCache(RateFailure.notAllowed);
    }

    try {
      final uri = Uri.parse('$_apiBase/$dateStr?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}');
      final res = await _client.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate is! num) throw Exception('Kein Kurs in der Antwort enthalten');
      final rateD = rate.toDouble();
      // A rate <= 0 (or NaN/Infinity) is not a valid answer and would
      // otherwise be cached and written into `Balance.rate`/`Subscription.rate`
      // — entries_view already has to guard `rate != 0` there. Better treated
      // as a failure here (cache/manual entry takes over), since manual entry
      // has always validated the same condition.
      if (!rateD.isFinite || rateD <= 0) throw Exception('Unplausibler Kurs in der Antwort: $rateD');

      // Caching is best-effort and must never cost a rate we already hold: a
      // failing write to finanzgecko-rates.json (read-only directory, full
      // disk) previously landed in the outer catch and turned a perfectly good
      // live rate into "kein Wechselkurs verfügbar".
      try {
        await _store.setCachedRate(key, rateD);
      } catch (err) {
        _log('Kurs $from→$to abgerufen, aber Cache-Schreiben fehlgeschlagen: $err');
      }

      lastFailure = null;
      return RateResult(rate: rateD, source: RateSource.live);
    } catch (err) {
      _log('Abruf $from→$to für $dateStr fehlgeschlagen: $err');
      return fromCache(RateFailure.requestFailed);
    }
  }
}
