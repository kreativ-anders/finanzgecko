/// Domain checks an imported backup's entries must pass before they replace the user's data.
///
/// INFO: pure and IO-free — rules and rationale in dev/ai/persistence.md, scenarios in
/// gherkin/executable/import_validation.feature.
library;

import '../constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';

/// The four entry lists of a backup, after type parsing.
typedef ImportedEntries = ({
  List<Account> accounts,
  List<Balance> balances,
  List<Asset> assets,
  List<Subscription> subscriptions,
});

/// Largest absolute amount accepted on import; anything above is a conversion error, not a real balance.
// INFO: keeps sums finite — a single 1e308 turns every total and chart into Infinity.
const double kMaxImportedAmount = 1e15;

final RegExp _periodPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// True for a "YYYY-MM" month with a month from 01 to 12 — the only shape the period helpers can parse.
bool isValidPeriod(String period) => _periodPattern.hasMatch(period);

bool isKnownCurrency(String currency) => kCurrencies.contains(currency);

bool isKnownInterval(String interval) => kSubscriptionIntervals.any((i) => i.value == interval);

bool _isPlausibleAmount(double value) => value.isFinite && value.abs() <= kMaxImportedAmount;

/// The imported Basiswährung, or null when it is missing or not one the app offers.
String? importedBaseCurrency(Object? raw) => raw is String && isKnownCurrency(raw) ? raw : null;

/// Drops every entry that would break the app after import; the first of several entries with one id wins.
// INFO: Kontotyp is deliberately not checked — older versions offered "Festgeld" and "Kredit".
ImportedEntries dropInvalidImportEntries(ImportedEntries entries) {
  final accountIds = <int>{};
  final accounts = [
    for (final a in entries.accounts)
      if (isKnownCurrency(a.currency) && accountIds.add(a.id)) a,
  ];

  final balanceIds = <int>{};
  final balanceMonths = <String>{};
  final balances = [
    for (final b in entries.balances)
      if (isValidPeriod(b.period) &&
          isKnownCurrency(b.currencyOriginal) &&
          _isPlausibleAmount(b.amountOriginal) &&
          _isPlausibleAmount(b.rate) &&
          _isPlausibleAmount(b.amountBase) &&
          balanceIds.add(b.id) &&
          // One Kontostand per Konto and Monat — a second one would be counted twice in every total.
          balanceMonths.add('${b.accountId}|${b.period}'))
        b,
  ];

  final assetIds = <int>{};
  final assets = [
    for (final a in entries.assets)
      if (_isPlausibleAmount(a.value) && assetIds.add(a.id)) a,
  ];

  final subscriptionIds = <int>{};
  final subscriptions = [
    for (final s in entries.subscriptions)
      if (isKnownInterval(s.interval) &&
          isKnownCurrency(s.currencyOriginal) &&
          _isPlausibleAmount(s.amountOriginal) &&
          _isPlausibleAmount(s.rate) &&
          _isPlausibleAmount(s.amountBase) &&
          subscriptionIds.add(s.id))
        s,
  ];

  return (accounts: accounts, balances: balances, assets: assets, subscriptions: subscriptions);
}
