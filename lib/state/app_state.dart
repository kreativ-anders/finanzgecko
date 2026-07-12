import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../data/app_store.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';
import '../services/currency_service.dart';
import '../utils/formatting.dart';

class BackupReminder {
  final bool overdue;
  final String message;

  const BackupReminder({required this.overdue, required this.message});
}

class SubscriptionTotals {
  final double totalIncome;
  final double totalExpense;
  final double net;

  const SubscriptionTotals({required this.totalIncome, required this.totalExpense, required this.net});
}

/// Central app state: loads the store once at startup, then keeps an
/// in-memory copy of everything the UI needs. Every mutating action re-reads
/// from the store afterwards and calls notifyListeners(), so all views stay
/// in sync automatically (no manual per-route reload like the old SPA router).
class AppState extends ChangeNotifier {
  AppState(this.store) : currencyService = CurrencyService(store);

  final AppStore store;
  final CurrencyService currencyService;

  bool ready = false;

  List<Account> accounts = [];
  List<Balance> balances = [];
  List<Asset> assets = [];
  List<Subscription> subscriptions = [];
  String baseCurrency = 'EUR';
  String defaultSubscriptionInterval = 'monthly';

  Future<void> init() async {
    await store.ensureInitialized();
    _reload();
    ready = true;
    notifyListeners();
  }

  void _reload() {
    accounts = store.getAccounts(includeArchived: false);
    balances = store.getAllBalances();
    assets = store.getAssets();
    subscriptions = store.getSubscriptions();
    baseCurrency = store.baseCurrency;
    defaultSubscriptionInterval = store.defaultSubscriptionInterval;
  }

  Future<void> _reloadAndNotify() async {
    _reload();
    notifyListeners();
  }

  // ---------- Accounts ----------

  Future<Account> addAccount({
    required String name,
    String bank = '',
    required String tag,
    required String currency,
    required String color,
  }) async {
    final acc = await store.addAccount(name: name, bank: bank, tag: tag, currency: currency, color: color);
    await _reloadAndNotify();
    return acc;
  }

  Future<void> updateAccount(
    int id, {
    String? name,
    String? bank,
    String? tag,
    String? currency,
    String? color,
  }) async {
    await store.updateAccount(id, name: name, bank: bank, tag: tag, currency: currency, color: color);
    await _reloadAndNotify();
  }

  Future<void> archiveAccount(int id) async {
    await store.archiveAccount(id);
    await _reloadAndNotify();
  }

  // ---------- Balances ----------

  Future<void> upsertBalance({
    required int accountId,
    required String period,
    required double amountOriginal,
    required String currencyOriginal,
    required double rate,
    required double amountBase,
  }) async {
    await store.upsertBalance(
      accountId: accountId,
      period: period,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
    );
    await _reloadAndNotify();
  }

  Future<void> updateBalance(int id, {required double amountOriginal, required double amountBase}) async {
    await store.updateBalance(id, amountOriginal: amountOriginal, amountBase: amountBase);
    await _reloadAndNotify();
  }

  Future<void> deleteBalance(int id) async {
    await store.deleteBalance(id);
    await _reloadAndNotify();
  }

  /// Most recent balance strictly before [period] for [accountId] — shown as
  /// an orientation hint while entering a new value.
  Balance? previousBalance(int accountId, String period) {
    final matches = balances.where((b) => b.accountId == accountId && b.period.compareTo(period) < 0).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.period.compareTo(b.period));
    return matches.last;
  }

  // balances is kept sorted ascending by period, so the last matching entry
  // is the most recent one for that account.
  Balance? latestBalanceForAccount(int accountId) {
    for (final b in balances.reversed) {
      if (b.accountId == accountId) return b;
    }
    return null;
  }

  List<String> allPeriodsSorted() {
    final set = balances.map((b) => b.period).toSet().toList();
    set.sort();
    return set;
  }

  List<Balance> balancesInPeriod(String period) {
    final accountIds = accounts.map((a) => a.id).toSet();
    return balances.where((b) => b.period == period && accountIds.contains(b.accountId)).toList();
  }

  // ---------- Vermögenswerte ----------

  Future<void> addAsset({required String name, required double value}) async {
    await store.addAsset(name: name, value: value);
    await _reloadAndNotify();
  }

  Future<void> updateAsset(int id, {String? name, double? value}) async {
    await store.updateAsset(id, name: name, value: value);
    await _reloadAndNotify();
  }

  Future<void> deleteAsset(int id) async {
    await store.deleteAsset(id);
    await _reloadAndNotify();
  }

  bool isAssetOverdue(Asset asset) {
    final lastEvaluatedAt = asset.lastEvaluatedAt;
    if (lastEvaluatedAt == null) return true;
    return daysSince(lastEvaluatedAt) >= kAssetReevaluationDays;
  }

  String? getAssetReminder() {
    final overdue = assets.where(isAssetOverdue).toList();
    if (overdue.isEmpty) return null;
    final names = overdue.map((a) => a.name).join(', ');
    final n = overdue.length;
    return '$n Vermögenswert${n == 1 ? '' : 'e'} seit über 6 Monaten nicht neu bewertet: $names';
  }

  // ---------- Fixposten ----------

  Future<void> addSubscription({
    required String name,
    required String interval,
    required double amountOriginal,
    required String currencyOriginal,
    required double rate,
    required double amountBase,
  }) async {
    await store.addSubscription(
      name: name,
      interval: interval,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
    );
    await _reloadAndNotify();
  }

  Future<void> updateSubscription(
    int id, {
    String? name,
    String? interval,
    double? amountOriginal,
    String? currencyOriginal,
    double? rate,
    double? amountBase,
  }) async {
    await store.updateSubscription(
      id,
      name: name,
      interval: interval,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
    );
    await _reloadAndNotify();
  }

  Future<void> deleteSubscription(int id) async {
    await store.deleteSubscription(id);
    await _reloadAndNotify();
  }

  double monthlyEquivalent(Subscription sub) => sub.amountBase * intervalMonthFactor(sub.interval);

  SubscriptionTotals computeSubscriptionTotals() {
    var income = 0.0;
    var expense = 0.0;
    for (final s in subscriptions) {
      if (s.amountBase > 0) {
        income += monthlyEquivalent(s);
      } else if (s.amountBase < 0) {
        expense += monthlyEquivalent(s).abs();
      }
    }
    return SubscriptionTotals(totalIncome: income, totalExpense: expense, net: income - expense);
  }

  // ---------- Settings ----------

  Future<void> setBaseCurrency(String value) async {
    await store.setBaseCurrency(value);
    await _reloadAndNotify();
  }

  Future<void> setDefaultSubscriptionInterval(String value) async {
    await store.setDefaultSubscriptionInterval(value);
    await _reloadAndNotify();
  }

  Future<void> markExported() async {
    await store.setLastExportAt(DateTime.now());
    await _reloadAndNotify();
  }

  BackupReminder getBackupReminder() {
    final lastExportAt = store.lastExportAt;
    if (lastExportAt == null) {
      return const BackupReminder(overdue: true, message: 'Noch nie exportiert — leg jetzt ein erstes Backup an.');
    }
    final days = daysSince(lastExportAt);
    if (days >= kBackupReminderDays) {
      return BackupReminder(overdue: true, message: 'Letztes Backup vor $days Tagen — Zeit für ein neues Export.');
    }
    return BackupReminder(overdue: false, message: 'Letztes Backup vor $days Tag${days == 1 ? '' : 'en'}.');
  }

  // ---------- Export / Import ----------

  Map<String, dynamic> exportAllData() => store.exportAllData();

  Future<void> importAllData(Map<String, dynamic> imported) async {
    await store.importAllData(imported);
    await _reloadAndNotify();
  }
}
