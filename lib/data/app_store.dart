import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';
import 'app_data.dart';

const String _applicationId = 'de.finanzgecko.app';
const String _storeFilename = 'app-data.json';

/// Persists the entire app database as a single JSON file in the OS-native
/// per-user data directory — same location and schema the previous
/// Neutralino build used, so existing installs migrate without conversion:
///
///  - Linux:   ~/.local/share/de.finanzgecko.app/app-data.json
///  - macOS:   ~/Library/Application Support/de.finanzgecko.app/app-data.json
///  - Windows: %APPDATA%\de.finanzgecko.app\app-data.json
///
/// The file is unencrypted; confidentiality against other local OS accounts
/// is provided by filesystem permissions (0700 dir / 0600 file on
/// Linux/macOS), not by encryption. Writes are atomic (temp file + rename).
class AppStore {
  AppData? _data;
  String? _filePath;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  String get filePath {
    final path = _filePath;
    if (path == null) {
      throw StateError('Store not initialized. Call ensureInitialized() first.');
    }
    return path;
  }

  AppData get _requireData {
    final data = _data;
    if (data == null) {
      throw StateError('Store not initialized. Call ensureInitialized() first.');
    }
    return data;
  }

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

  static Directory resolveDataDirectory() {
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      final base = (xdg != null && xdg.isNotEmpty) ? xdg : p.join(_home(), '.local', 'share');
      return Directory(p.join(base, _applicationId));
    } else if (Platform.isMacOS) {
      return Directory(p.join(_home(), 'Library', 'Application Support', _applicationId));
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, _applicationId));
      }
      return Directory(p.join(_home(), 'AppData', 'Roaming', _applicationId));
    }
    return Directory(p.join(Directory.current.path, '.finanzgecko-data'));
  }

  Future<void> _chmod(String path, String mode) async {
    if (!Platform.isLinux && !Platform.isMacOS) return; // not applicable on Windows
    try {
      await Process.run('chmod', [mode, path]);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    final dir = resolveDataDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _chmod(dir.path, '700');

    _filePath = p.join(dir.path, _storeFilename);
    final file = File(_filePath!);
    final tmpFile = File('${file.path}.tmp');

    // Clean up any leftover temp file from a previous crash.
    if (await tmpFile.exists()) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }

    final fileExisted = await file.exists();
    try {
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw);
      final validated = AppData.fromDynamic(parsed);
      if (validated != null) {
        _data = validated;
      } else {
        await _quarantineUnreadable(file);
        _data = AppData.defaults();
        await _persist();
      }
    } catch (_) {
      // File missing (first run) -> start fresh, nothing to lose. File
      // present but unreadable (corrupt JSON, wrong shape, ...) -> preserve
      // it under a new name first, since the next line would otherwise
      // silently overwrite the user's only copy of their data with empty
      // defaults.
      if (fileExisted) await _quarantineUnreadable(file);
      _data = AppData.defaults();
      await _persist();
    }

    _initialized = true;
  }

  /// Best-effort copy of a store file that failed to parse, so a corrupt or
  /// unexpectedly-shaped file never gets silently destroyed by [_persist]
  /// writing fresh defaults over it. A failed backup must not block startup.
  Future<void> _quarantineUnreadable(File file) async {
    try {
      final ts = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
      await file.copy('${file.path}.unreadable-$ts');
    } catch (_) {}
  }

  /// Best-effort snapshot of the pre-import state, written alongside the
  /// main store file. Must never throw or block the import it precedes.
  Future<void> _backupBeforeImport(Map<String, dynamic> snapshot) async {
    try {
      final ts = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
      final backupFile = File(p.join(File(filePath).parent.path, 'pre-import-backup-$ts.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
      await backupFile.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final path = filePath;
    final file = File(path);
    final tmpFile = File('$path.tmp');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_requireData.toJson());

    try {
      await tmpFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tmpFile.rename(path);
      await _chmod(path, '600');
    } finally {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  // ---------- Accounts ----------

  List<Account> getAccounts({bool includeArchived = false}) {
    final all = _requireData.accounts;
    return includeArchived ? List.of(all) : all.where((a) => !a.archived).toList();
  }

  Account? getAccount(int id) {
    for (final a in _requireData.accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Account> addAccount({
    required String name,
    String bank = '',
    required String tag,
    String currency = 'EUR',
    required String color,
  }) async {
    final data = _requireData;
    final record = Account(
      id: data.nextAccountId,
      name: name,
      bank: bank,
      tag: tag,
      currency: currency,
      color: color,
      archived: false,
      createdAt: DateTime.now(),
    );
    data.nextAccountId += 1;
    data.accounts.add(record);
    try {
      await _persist();
    } catch (_) {
      data.accounts.removeLast();
      data.nextAccountId -= 1;
      rethrow;
    }
    return record;
  }

  Future<Account> updateAccount(
    int id, {
    String? name,
    String? bank,
    String? tag,
    String? currency,
    String? color,
  }) async {
    final data = _requireData;
    final idx = data.accounts.indexWhere((a) => a.id == id);
    if (idx == -1) throw Exception('Konto nicht gefunden');
    final updated = data.accounts[idx].copyWith(name: name, bank: bank, tag: tag, currency: currency, color: color);
    data.accounts[idx] = updated;
    await _persist();
    return updated;
  }

  Future<void> archiveAccount(int id) async {
    final data = _requireData;
    final idx = data.accounts.indexWhere((a) => a.id == id);
    if (idx == -1) throw Exception('Konto nicht gefunden');
    data.accounts[idx] = data.accounts[idx].copyWith(archived: true);
    await _persist();
  }

  // ---------- Balances ----------

  List<Balance> getAllBalances() {
    final list = List.of(_requireData.balances);
    list.sort((a, b) => a.period.compareTo(b.period));
    return list;
  }

  List<Balance> getBalancesForAccount(int accountId) {
    final list = _requireData.balances.where((b) => b.accountId == accountId).toList();
    list.sort((a, b) => a.period.compareTo(b.period));
    return list;
  }

  Balance? getBalanceForAccountPeriod(int accountId, String period) {
    for (final b in _requireData.balances) {
      if (b.accountId == accountId && b.period == period) return b;
    }
    return null;
  }

  Future<Balance> upsertBalance({
    required int accountId,
    required String period,
    required double amountOriginal,
    required String currencyOriginal,
    required double rate,
    required double amountBase,
    String note = '',
  }) async {
    final data = _requireData;
    final idx = data.balances.indexWhere((b) => b.accountId == accountId && b.period == period);
    final record = Balance(
      id: idx != -1 ? data.balances[idx].id : data.nextBalanceId,
      accountId: accountId,
      period: period,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
      note: note,
      enteredAt: DateTime.now(),
    );
    if (idx != -1) {
      data.balances[idx] = record;
    } else {
      data.nextBalanceId += 1;
      data.balances.add(record);
    }
    await _persist();
    return record;
  }

  Future<Balance> updateBalance(int id, {double? amountOriginal, double? amountBase}) async {
    final data = _requireData;
    final idx = data.balances.indexWhere((b) => b.id == id);
    if (idx == -1) throw Exception('Eintrag nicht gefunden');
    final updated = data.balances[idx].copyWith(amountOriginal: amountOriginal, amountBase: amountBase);
    data.balances[idx] = updated;
    await _persist();
    return updated;
  }

  Future<void> deleteBalance(int id) async {
    final data = _requireData;
    data.balances.removeWhere((b) => b.id == id);
    await _persist();
  }

  // ---------- Vermögenswerte ----------

  List<Asset> getAssets() => List.of(_requireData.assets);

  Future<Asset> addAsset({required String name, required double value}) async {
    final data = _requireData;
    final now = DateTime.now();
    final record = Asset(id: data.nextAssetId, name: name, value: value, createdAt: now, lastEvaluatedAt: now);
    data.nextAssetId += 1;
    data.assets.add(record);
    try {
      await _persist();
    } catch (_) {
      data.assets.removeLast();
      data.nextAssetId -= 1;
      rethrow;
    }
    return record;
  }

  /// Changing [value] counts as a fresh re-evaluation today — that drives the
  /// 6-month reminder without needing a separate "re-evaluate" button.
  Future<Asset> updateAsset(int id, {String? name, double? value}) async {
    final data = _requireData;
    final idx = data.assets.indexWhere((a) => a.id == id);
    if (idx == -1) throw Exception('Vermögenswert nicht gefunden');
    final updated = data.assets[idx].copyWith(
      name: name,
      value: value,
      lastEvaluatedAt: value != null ? DateTime.now() : null,
    );
    data.assets[idx] = updated;
    await _persist();
    return updated;
  }

  Future<void> deleteAsset(int id) async {
    final data = _requireData;
    data.assets.removeWhere((a) => a.id == id);
    await _persist();
  }

  // ---------- Fixposten ----------

  List<Subscription> getSubscriptions() => List.of(_requireData.subscriptions);

  Future<Subscription> addSubscription({
    required String name,
    required String interval,
    required double amountOriginal,
    required String currencyOriginal,
    required double rate,
    required double amountBase,
  }) async {
    final data = _requireData;
    final record = Subscription(
      id: data.nextSubscriptionId,
      name: name,
      interval: interval,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
      createdAt: DateTime.now(),
    );
    data.nextSubscriptionId += 1;
    data.subscriptions.add(record);
    try {
      await _persist();
    } catch (_) {
      data.subscriptions.removeLast();
      data.nextSubscriptionId -= 1;
      rethrow;
    }
    return record;
  }

  Future<Subscription> updateSubscription(
    int id, {
    String? name,
    String? interval,
    double? amountOriginal,
    String? currencyOriginal,
    double? rate,
    double? amountBase,
  }) async {
    final data = _requireData;
    final idx = data.subscriptions.indexWhere((s) => s.id == id);
    if (idx == -1) throw Exception('Fixposten nicht gefunden');
    final current = data.subscriptions[idx];
    final updated = Subscription(
      id: current.id,
      name: name ?? current.name,
      interval: interval ?? current.interval,
      amountOriginal: amountOriginal ?? current.amountOriginal,
      currencyOriginal: currencyOriginal ?? current.currencyOriginal,
      rate: rate ?? current.rate,
      amountBase: amountBase ?? current.amountBase,
      createdAt: current.createdAt,
    );
    data.subscriptions[idx] = updated;
    await _persist();
    return updated;
  }

  Future<void> deleteSubscription(int id) async {
    final data = _requireData;
    data.subscriptions.removeWhere((s) => s.id == id);
    await _persist();
  }

  // ---------- Settings ----------

  String get baseCurrency => _requireData.baseCurrency;
  String get defaultSubscriptionInterval => _requireData.defaultSubscriptionInterval;
  DateTime? get lastExportAt => _requireData.lastExportAt;

  Future<void> setBaseCurrency(String value) async {
    _requireData.baseCurrency = value;
    await _persist();
  }

  Future<void> setDefaultSubscriptionInterval(String value) async {
    _requireData.defaultSubscriptionInterval = value;
    await _persist();
  }

  Future<void> setLastExportAt(DateTime value) async {
    _requireData.lastExportAt = value;
    await _persist();
  }

  // ---------- Fenstergeometrie ----------

  WindowPrefs get windowPrefs => _requireData.window;

  Future<void> setWindowPrefs(WindowPrefs prefs) async {
    _requireData.window = prefs;
    await _persist();
  }

  // ---------- Wechselkurs-Cache ----------

  double? getCachedRate(String key) => _requireData.ratesCache[key];

  Future<void> setCachedRate(String key, double rate) async {
    _requireData.ratesCache[key] = rate;
    await _persist();
  }

  // ---------- Export / Import ----------

  Map<String, dynamic> exportAllData() => _requireData.toExportJson();

  /// Replaces ALL data with the contents of an imported backup. Returns a
  /// snapshot of the previous state (useful for a future undo). The same
  /// snapshot is also written to disk first (best-effort) so an accidental
  /// import of the wrong file — confirmed by the user, but still a one-way
  /// door in the UI today — leaves a recovery copy behind.
  Future<Map<String, dynamic>> importAllData(Map<String, dynamic> imported) async {
    final data = _requireData;
    final snapshot = exportAllData();
    await _backupBeforeImport(snapshot);

    // Mirrors AppData.fromDynamic's per-entry recovery: one malformed row in
    // an otherwise-valid backup (e.g. from a slightly different schema
    // version) should be skipped, not abort the whole import.
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = imported[key];
      if (raw is! List) return <T>[];
      final result = <T>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          result.add(fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip malformed entry, keep the rest of the import usable.
        }
      }
      return result;
    }

    final accounts = parseList('accounts', Account.fromJson);
    final balances = parseList('balances', Balance.fromJson);
    final assets = parseList('assets', Asset.fromJson);
    final subscriptions = parseList('subscriptions', Subscription.fromJson);

    int maxId(Iterable<int> ids) => ids.fold(0, (m, id) => id > m ? id : m);

    data.accounts = accounts;
    data.balances = balances;
    data.assets = assets;
    data.subscriptions = subscriptions;
    if (imported['baseCurrency'] is String) data.baseCurrency = imported['baseCurrency'] as String;
    if (imported['defaultSubscriptionInterval'] is String) {
      data.defaultSubscriptionInterval = imported['defaultSubscriptionInterval'] as String;
    }
    data.nextAccountId = [data.nextAccountId, maxId(accounts.map((a) => a.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextBalanceId = [data.nextBalanceId, maxId(balances.map((b) => b.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextAssetId = [data.nextAssetId, maxId(assets.map((a) => a.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextSubscriptionId = [
      data.nextSubscriptionId,
      maxId(subscriptions.map((s) => s.id)) + 1,
    ].reduce((a, b) => a > b ? a : b);

    await _persist();
    return snapshot;
  }
}
