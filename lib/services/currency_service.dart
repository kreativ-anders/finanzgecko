import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/app_store.dart';

/// Where a rate came from — mirrors the "Quelle" wording in `gherkin/currency_exchange.feature`.
enum RateSource { identity, live, cache }

class RateResult {
  final double rate;
  final RateSource source;

  const RateResult({required this.rate, required this.source});
}

/// Why no rate could be produced.
// INFO: failures used to collapse to a bare `null`, so the dialog blamed "(offline?)" for a missing opt-in.
// INFO: [message] lives in the enum, not an extension — the only caller knows the type via `AppState`.
enum RateFailure {
  /// Rate lookups aren't allowed (opt-in `unset`/`denied`) and nothing cached.
  notAllowed(
    'Der Online-Abruf von Wechselkursen ist nicht erlaubt (Einstellungen → Wechselkurse), '
    'und für dieses Währungspaar liegt kein gespeicherter Kurs vor.',
  ),

  /// Allowed, but the request failed (no connection, timeout, HTTP error, bad answer) and nothing cached.
  requestFailed(
    'Der Wechselkurs konnte nicht abgerufen werden (keine Verbindung oder Störung der API), '
    'und für dieses Währungspaar liegt kein gespeicherter Kurs vor.',
  );

  const RateFailure(this.message);

  /// Shown to the user above the manual-rate field.
  final String message;
}

/// Exchange rates via the free Frankfurter.app API (ECB reference rates), cached for offline use.
class CurrencyService {
  CurrencyService(this._store, {http.Client? client}) : _client = client ?? http.Client();

  final AppStore _store;

  /// Injectable so the rate path can run without a network, long-lived so lookups reuse one connection.
  final http.Client _client;

  static const _apiBase = 'https://api.frankfurter.dev/v1';

  /// How long a save blocks on a slow connection before the cache/manual-rate path takes over.
  static const _requestTimeout = Duration(seconds: 10);

  String _cacheKey(String from, String to, String dateStr) => '${from}_${to}_$dateStr';

  // DEBUG: guarded because `debugPrint` is not stripped from release builds and currency pairs are financial data.
  void _log(String message) {
    if (kDebugMode) debugPrint('CurrencyService: $message');
  }

  /// Releases the connection pool. See [AppState.dispose].
  void dispose() => _client.close();

  /// Whether the user has allowed rate lookups (Einstellungen → Wechselkurse).
  bool get mayFetchRates => _store.mayFetchRates;

  /// Live reachability probe for Einstellungen → "Hilfe"; null when fetching isn't allowed ("nicht geprüft").
  // INFO: runs only on an explicit click, never when a view opens — see dev/ai/stack.md.
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
  // WARNING: diagnostic only — safe solely because rate lookups run strictly sequentially inside one save.
  RateFailure? lastFailure;

  /// dateStr must be "YYYY-MM-DD"; null when neither API nor cache can supply a rate ([lastFailure] says why).
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

    // WARNING: the opt-in gate sits here, not at the call sites — this is the only place that opens a socket.
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
      // INFO: an implausible rate would otherwise be cached and written into `Balance.rate`/`Subscription.rate`.
      if (!rateD.isFinite || rateD <= 0) throw Exception('Unplausibler Kurs in der Antwort: $rateD');

      // INFO: a failing cache write must not turn a good live rate into "kein Wechselkurs verfügbar".
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
