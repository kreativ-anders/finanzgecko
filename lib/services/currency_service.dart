import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/app_store.dart';

class RateResult {
  final double rate;

  const RateResult({required this.rate});
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

  /// dateStr must be "YYYY-MM-DD". Returns null only if neither the API nor
  /// the cache can supply a rate (caller then asks the user for a manual one).
  Future<RateResult?> getExchangeRate(String from, String to, String dateStr) async {
    if (from == to) {
      return const RateResult(rate: 1);
    }

    final key = _cacheKey(from, to, dateStr);

    // Opt-in gate. Deliberately enforced *here* rather than only at the call
    // sites: this is the one place that opens a socket, so no future caller can
    // forget the check. Without consent the local cache is still fair game — it
    // is a file on this machine, reading it contacts nobody. Callers that get
    // null then fall back to promptManualRate, exactly as when offline.
    if (!mayFetchRates) {
      final cached = _store.getCachedRate(key);
      return cached != null ? RateResult(rate: cached) : null;
    }

    try {
      final uri = Uri.parse('$_apiBase/$dateStr?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}');
      final res = await http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) throw Exception('Frankfurter API: HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate is! num) throw Exception('Kein Kurs in der Antwort enthalten');
      final rateD = rate.toDouble();
      await _store.setCachedRate(key, rateD);
      return RateResult(rate: rateD);
    } catch (_) {
      final cached = _store.getCachedRate(key);
      return cached != null ? RateResult(rate: cached) : null;
    }
  }
}
