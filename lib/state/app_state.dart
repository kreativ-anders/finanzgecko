import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../data/app_store.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';
import '../services/currency_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../utils/analysis.dart';
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

/// Central app state: every mutating action reloads from the store and notifies — see dev/ai/state-and-models.md.
class AppState extends ChangeNotifier {
  AppState(this.store, {NotificationService? notificationService, UpdateService? updateService})
    : currencyService = CurrencyService(store),
      notificationService = notificationService ?? NotificationService(),
      // WARNING: null in the App Store build on purpose — Guideline 2.4.5 forbids a second update channel.
      // WARNING: it must stay UNREFERENCED there, or the tree shaker keeps the class and its GitHub URL.
      updateService = updateService ?? (kIsMacAppStore ? null : UpdateService());

  final AppStore store;
  final CurrencyService currencyService;
  final NotificationService notificationService;

  /// `null` in the App Store build — see dev/ai/persistence.md "macOS specifics".
  final UpdateService? updateService;

  @override
  void dispose() {
    // Releases the HTTP connection pools; both services hold a long-lived client.
    updateService?.dispose();
    currencyService.dispose();
    super.dispose();
  }

  bool ready = false;

  List<Account> accounts = [];
  List<Balance> balances = [];
  List<Asset> assets = [];
  List<Subscription> subscriptions = [];
  String baseCurrency = 'EUR';

  // Held here, not in DashboardView's State, so they survive navigating away; deliberately not persisted.
  HistoryRange? dashboardRangePreset;
  AccountSortOrder accountSortOrder = AccountSortOrder.standard;
  bool includeAssetsInTotal = false;

  void setDashboardRangePreset(HistoryRange preset) {
    dashboardRangePreset = preset;
    notifyListeners();
  }

  void setAccountSortOrder(AccountSortOrder order) {
    accountSortOrder = order;
    notifyListeners();
  }

  void setIncludeAssetsInTotal(bool value) {
    includeAssetsInTotal = value;
    notifyListeners();
  }

  Future<void> init() async {
    await store.ensureInitialized();
    _reload();
    ready = true;
    notifyListeners();
    await _checkReminderNotifications();
  }

  void _reload() {
    accounts = store.getAccounts(includeArchived: false);
    balances = store.getAllBalances();
    assets = store.getAssets();
    subscriptions = store.getSubscriptions();
    baseCurrency = store.baseCurrency;
  }

  Future<void> _reloadAndNotify() async {
    _reload();
    notifyListeners();
    await _checkReminderNotifications();
  }

  /// Fires an OS notification once per overdue episode, not on every start — see gherkin/notifications.feature.
  Future<void> _checkReminderNotifications() async {
    if (!store.notificationsEnabled) return;

    final backup = getBackupReminder();
    if (backup.overdue && !store.backupOverdueNotified) {
      await notificationService.show(id: kBackupNotificationId, title: 'FinanzGecko', body: backup.message);
      await store.markBackupOverdueNotified();
    }

    final overdueAssets = assets.where(isAssetOverdue).toList();
    final notifiedIds = store.assetOverdueNotifiedIds;
    final newlyOverdue = overdueAssets.where((a) => !notifiedIds.contains(a.id)).toList();
    if (newlyOverdue.isNotEmpty) {
      // One bundled message instead of one per Vermögenswert, otherwise many overdue assets flood the user.
      await notificationService.show(id: kAssetNotificationId, title: 'FinanzGecko', body: getAssetReminder()!);
      for (final asset in newlyOverdue) {
        await store.markAssetOverdueNotified(asset.id);
      }
    }
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

  Future<void> updateAccount(int id, {String? name, String? bank, String? tag, String? currency, String? color}) async {
    await store.updateAccount(id, name: name, bank: bank, tag: tag, currency: currency, color: color);
    await _reloadAndNotify();
  }

  Future<void> archiveAccount(int id) async {
    await store.archiveAccount(id);
    await _reloadAndNotify();
  }

  Future<void> restoreAccount(int id) async {
    await store.restoreAccount(id);
    await _reloadAndNotify();
  }

  /// Looks up an account regardless of archived status; null if it no longer exists at all.
  Account? findAccount(int id) => store.getAccount(id);

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

  /// Most recent balance strictly before [period] — the orientation hint shown while entering a new value.
  Balance? previousBalance(int accountId, String period) {
    final matches = balances.where((b) => b.accountId == accountId && b.period.compareTo(period) < 0).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.period.compareTo(b.period));
    return matches.last;
  }

  // balances is kept sorted ascending by period, so the last match is that account's most recent entry.
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

  /// Sum of all account balances (in base currency) for [period].
  double totalForPeriod(String period) => balancesInPeriod(period).fold<double>(0, (sum, b) => sum + b.amountBase);

  /// Including archived ones — only where their historical balances still matter, e.g. the CSV export.
  List<Account> allAccountsIncludingArchived() => store.getAccounts(includeArchived: true);

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
    return '$n Vermögenswert${n == 1 ? '' : 'e'} seit über 6 Monaten nicht mehr neu bewertet: $names';
  }

  /// Nudge when there is history but no entry for the current month yet; null when up to date or empty.
  String? getUpdateReminder() {
    if (balances.isEmpty) return null;
    final latest = balances.map((b) => b.period).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    final current = currentPeriod();
    if (latest.compareTo(current) >= 0) return null;
    return 'Letzte Erfassung: ${periodLabel(latest)}. Kontostände für ${periodLabel(current)} aktualisieren?';
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

  bool get notificationsEnabled => store.notificationsEnabled;

  /// Stores `true` only once macOS has actually granted authorization, and returns the value stored.
  Future<bool> setNotificationsEnabled(bool value) async {
    final granted = value ? await notificationService.requestPermission() : true;
    final effective = value && granted;
    await store.setNotificationsEnabled(effective);
    await _reloadAndNotify();
    return effective;
  }

  AppThemeMode get themeMode => store.themeMode;

  Future<void> setThemeMode(AppThemeMode value) async {
    await store.setThemeMode(value);
    await _reloadAndNotify();
  }

  /// Consent for fetching Wechselkurse; `unset` is treated like a denial until the user has been asked.
  RateFetchConsent get rateFetchConsent => store.rateFetchConsent;

  bool get mayFetchRates => store.mayFetchRates;

  Future<void> setRateFetchConsent(RateFetchConsent value) async {
    await store.setRateFetchConsent(value);
    await _reloadAndNotify();
  }

  DateTime? get lastExportAt => store.lastExportAt;

  /// Where the encrypted database lives; the location is not user-selectable, see dev/ai/persistence.md.
  String get dataDirectoryPath => AppStore.resolveDataDirectory().path;

  Future<void> markExported() async {
    await store.setLastExportAt(DateTime.now());
    await _reloadAndNotify();
  }

  /// Earliest recorded activity — the anchor for the "never exported" reminder; null while the app is empty.
  DateTime? _firstActivityAt() {
    DateTime? earliest;
    void consider(DateTime candidate) {
      if (earliest == null || candidate.isBefore(earliest!)) earliest = candidate;
    }

    for (final a in accounts) {
      consider(a.createdAt);
    }
    for (final b in balances) {
      consider(b.enteredAt);
    }
    for (final a in assets) {
      consider(a.createdAt);
    }
    for (final s in subscriptions) {
      consider(s.createdAt);
    }
    return earliest;
  }

  BackupReminder getBackupReminder() {
    final lastExportAt = store.lastExportAt;
    if (lastExportAt == null) {
      // Only nag once there is something to lose, and once it has had time to accumulate.
      final firstActivityAt = _firstActivityAt();
      if (firstActivityAt == null) {
        return const BackupReminder(overdue: false, message: 'Noch keine Daten erfasst.');
      }
      final days = daysSince(firstActivityAt);
      if (days >= kBackupReminderFirstDays) {
        // INFO: this reminder is where most users first learn that ONLY the backup opens on another machine.
        return const BackupReminder(
          overdue: true,
          message:
              'Noch nie exportiert — leg jetzt ein erstes Backup an und bewahre es außerhalb dieses Computers '
              'auf. Nur das Backup lässt sich auf einem anderen Rechner öffnen.',
        );
      }
      return const BackupReminder(overdue: false, message: 'Noch nie exportiert.');
    }

    final days = daysSince(lastExportAt);
    if (days >= kBackupReminderRepeatDays) {
      return BackupReminder(
        overdue: true,
        message:
            'Letztes Backup vor $days Tagen — Zeit für ein neues Backup. Bewahre es außerhalb dieses Computers '
            'auf; nur das Backup lässt sich auf einem anderen Rechner öffnen.',
      );
    }
    return BackupReminder(overdue: false, message: 'Letztes Backup vor $days Tag${days == 1 ? '' : 'en'}.');
  }

  Future<void> resetAllData() async {
    await store.resetAll();
    await _reloadAndNotify();
  }

  // ---------- Export / Import ----------

  Map<String, dynamic> exportAllData() => store.exportAllData();

  Future<void> importAllData(Map<String, dynamic> imported) async {
    await store.importAllData(imported);
    await _reloadAndNotify();
  }
}
