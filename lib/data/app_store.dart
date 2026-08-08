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
import 'secure_key_store.dart';

const String _applicationId = 'de.finanzgecko.app';
const String _storeFilename = 'finanzgecko-data.json';
// Exchange rates are public ECB reference data and re-fetchable at any time,
// so they live in their own small, unencrypted file rather than inside the
// encrypted store — that way caching a freshly fetched rate doesn't force a
// full re-encrypt-and-rewrite of the entire database.
const String _ratesFilename = 'finanzgecko-rates.json';
const int _envelopeVersion = 1;

/// Thrown when the data file was encrypted by a *different* installation —
/// its `keyId` doesn't match this machine's key.
///
/// Deliberately its own type and deliberately **fatal**: every other read
/// problem ends in "quarantine the file, start empty, write defaults", which
/// for this case would be the worst possible outcome. Somebody who puts their
/// data file in a synced folder and opens the app on a second computer would
/// otherwise watch that file get replaced by an empty one. So nothing is moved
/// and nothing is written — the startup guard in `main()` explains the
/// situation and points at the export/import route instead.
class ForeignKeyDataException implements Exception {
  const ForeignKeyDataException(this.filePath);

  final String filePath;

  @override
  String toString() => 'ForeignKeyDataException($filePath)';
}

/// Thrown by an update/delete lookup when the given id no longer exists in
/// the store. Carries structural data only (no user-facing text) — composing
/// German text from it is a UI-layer concern (see `describeError` in
/// `ui/widgets/app_snackbar.dart`), not the persistence layer's.
class RecordNotFoundException implements Exception {
  const RecordNotFoundException(this.entity, this.id);

  /// One of "account", "balance", "asset", "subscription".
  final String entity;
  final int id;

  @override
  String toString() => 'RecordNotFoundException($entity #$id)';
}

/// Thrown by [AppStore.importAllData] when the backup's `schemaVersion` is
/// newer than this build understands.
class UnsupportedBackupVersionException implements Exception {
  const UnsupportedBackupVersionException({required this.importedVersion, required this.supportedVersion});

  final num importedVersion;
  final int supportedVersion;

  @override
  String toString() => 'UnsupportedBackupVersionException(imported: $importedVersion, supported: $supportedVersion)';
}

/// Thrown by [AppStore.importAllData] when an account in the backup names a
/// bank [resolveAccountColor] doesn't recognize — the whole import is
/// rejected rather than silently assigning an arbitrary color.
class AccountImportRejectedException implements Exception {
  const AccountImportRejectedException({required this.accountName, required this.unknownBank});

  final String accountName;
  final String unknownBank;

  @override
  String toString() => 'AccountImportRejectedException(account: $accountName, unknownBank: $unknownBank)';
}

/// Persists the entire app database as a single JSON file in the OS-native
/// per-user data directory, so existing installs keep working without
/// conversion:
///
///  - Linux:   ~/.local/share/de.finanzgecko.app/finanzgecko-data.json
///  - macOS:   ~/Library/Application Support/de.finanzgecko.app/finanzgecko-data.json
///  - Windows: %APPDATA%\de.finanzgecko.app\finanzgecko-data.json
///
/// The file content is AES-256-GCM encrypted (an "envelope" of
/// nonce/cipherText/mac around the real JSON), with the key held in the
/// OS-native credential store (Windows Credential Locker, macOS Keychain,
/// Linux libsecret/kwallet) via [SecureKeyStore] — so the file is useless
/// without that specific OS user's keychain unlock, not just filesystem
/// permissions. Filesystem permissions (0700 dir / 0600 file on
/// Linux/macOS, an equivalent current-user-only ACL via icacls on Windows)
/// remain as defense in depth. Writes are atomic (temp file + rename) and
/// serialized through a single write queue so concurrent saves can't
/// interleave on the shared temp file.
class AppStore {
  /// [dataDirectory] overrides the OS-resolved data directory — used by
  /// tests to point the store at a temp folder instead of the real
  /// per-user app-data location. Production code should always use the
  /// default (unnamed) constructor.
  ///
  /// [persistToDisk] `false` keeps everything in memory and performs no
  /// `dart:io` file operations at all. This exists for widget tests
  /// (`testWidgets`), which run under a fake-async clock that never pumps the
  /// real event loop — real file I/O would never complete there and would
  /// hang the test. Persistence itself is covered by the plain `test()`-based
  /// store tests, which run in real async with this left at its default.
  AppStore({Directory? dataDirectory, this.persistToDisk = true}) : _dataDirectoryOverride = dataDirectory;

  final Directory? _dataDirectoryOverride;
  final bool persistToDisk;
  AppSchema? _data;
  String? _filePath;
  String? _ratesFilePath;
  final Map<String, double> _ratesCache = {};
  bool _initialized = false;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _key;

  /// Serializes all disk writes. Every persist appends itself to this chain
  /// so two overlapping mutations can never race on the shared `.tmp` file —
  /// the second write only starts once the first has fully renamed into
  /// place. Failures are isolated to their own caller and don't break the
  /// chain for later writes.
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() action) {
    // Chain this write after the previous one, and hand the caller that same
    // chained future so it awaits the real I/O directly. The queue itself
    // tracks a swallowed copy so one write's failure can't poison the chain
    // for later writes (the error still propagates to the failing caller).
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

  /// Short, non-secret fingerprint of the encryption key: the first 8 bytes of
  /// its SHA-256, base64. Written into the envelope in the clear so the app can
  /// tell "this file belongs to a different installation" apart from "this file
  /// is damaged" — without it, both look identical (decryption simply fails)
  /// and the file would be quarantined as corrupt.
  ///
  /// A hash of the key reveals nothing about the key itself; 8 bytes are ample
  /// to distinguish installations, and it is not a security boundary anyway —
  /// AES-GCM's MAC still decides whether the data is authentic.
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
      // `v` bleibt bewusst bei 1: `keyId` ist ein *additives* Feld, und
      // _isEnvelope prüft nur die vier bekannten Schlüssel. Eine ältere
      // App-Version liest eine neu geschriebene Datei damit weiterhin
      // anstandslos — ein Versionsbump hätte genau das gebrochen. Gleiches
      // Muster wie die additiven `meta`-Felder in AppSchema.
      'v': _envelopeVersion,
      'keyId': await keyFingerprint(_requireKey),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

  /// Der vom Betriebssystem vorgesehene Ort — und bewusst der **einzige**.
  ///
  /// Ein frei wählbarer Ordner wurde erwogen und wieder verworfen: der einzige
  /// Grund, ihn zu wollen, ist "dann liegt meine Datei in einem Ordner, der in
  /// die Cloud gesichert wird" — und genau das leistet er nicht. Die Datei ist
  /// mit einem Schlüssel verschlüsselt, der auf diesem Gerät liegt; geht das
  /// Gerät kaputt, ist auch die schönste Cloud-Kopie nicht mehr zu öffnen. Ein
  /// Ordnerdialog würde also eine Sicherheit versprechen, die nicht existiert.
  /// Wer ein wiederherstellbares Backup will, nimmt den Export (auf Wunsch mit
  /// Passwort, siehe `data/backup_crypto.dart`) — der ist gerätunabhängig.
  /// Siehe AI_MASTER §4.1.
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

  /// True under `flutter test`, which sets this env var. Used to skip the
  /// subprocess-based permission hardening below: `Process.run` never
  /// completes inside the fake-async clock a `testWidgets` body runs under,
  /// so shelling out on every persist would hang the widget tests. The
  /// hardening is only meaningful for the real per-user data directory
  /// anyway, not a throwaway test temp dir.
  static bool get _inFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _chmod(String path, String mode) async {
    if (_inFlutterTest) return;
    if (!Platform.isLinux && !Platform.isMacOS) return; // not applicable on Windows
    try {
      await Process.run('chmod', [mode, path]);
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Windows counterpart to [_chmod] — NTFS has no chmod bits, but `icacls`
  /// (built into every edition, no elevation needed on a folder/file you
  /// own) gets the same "current user only" effect via ACLs. Applied to the
  /// data directory with inheritable flags, so every file created inside it
  /// afterwards — including the corrupt-file and pre-import backups written
  /// later in this class — picks up the same restriction automatically,
  /// without each call site needing to remember to lock its own file down.
  Future<void> _restrictWindowsAccess(String path, {required bool isDirectory}) async {
    if (_inFlutterTest) return;
    if (!Platform.isWindows) return;
    final user = Platform.environment['USERNAME'];
    if (user == null || user.isEmpty) return;
    final domain = Platform.environment['USERDOMAIN'];
    final principal = (domain != null && domain.isNotEmpty) ? '$domain\\$user' : user;
    final grant = isDirectory ? '$principal:(OI)(CI)F' : '$principal:F';
    try {
      await Process.run('icacls', [path, '/inheritance:r', '/grant:r', grant]);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    _key = await const SecureKeyStore().getOrCreateKey();

    // In-memory mode (widget tests): no directory, no file reads/writes —
    // just start from defaults. Every persist below is a no-op too.
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

    _filePath = p.join(dir.path, _storeFilename);
    _ratesFilePath = p.join(dir.path, _ratesFilename);
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
      final decoded = jsonDecode(raw);
      if (!_isEnvelope(decoded)) {
        // Not an encrypted envelope — an unexpected or foreign file shape.
        // Preserve it before overwriting so nothing is silently destroyed.
        await _quarantineFile(file, 'unreadable');
        _data = AppSchema.defaults();
        await _persist();
      } else {
        // Vor dem Entschlüsselungsversuch: gehört die Datei überhaupt zu
        // diesem Rechner? Ohne diese Prüfung wäre ein fremder Schlüssel von
        // einer beschädigten Datei nicht zu unterscheiden (beides scheitert
        // beim Entschlüsseln) und liefe unten in Quarantäne + Leerstart.
        // Dateien ohne `keyId` stammen aus der Zeit vor diesem Feld und
        // nehmen weiterhin den bisherigen Weg.
        final storedKeyId = (decoded as Map)['keyId'];
        if (storedKeyId is String && storedKeyId != await keyFingerprint(_requireKey)) {
          throw ForeignKeyDataException(_filePath!);
        }
        final parsed = jsonDecode(await _decryptEnvelope(decoded));
        final onDiskVersion = (parsed is Map && parsed['schemaVersion'] is num) ? parsed['schemaVersion'] as num : null;
        final validated = AppSchema.fromDynamic(parsed);
        if (validated == null) {
          await _quarantineFile(file, 'unreadable');
          _data = AppSchema.defaults();
          await _persist();
        } else if (onDiskVersion != null && onDiskVersion > currentSchemaVersion) {
          // Downgrade guard: this file was written by a NEWER build. Parsing it
          // here would silently drop fields this older build doesn't understand
          // and then overwrite the user's only copy with a lossy re-write.
          // Preserve the newer file verbatim and start fresh instead — the
          // kept copy lets the user recover by updating the app. Mirrors the
          // import-side check ([UnsupportedBackupVersionException]) for the
          // everyday load path, which otherwise had no version guard at all.
          await _quarantineFile(file, 'newer-version');
          _data = AppSchema.defaults();
          await _persist();
        } else {
          final needsMigration = onDiskVersion != null && onDiskVersion < currentSchemaVersion;
          if (needsMigration) {
            // Snapshot the pre-migration file byte-for-byte (it's already an
            // encrypted envelope) BEFORE this build ever rewrites it in the new
            // format, so a botched forward-migration is always recoverable.
            await _writePreMigrationBackup(file);
          }
          // This build now owns the data: stamp it with the current version so
          // subsequent persists/exports carry it.
          validated.schemaVersion = currentSchemaVersion;
          _data = validated;
          // Make the upgraded shape + version bump durable immediately, rather
          // than waiting for the user's next mutation, so the on-disk file and
          // its pre-migration backup can't drift apart across restarts.
          if (needsMigration) await _persist();
        }
      }
    } on ForeignKeyDataException {
      // Muss am Auffangnetz unten vorbei: die Datei ist heil, sie gehört nur
      // zu einem anderen Rechner. Nicht verschieben, nicht überschreiben —
      // main() zeigt eine Erklärung, der Nutzer entscheidet.
      rethrow;
    } catch (_) {
      // File missing (first run) -> start fresh, nothing to lose. File
      // present but unreadable (corrupt JSON, wrong shape, tampered/failed
      // envelope decryption, ...) -> preserve it under a new name first,
      // since the next line would otherwise silently overwrite the user's
      // only copy of their data with empty defaults.
      if (fileExisted) await _quarantineFile(file, 'unreadable');
      _data = AppSchema.defaults();
      await _persist();
    }

    await _loadRatesCache();
    // One-time migration: older stores kept the rate cache inside the
    // encrypted database. Lift any such entries into the standalone rates
    // file, then drop them from the in-memory store so the next persist
    // writes the database without them.
    if (_data!.ratesCache.isNotEmpty) {
      _ratesCache.addAll(_data!.ratesCache);
      _data!.ratesCache = {};
      await _persistRates();
    }

    _initialized = true;
  }

  /// Loads the standalone rate cache. A missing file just means "nothing
  /// cached yet"; a corrupt one is disposable (rates are re-fetchable), so a
  /// parse failure is swallowed rather than surfaced.
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

  /// Filesystem-safe timestamp suffix (no `:`/`.`) shared by every
  /// side-file this class writes (quarantine copies, pre-import/-reset
  /// snapshots).
  static String _timestampSuffix() => DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');

  /// Best-effort copy of a store file that this build won't adopt, so a corrupt,
  /// unexpectedly-shaped, or newer-schema file never gets silently destroyed by
  /// [_persist] writing fresh defaults over it. [reason] becomes part of the
  /// side-file name (`<file>.<reason>-<timestamp>`): `unreadable` for corrupt/
  /// foreign/undecryptable files, `newer-version` for a file written by a newer
  /// build (downgrade guard). A failed copy must not block startup.
  Future<void> _quarantineFile(File file, String reason) async {
    try {
      await file.copy('${file.path}.$reason-${_timestampSuffix()}');
    } catch (_) {}
  }

  /// Byte-for-byte copy of the encrypted store file, taken before a forward
  /// schema migration rewrites it in the new format, so a botched migration
  /// stays recoverable. Best-effort — a failed copy must not block startup.
  Future<void> _writePreMigrationBackup(File file) async {
    try {
      await file.copy(p.join(file.parent.path, 'pre-migrate-backup-${_timestampSuffix()}.json'));
    } catch (_) {}
  }

  /// Best-effort snapshot of the current state, written alongside the main
  /// store file before a destructive one-way action (import, reset). Must
  /// never throw or block the action it precedes.
  Future<void> _writeSnapshotBackup(String label, Map<String, dynamic> snapshot) async {
    if (!persistToDisk) return;
    try {
      final backupFile = File(p.join(File(filePath).parent.path, 'pre-$label-backup-${_timestampSuffix()}.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
      final envelopeJson = await _encryptToEnvelope(jsonStr);
      await backupFile.writeAsString(envelopeJson, flush: true);
    } catch (_) {}
  }

  /// Atomically writes [content] to [path]: write to a sibling `.tmp` file,
  /// delete any existing file, then rename the temp file into place — so a
  /// crash mid-write never leaves a half-written file behind. Shared by
  /// [_persistNow] (encrypted database) and [_persistRatesNow] (plain rate
  /// cache); callers serialize their own calls through [_enqueueWrite].
  Future<void> _atomicWrite(String path, String content) async {
    if (!persistToDisk) return;
    final file = File(path);
    final tmpFile = File('$path.tmp');
    try {
      await tmpFile.writeAsString(content, flush: true);
      if (await file.exists()) {
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

  /// Encrypts and writes the whole database. Serialized through the write
  /// queue so it can never interleave with another save on the shared temp
  /// file.
  Future<void> _persist() => _enqueueWrite(_persistNow);

  Future<void> _persistNow() async {
    if (!persistToDisk) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_requireData.toJson());
    final envelopeJson = await _encryptToEnvelope(jsonStr);
    await _atomicWrite(filePath, envelopeJson);
  }

  /// Writes the standalone (unencrypted) rate cache. Same atomic temp-file
  /// dance as [_persistNow] and routed through the same write queue, but it
  /// only ever touches the small rates file — not the encrypted database.
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

  /// Changing [value] counts as a fresh re-evaluation today — that drives the
  /// 6-month reminder without needing a separate "re-evaluate" button. Also
  /// resolves this asset's overdue-notification episode (see
  /// [assetOverdueNotifiedIds]), so it can notify again next time it's overdue.
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

  /// Also resolves the backup-overdue notification episode (see
  /// [backupOverdueNotified]), so it can notify again next time it's overdue.
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

  // ---------- Reminder-Benachrichtigungen (OS-Notifications) ----------

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

  // ---------- Wechselkurs-Abruf (Opt-in) ----------

  RateFetchConsent get rateFetchConsent => _requireData.rateFetchConsent;

  /// Einzige Stelle, an der entschieden wird, ob die App die Kurs-API
  /// kontaktieren darf. `unset` zählt bewusst als **nicht** erlaubt: solange
  /// niemand gefragt wurde, geht nichts raus.
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

  /// Wipes everything back to a fresh install: all accounts, balances,
  /// assets and subscriptions gone, settings back to their defaults. Window
  /// geometry is deliberately preserved — it isn't a user-visible "setting"
  /// and resetting it would just move/resize the window unexpectedly.
  ///
  /// Snapshots the pre-reset state first (mirroring [importAllData]'s
  /// pre-import snapshot) since this is the app's other genuinely
  /// irreversible action, then rolls the in-memory replacement back if the
  /// write itself fails.
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

  // ---------- Fenstergeometrie ----------

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

  /// Replaces ALL data with the contents of an imported backup. Returns a
  /// snapshot of the previous state (useful for a future undo). The same
  /// snapshot is also written to disk first (best-effort) so an accidental
  /// import of the wrong file — confirmed by the user, but still a one-way
  /// door in the UI today — leaves a recovery copy behind.
  Future<Map<String, dynamic>> importAllData(Map<String, dynamic> imported) async {
    // Reject backups written by a newer schema than this build understands.
    // Silently importing could drop or misread fields this version doesn't
    // know about — better to fail loudly and ask the user to update. Older
    // or equal versions are always accepted (per-entry parsing below already
    // tolerates missing fields).
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

    // Enforce the bank→color invariant on import: a known bank fixes the brand
    // color, an empty bank falls back to the Kontotyp color, and an UNKNOWN
    // (non-empty) bank aborts the whole import — no silent wrong color. Done
    // before touching `data`, so a bad backup leaves the current data intact.
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

    // Snapshotted so a failed persist below can roll the in-memory store back
    // to exactly what it held before this import (mirrors every other
    // mutator's rollback-on-failed-persist behavior).
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
