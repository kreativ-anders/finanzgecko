import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/app_store.dart';

class RateResult {
  final double rate;
  final String source; // "identity" | "live" | "cache"
  final String date;

  const RateResult({required this.rate, required this.source, required this.date});
}

/// Exchange rates via the free Frankfurter.app API (ECB reference rates).
/// Rates are cached in the app store so the app keeps working offline with
/// the last known rate.
class CurrencyService {
  CurrencyService(this._store);

  final AppStore _store;
  static const _apiBase = 'https://api.frankfurter.dev/v1';

  String _cacheKey(String from, String to, String dateStr) => '${from}_${to}_$dateStr';

  /// dateStr must be "YYYY-MM-DD". Returns null only if neither the API nor
  /// the cache can supply a rate (caller then asks the user for a manual one).
  Future<RateResult?> getExchangeRate(String from, String to, String dateStr) async {
    if (from == to) {
      return RateResult(rate: 1, source: 'identity', date: dateStr);
    }

    final key = _cacheKey(from, to, dateStr);

    try {
      final uri = Uri.parse('$_apiBase/$dateStr?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Frankfurter API: HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate is! num) throw Exception('Kein Kurs in der Antwort enthalten');
      final rateD = rate.toDouble();
      await _store.setCachedRate(key, rateD);
      return RateResult(rate: rateD, source: 'live', date: data['date'] as String? ?? dateStr);
    } catch (_) {
      final cached = _store.getCachedRate(key);
      if (cached != null) {
        return RateResult(rate: cached, source: 'cache', date: dateStr);
      }
      return null;
    }
  }
}
