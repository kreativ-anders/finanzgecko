import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';
import 'app_schema.dart';
import 'crypto_platform.dart';
import 'sandbox_migration.dart';
import 'secure_key_store.dart';

const String _applicationId = 'de.finanzgecko.app';

// WARNING: a macOS folder name ending in ".app" reads to Finder as a damaged app bundle (measured 2026-08-13).
const String _macOsDirectoryName = 'FinanzGecko';

const String _storeFilename = 'finanzgecko-data.json';
// WARNING: both macOS builds share one container but not one key — a shared filename would make them fight
// over the same file. The store build writes its own; see dev/ai/persistence.md "Channel switch".
const String _appStoreFilename = 'finanzgecko-data-appstore.json';
// INFO: rates are public ECB data in their own unencrypted file, so a fresh rate never re-encrypts the database.
const String _ratesFilename = 'finanzgecko-rates.json';
const int _envelopeVersion = 1;

/// Thrown when the data file was encrypted by a *different* installation — its `keyId` doesn't match.
class ForeignKeyDataException implements Exception {
  const ForeignKeyDataException(this.filePath);

  final String filePath;

  @override
  String toString() => 'ForeignKeyDataException($filePath)';
}

/// Thrown by an update/delete lookup when the id no longer exists.
class RecordNotFoundException implements Exception {
  const RecordNotFoundException(this.entity, this.id);

  /// One of "account", "balance", "asset", "subscription".
  final String entity;
  final int id;

  @override
  String toString() => 'RecordNotFoundException($entity #$id)';
}

/// Thrown by [AppStore.importAllData] when the backup's `schemaVersion` is newer than this build.
class UnsupportedBackupVersionException implements Exception {
  const UnsupportedBackupVersionException({required this.importedVersion, required this.supportedVersion});

  final num importedVersion;
  final int supportedVersion;

  @override
  String toString() => 'UnsupportedBackupVersionException(imported: $importedVersion, supported: $supportedVersion)';
}

/// Thrown by [AppStore.importAllData] when an account names a bank [resolveAccountColor] doesn't know.
class AccountImportRejectedException implements Exception {
  const AccountImportRejectedException({required this.accountName, required this.unknownBank});

  final String accountName;
  final String unknownBank;

  @override
  String toString() => 'AccountImportRejectedException(account: $accountName, unknownBank: $unknownBank)';
}

/// Persists the whole app database as one AES-256-GCM encrypted JSON file — see dev/ai/persistence.md.
class AppStore {
  // WARNING: widget tests need [persistToDisk] false — real file I/O never completes under their fake-async clock.
  AppStore({Directory? dataDirectory, this.persistToDisk = true, this.ignoreForeignData = false, bool? appStoreChannel})
    : _dataDirectoryOverride = dataDirectory,
      appStoreChannel = appStoreChannel ?? kIsMacAppStore;

  final Directory? _dataDirectoryOverride;
  final bool persistToDisk;

  /// Which delivery channel's data file this store owns; injectable because [kIsMacAppStore] is compile-time.
  final bool appStoreChannel;

  /// Set only by the startup screen after the user chose import or an empty start — see [ForeignKeyDataException].
  final bool ignoreForeignData;
  AppSchema? _data;
  String? _filePath;
  String? _ratesFilePath;
  final Map<String, double> _ratesCache = {};
  bool _initialized = false;
  final AesGcm _cipher = buildAesGcm256();
  SecretKey? _key;

  // WARNING: [SandboxMigrationOutcome.failed] must never be presented to the user as an empty app.
  /// Outcome of the one-time pre-sandbox migration attempted during [ensureInitialized].
  SandboxMigrationOutcome lastSandboxMigration = SandboxMigrationOutcome.notApplicable;

  /// Serializes all disk writes so two overlapping mutations can never race on the shared `.tmp` file.
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() action) {
    // INFO: the queue keeps an error-swallowing copy so one failed write can't poison it for later writes.
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  bool get isInitialized => _initialized;

  String get filePath {
    final path = _filePath;
    if (path == null) {
      throw StateError('Store not initialized. Call ensureInitialized() first.');
    }
    return path;
  }

  AppSchema get _requireData {
    final data = _data;
    if (data == null) {
      throw StateError('Store not initialized. Call ensureInitialized() first.');
    }
    return data;
  }

  SecretKey get _requireKey {
    final key = _key;
    if (key == null) {
      throw StateError('Store not initialized. Call ensureInitialized() first.');
    }
    return key;
  }

  static bool _isEnvelope(dynamic decoded) =>
      decoded is Map &&
      decoded['v'] == _envelopeVersion &&
      decoded['nonce'] is String &&
      decoded['cipherText'] is String &&
      decoded['mac'] is String;

  /// Non-secret fingerprint of the encryption key (first 8 bytes of its SHA-256, base64), stored in the clear.
  static Future<String> keyFingerprint(SecretKey key) async {
    final bytes = await key.extractBytes();
    final digest = await Sha256().hash(bytes);
    return base64Encode(digest.bytes.take(8).toList());
  }

  Future<String> _decryptEnvelope(Map decoded) async {
    final box = SecretBox(
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
    final clearBytes = await _cipher.decrypt(box, secretKey: _requireKey);
    return utf8.decode(clearBytes);
  }

  Future<String> _encryptToEnvelope(String plaintext) async {
    final box = await _cipher.encrypt(utf8.encode(plaintext), secretKey: _requireKey);
    return jsonEncode({
      // WARNING: `v` stays 1 — `keyId` is additive, so older builds still read newly written files.
      'v': _envelopeVersion,
      'keyId': await keyFingerprint(_requireKey),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

  /// The only location, deliberately: a user-choosable folder was designed and rejected, see dev/ai/persistence.md.
  static Directory resolveDataDirectory() {
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      final base = (xdg != null && xdg.isNotEmpty) ? xdg : p.join(_home(), '.local', 'share');
      return Directory(p.join(base, _applicationId));
    } else if (Platform.isMacOS) {
      return Directory(p.join(_home(), 'Library', 'Application Support', _macOsDirectoryName));
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, _applicationId));
      }
      return Directory(p.join(_home(), 'AppData', 'Roaming', _applicationId));
    }
    return Directory(p.join(Directory.current.path, '.finanzgecko-data'));
  }

  // WARNING: `Process.run` never completes under a `testWidgets` fake-async clock and would hang the tests.
  static bool get _inFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Paths already hardened in this process — the bits survive a rewrite, so one spawn per path per session.
  final Set<String> _hardened = <String>{};

  // INFO: absolute, not PATH-resolved: `PATH` is attacker-influenced and `/bin/chmod` is POSIX-mandated.
  static const String _chmodBinary = '/bin/chmod';

  Future<void> _chmod(String path, String mode) async {
    if (_inFlutterTest) return;
    // INFO: a sandboxed container is already per-app and per-user, so the chmod bits add nothing.
    if (kIsMacAppStore) return;
    if (!Platform.isLinux && !Platform.isMacOS) return; // not applicable on Windows
    if (!_hardened.add('chmod:$mode:$path')) return;
    try {
      await Process.run(_chmodBinary, [mode, path]);
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Windows counterpart to [_chmod]: `icacls` ACLs, inheritable so files created later keep the restriction.
  Future<void> _restrictWindowsAccess(String path, {required bool isDirectory}) async {
    if (_inFlutterTest) return;
    if (!Platform.isWindows) return;
    if (!_hardened.add('icacls:$path')) return;
    final user = Platform.environment['USERNAME'];
    if (user == null || user.isEmpty) return;
    final domain = Platform.environment['USERDOMAIN'];
    final principal = (domain != null && domain.isNotEmpty) ? '$domain\\$user' : user;
    final grant = isDirectory ? '$principal:(OI)(CI)F' : '$principal:F';
    // INFO: absolute for the same reason as [_chmodBinary] — %SystemRoot% is set by the OS, %PATH% is not.
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    try {
      await Process.run('$systemRoot\\System32\\icacls.exe', [path, '/inheritance:r', '/grant:r', grant]);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    _key = await const SecureKeyStore().getOrCreateKey();

    if (!persistToDisk) {
      _data = AppSchema.defaults();
      _initialized = true;
      return;
    }

    final dir = _dataDirectoryOverride ?? resolveDataDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _chmod(dir.path, '700');
    await _restrictWindowsAccess(dir.path, isDirectory: true);

    // WARNING: must run before the first read — otherwise a sandboxed first launch looks like a fresh install.
    if (_dataDirectoryOverride == null && !_inFlutterTest) {
      lastSandboxMigration = await SandboxMigration.run(
        targetDirectory: dir,
        home: _home(),
        bundleId: _applicationId,
        // INFO: deliberately the old name, not [_macOsDirectoryName] — pre-sandbox versions wrote that one.
        legacyDirectoryName: _applicationId,
        filenames: const [_storeFilename, _ratesFilename],
      );
    }

    _filePath = p.join(dir.path, appStoreChannel ? _appStoreFilename : _storeFilename);
    _ratesFilePath = p.join(dir.path, _ratesFilename);
    final file = File(_filePath!);

    // INFO: store build only — the other channel's file sits in the same container under the classic name.
    if (appStoreChannel && !await file.exists()) {
      await _adoptOrReportLegacyFile(File(p.join(dir.path, _storeFilename)), file);
    }
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
      final decoded = jsonDecode(raw);
      if (!_isEnvelope(decoded)) {
        // Preserve an unexpected or foreign file shape before defaults overwrite it.
        await _quarantineFile(file, 'unreadable');
        _data = AppSchema.defaults();
        await _persist();
      } else if (await _hasForeignKeyId(decoded as Map)) {
        // INFO: without this check a foreign file looks exactly like a corrupt one; see dev/ai/persistence.md.
        if (!ignoreForeignData) throw ForeignKeyDataException(_filePath!);
        // The user chose to continue here, and this path is the one we're about to write — keep a copy first.
        await _quarantineFile(file, 'foreign');
        _data = AppSchema.defaults();
        await _persist();
      } else {
        final parsed = jsonDecode(await _decryptEnvelope(decoded));
        final onDiskVersion = (parsed is Map && parsed['schemaVersion'] is num) ? parsed['schemaVersion'] as num : null;
        final validated = AppSchema.fromDynamic(parsed);
        if (validated == null) {
          await _quarantineFile(file, 'unreadable');
          _data = AppSchema.defaults();
          await _persist();
        } else if (onDiskVersion != null && onDiskVersion > currentSchemaVersion) {
          // WARNING: parsing a newer build's file leniently would drop unknown fields and overwrite the only copy.
          await _quarantineFile(file, 'newer-version');
          _data = AppSchema.defaults();
          await _persist();
        } else {
          final needsMigration = onDiskVersion != null && onDiskVersion < currentSchemaVersion;
          if (needsMigration) {
            // Snapshot the file before this build rewrites it, so a botched forward migration stays recoverable.
            await _writePreMigrationBackup(file);
          }
          validated.schemaVersion = currentSchemaVersion;
          _data = validated;
          // Persisted immediately so the file and its pre-migration backup can't drift apart across restarts.
          if (needsMigration) await _persist();
        }
      }
    } on ForeignKeyDataException {
      // WARNING: must bypass the catch-all below — the intact foreign file must not be moved or overwritten.
      rethrow;
    } catch (_) {
      // A present but unreadable file is preserved first; the next line would overwrite the only copy.
      if (fileExisted) await _quarantineFile(file, 'unreadable');
      _data = AppSchema.defaults();
      await _persist();
    }

    await _loadRatesCache();
    // INFO: one-time migration of rate entries that older stores kept inside the encrypted database.
    if (_data!.ratesCache.isNotEmpty) {
      _ratesCache.addAll(_data!.ratesCache);
      _data!.ratesCache = {};
      await _persistRates();
    }

    _initialized = true;
  }

  /// True when the envelope names a key fingerprint that isn't this installation's.
  Future<bool> _hasForeignKeyId(Map decoded) async {
    final storedKeyId = decoded['keyId'];
    return storedKeyId is String && storedKeyId != await keyFingerprint(_requireKey);
  }

  /// Store build, first start: decides what the classic-name file next door means — ours, theirs, or neither.
  ///
  /// Own file (an earlier store build wrote it before this channel had its own name) → copied over once. The
  /// other channel's file → [ForeignKeyDataException], so the startup screen can offer an import. Anything
  /// else stays untouched: a file this build can't read is never quarantined when it isn't even at our path.
  Future<void> _adoptOrReportLegacyFile(File legacy, File target) async {
    if (!await legacy.exists()) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(await legacy.readAsString());
    } catch (_) {
      return; // Unreadable and not ours to clean up.
    }
    if (!_isEnvelope(decoded)) return;
    try {
      await _decryptEnvelope(decoded as Map);
    } catch (_) {
      // Only a successful decryption proves the key is ours — older files carry no keyId to compare.
      if (!ignoreForeignData) throw ForeignKeyDataException(legacy.path);
      return;
    }
    // WARNING: copy, never move — the classic name is what the other channel and older builds look for.
    await legacy.copy(target.path);
  }

  /// Loads the standalone rate cache; a missing or corrupt file just means "nothing cached yet".
  Future<void> _loadRatesCache() async {
    final path = _ratesFilePath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k is String && v is num) _ratesCache[k] = v.toDouble();
        });
      }
    } catch (_) {
      // Disposable cache — ignore and re-fetch on demand.
    }
  }

  /// Filesystem-safe timestamp suffix (no `:`/`.`) for every side-file this class writes.
  static String _timestampSuffix() => DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');

  /// Best-effort copy of a store file this build won't adopt; [reason] (`unreadable`/`newer-version`) names it.
  Future<void> _quarantineFile(File file, String reason) async {
    try {
      await file.copy('${file.path}.$reason-${_timestampSuffix()}');
    } catch (_) {}
  }

  /// Byte-for-byte copy of the encrypted store file, taken before a forward migration rewrites it.
  Future<void> _writePreMigrationBackup(File file) async {
    try {
      await file.copy(p.join(file.parent.path, 'pre-migrate-backup-${_timestampSuffix()}.json'));
    } catch (_) {}
  }

  /// Best-effort snapshot written before a destructive one-way action (import, reset); must never throw.
  Future<void> _writeSnapshotBackup(String label, Map<String, dynamic> snapshot) async {
    if (!persistToDisk) return;
    try {
      final backupFile = File(p.join(File(filePath).parent.path, 'pre-$label-backup-${_timestampSuffix()}.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
      final envelopeJson = await _encryptToEnvelope(jsonStr);
      await backupFile.writeAsString(envelopeJson, flush: true);
    } catch (_) {}
  }

  // WARNING: the pre-rename delete is Windows-only — on POSIX it would open a crash window with no data file.
  /// Atomically writes [content] to [path] via a sibling `.tmp` file and a rename.
  Future<void> _atomicWrite(String path, String content) async {
    if (!persistToDisk) return;
    final file = File(path);
    final tmpFile = File('$path.tmp');
    try {
      await tmpFile.writeAsString(content, flush: true);
      if (Platform.isWindows && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tmpFile.rename(path);
      await _chmod(path, '600');
      await _restrictWindowsAccess(path, isDirectory: false);
    } finally {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _persist() => _enqueueWrite(_persistNow);

  Future<void> _persistNow() async {
    if (!persistToDisk) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_requireData.toJson());
    final envelopeJson = await _encryptToEnvelope(jsonStr);
    await _atomicWrite(filePath, envelopeJson);
  }

  Future<void> _persistRates() => _enqueueWrite(_persistRatesNow);

  Future<void> _persistRatesNow() async {
    if (!persistToDisk) return;
    final path = _ratesFilePath;
    if (path == null) return;
    await _atomicWrite(path, jsonEncode(_ratesCache));
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
    if (idx == -1) throw RecordNotFoundException('account', id);
    final previous = data.accounts[idx];
    final updated = previous.copyWith(name: name, bank: bank, tag: tag, currency: currency, color: color);
    data.accounts[idx] = updated;
    try {
      await _persist();
    } catch (_) {
      data.accounts[idx] = previous;
      rethrow;
    }
    return updated;
  }

  Future<void> archiveAccount(int id) async {
    final data = _requireData;
    final idx = data.accounts.indexWhere((a) => a.id == id);
    if (idx == -1) throw RecordNotFoundException('account', id);
    final previous = data.accounts[idx];
    data.accounts[idx] = previous.copyWith(archived: true);
    try {
      await _persist();
    } catch (_) {
      data.accounts[idx] = previous;
      rethrow;
    }
  }

  Future<void> restoreAccount(int id) async {
    final data = _requireData;
    final idx = data.accounts.indexWhere((a) => a.id == id);
    if (idx == -1) throw RecordNotFoundException('account', id);
    final previous = data.accounts[idx];
    data.accounts[idx] = previous.copyWith(archived: false);
    try {
      await _persist();
    } catch (_) {
      data.accounts[idx] = previous;
      rethrow;
    }
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
    final previous = idx != -1 ? data.balances[idx] : null;
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
    try {
      await _persist();
    } catch (_) {
      if (previous != null) {
        data.balances[idx] = previous;
      } else {
        data.balances.removeLast();
        data.nextBalanceId -= 1;
      }
      rethrow;
    }
    return record;
  }

  Future<Balance> updateBalance(int id, {double? amountOriginal, double? amountBase}) async {
    final data = _requireData;
    final idx = data.balances.indexWhere((b) => b.id == id);
    if (idx == -1) throw RecordNotFoundException('balance', id);
    final previous = data.balances[idx];
    final updated = previous.copyWith(amountOriginal: amountOriginal, amountBase: amountBase);
    data.balances[idx] = updated;
    try {
      await _persist();
    } catch (_) {
      data.balances[idx] = previous;
      rethrow;
    }
    return updated;
  }

  Future<void> deleteBalance(int id) async {
    final data = _requireData;
    final idx = data.balances.indexWhere((b) => b.id == id);
    final removed = idx == -1 ? null : data.balances.removeAt(idx);
    try {
      await _persist();
    } catch (_) {
      if (removed != null) data.balances.insert(idx, removed);
      rethrow;
    }
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

  /// Changing [value] counts as a fresh re-evaluation and resolves this asset's overdue-notification episode.
  Future<Asset> updateAsset(int id, {String? name, double? value}) async {
    final data = _requireData;
    final idx = data.assets.indexWhere((a) => a.id == id);
    if (idx == -1) throw RecordNotFoundException('asset', id);
    final previous = data.assets[idx];
    final wasNotified = data.assetOverdueNotifiedIds.contains(id);
    final updated = previous.copyWith(name: name, value: value, lastEvaluatedAt: value != null ? DateTime.now() : null);
    data.assets[idx] = updated;
    if (value != null) data.assetOverdueNotifiedIds.remove(id);
    try {
      await _persist();
    } catch (_) {
      data.assets[idx] = previous;
      if (value != null && wasNotified) data.assetOverdueNotifiedIds.add(id);
      rethrow;
    }
    return updated;
  }

  Future<void> deleteAsset(int id) async {
    final data = _requireData;
    final idx = data.assets.indexWhere((a) => a.id == id);
    final removed = idx == -1 ? null : data.assets.removeAt(idx);
    final wasNotified = data.assetOverdueNotifiedIds.contains(id);
    data.assetOverdueNotifiedIds.remove(id);
    try {
      await _persist();
    } catch (_) {
      if (removed != null) data.assets.insert(idx, removed);
      if (wasNotified) data.assetOverdueNotifiedIds.add(id);
      rethrow;
    }
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
    if (idx == -1) throw RecordNotFoundException('subscription', id);
    final previous = data.subscriptions[idx];
    final updated = previous.copyWith(
      name: name,
      interval: interval,
      amountOriginal: amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase,
    );
    data.subscriptions[idx] = updated;
    try {
      await _persist();
    } catch (_) {
      data.subscriptions[idx] = previous;
      rethrow;
    }
    return updated;
  }

  Future<void> deleteSubscription(int id) async {
    final data = _requireData;
    final idx = data.subscriptions.indexWhere((s) => s.id == id);
    final removed = idx == -1 ? null : data.subscriptions.removeAt(idx);
    try {
      await _persist();
    } catch (_) {
      if (removed != null) data.subscriptions.insert(idx, removed);
      rethrow;
    }
  }

  // ---------- Settings ----------

  String get baseCurrency => _requireData.baseCurrency;
  DateTime? get lastExportAt => _requireData.lastExportAt;

  Future<void> setBaseCurrency(String value) async {
    final data = _requireData;
    final previous = data.baseCurrency;
    data.baseCurrency = value;
    try {
      await _persist();
    } catch (_) {
      data.baseCurrency = previous;
      rethrow;
    }
  }

  /// Also resolves the backup-overdue notification episode, so it can notify again once overdue.
  Future<void> setLastExportAt(DateTime value) async {
    final data = _requireData;
    final previousExportAt = data.lastExportAt;
    final previousNotified = data.backupOverdueNotified;
    data.lastExportAt = value;
    data.backupOverdueNotified = false;
    try {
      await _persist();
    } catch (_) {
      data.lastExportAt = previousExportAt;
      data.backupOverdueNotified = previousNotified;
      rethrow;
    }
  }

  // ---------- Reminder Benachrichtigungen (OS notifications) ----------

  bool get notificationsEnabled => _requireData.notificationsEnabled;
  bool get backupOverdueNotified => _requireData.backupOverdueNotified;
  List<int> get assetOverdueNotifiedIds => List.of(_requireData.assetOverdueNotifiedIds);

  Future<void> setNotificationsEnabled(bool value) async {
    final data = _requireData;
    final previous = data.notificationsEnabled;
    data.notificationsEnabled = value;
    try {
      await _persist();
    } catch (_) {
      data.notificationsEnabled = previous;
      rethrow;
    }
  }

  // ---------- Erscheinungsbild ----------

  AppThemeMode get themeMode => _requireData.themeMode;

  Future<void> setThemeMode(AppThemeMode value) async {
    final data = _requireData;
    final previous = data.themeMode;
    data.themeMode = value;
    try {
      await _persist();
    } catch (_) {
      data.themeMode = previous;
      rethrow;
    }
  }

  // ---------- Wechselkurse fetching (opt-in) ----------

  RateFetchConsent get rateFetchConsent => _requireData.rateFetchConsent;

  /// The single gate on contacting the rate API; `unset` deliberately counts as not allowed.
  bool get mayFetchRates => rateFetchConsent == RateFetchConsent.granted;

  Future<void> setRateFetchConsent(RateFetchConsent value) async {
    final data = _requireData;
    final previous = data.rateFetchConsent;
    data.rateFetchConsent = value;
    try {
      await _persist();
    } catch (_) {
      data.rateFetchConsent = previous;
      rethrow;
    }
  }

  Future<void> markBackupOverdueNotified() async {
    final data = _requireData;
    final previous = data.backupOverdueNotified;
    data.backupOverdueNotified = true;
    try {
      await _persist();
    } catch (_) {
      data.backupOverdueNotified = previous;
      rethrow;
    }
  }

  Future<void> markAssetOverdueNotified(int assetId) async {
    final data = _requireData;
    final alreadyPresent = data.assetOverdueNotifiedIds.contains(assetId);
    if (!alreadyPresent) data.assetOverdueNotifiedIds.add(assetId);
    try {
      await _persist();
    } catch (_) {
      if (!alreadyPresent) data.assetOverdueNotifiedIds.remove(assetId);
      rethrow;
    }
  }

  /// Wipes everything back to a fresh install; window geometry is deliberately kept.
  Future<void> resetAll() async {
    final previous = _requireData;
    await _writeSnapshotBackup('reset', previous.toExportJson());
    final window = previous.window;
    _data = AppSchema.defaults()..window = window;
    try {
      await _persist();
    } catch (_) {
      _data = previous;
      rethrow;
    }
  }

  // ---------- Window geometry ----------

  WindowPrefs get windowPrefs => _requireData.window;

  Future<void> setWindowPrefs(WindowPrefs prefs) async {
    final data = _requireData;
    final previous = data.window;
    data.window = prefs;
    try {
      await _persist();
    } catch (_) {
      data.window = previous;
      rethrow;
    }
  }

  // ---------- Wechselkurs-Cache ----------

  double? getCachedRate(String key) => _ratesCache[key];

  Future<void> setCachedRate(String key, double rate) async {
    final hadPrevious = _ratesCache.containsKey(key);
    final previous = _ratesCache[key];
    _ratesCache[key] = rate;
    try {
      await _persistRates();
    } catch (_) {
      if (hadPrevious) {
        _ratesCache[key] = previous!;
      } else {
        _ratesCache.remove(key);
      }
      rethrow;
    }
  }

  // ---------- Export / Import ----------

  Map<String, dynamic> exportAllData() => _requireData.toExportJson();

  /// Replaces ALL data with an imported backup and returns a snapshot of the previous state.
  Future<Map<String, dynamic>> importAllData(Map<String, dynamic> imported) async {
    // Reject backups from a newer schema: importing could silently drop or misread unknown fields.
    final importedVersion = imported['schemaVersion'];
    if (importedVersion is num && importedVersion > currentSchemaVersion) {
      throw UnsupportedBackupVersionException(importedVersion: importedVersion, supportedVersion: currentSchemaVersion);
    }

    final data = _requireData;
    final snapshot = exportAllData();
    await _writeSnapshotBackup('import', snapshot);

    final accounts = parseTolerantList(imported['accounts'], Account.fromJson);
    final balances = parseTolerantList(imported['balances'], Balance.fromJson);
    final assets = parseTolerantList(imported['assets'], Asset.fromJson);
    final subscriptions = parseTolerantList(imported['subscriptions'], Subscription.fromJson);

    // INFO: an unknown non-empty bank aborts the import, before `data` is touched, so a bad backup survives it.
    final normalizedAccounts = <Account>[];
    for (final a in accounts) {
      try {
        normalizedAccounts.add(
          a.copyWith(
            color: resolveAccountColor(bank: a.bank, tag: a.tag),
          ),
        );
      } on FormatException {
        throw AccountImportRejectedException(accountName: a.name, unknownBank: a.bank);
      }
    }

    int maxId(Iterable<int> ids) => ids.fold(0, (m, id) => id > m ? id : m);

    // Snapshotted so a failed persist can roll the in-memory store back.
    final previousAccounts = data.accounts;
    final previousBalances = data.balances;
    final previousAssets = data.assets;
    final previousSubscriptions = data.subscriptions;
    final previousBaseCurrency = data.baseCurrency;
    final previousNextAccountId = data.nextAccountId;
    final previousNextBalanceId = data.nextBalanceId;
    final previousNextAssetId = data.nextAssetId;
    final previousNextSubscriptionId = data.nextSubscriptionId;

    data.accounts = normalizedAccounts;
    data.balances = balances;
    data.assets = assets;
    data.subscriptions = subscriptions;
    if (imported['baseCurrency'] is String) data.baseCurrency = imported['baseCurrency'] as String;
    data.nextAccountId = [data.nextAccountId, maxId(accounts.map((a) => a.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextBalanceId = [data.nextBalanceId, maxId(balances.map((b) => b.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextAssetId = [data.nextAssetId, maxId(assets.map((a) => a.id)) + 1].reduce((a, b) => a > b ? a : b);
    data.nextSubscriptionId = [
      data.nextSubscriptionId,
      maxId(subscriptions.map((s) => s.id)) + 1,
    ].reduce((a, b) => a > b ? a : b);

    try {
      await _persist();
    } catch (_) {
      data.accounts = previousAccounts;
      data.balances = previousBalances;
      data.assets = previousAssets;
      data.subscriptions = previousSubscriptions;
      data.baseCurrency = previousBaseCurrency;
      data.nextAccountId = previousNextAccountId;
      data.nextBalanceId = previousNextBalanceId;
      data.nextAssetId = previousNextAssetId;
      data.nextSubscriptionId = previousNextSubscriptionId;
      rethrow;
    }
    return snapshot;
  }
}
