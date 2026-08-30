import '../constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';

const int currentSchemaVersion = 1;

/// Parses a JSON list tolerantly: a malformed entry is skipped instead of costing the caller the whole list.
List<T> parseTolerantList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  final result = <T>[];
  for (final item in raw) {
    if (item is Map) {
      try {
        result.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed entry, keep the rest of the list usable.
      }
    }
  }
  return result;
}

/// Remembered window geometry, restored on next launch (best-effort).
class WindowPrefs {
  final double width;
  final double height;
  final bool maximized;

  const WindowPrefs({required this.width, required this.height, required this.maximized});

  factory WindowPrefs.defaults() => const WindowPrefs(width: 1280, height: 860, maximized: true);

  factory WindowPrefs.fromJson(Map<String, dynamic> json) => WindowPrefs(
    width: json['width'] is num ? (json['width'] as num).toDouble() : 1280,
    height: json['height'] is num ? (json['height'] as num).toDouble() : 860,
    maximized: json['maximized'] is bool ? json['maximized'] as bool : true,
  );

  Map<String, dynamic> toJson() => {'width': width, 'height': height, 'maximized': maximized};
}

/// In-memory image of the whole app database — one JSON file on disk.
class AppSchema {
  int schemaVersion;
  String baseCurrency;
  List<Account> accounts;
  List<Balance> balances;
  List<Asset> assets;
  List<Subscription> subscriptions;
  Map<String, double> ratesCache;
  int nextAccountId;
  int nextBalanceId;
  int nextAssetId;
  int nextSubscriptionId;
  DateTime? lastExportAt;
  WindowPrefs window;

  // WARNING: persisted as `notificationsOptIn`, not this field name — the old key would opt existing files in.
  bool notificationsEnabled;
  bool backupOverdueNotified;
  List<int> assetOverdueNotifiedIds;

  /// Einstellungen → Erscheinungsbild (system/light/dark), default: system.
  AppThemeMode themeMode;

  /// Consent for fetching Wechselkurse; an absent key yields `unset`, so the app asks once instead of assuming.
  RateFetchConsent rateFetchConsent;

  AppSchema({
    required this.schemaVersion,
    required this.baseCurrency,
    required this.accounts,
    required this.balances,
    required this.assets,
    required this.subscriptions,
    required this.ratesCache,
    required this.nextAccountId,
    required this.nextBalanceId,
    required this.nextAssetId,
    required this.nextSubscriptionId,
    required this.lastExportAt,
    required this.window,
    this.notificationsEnabled = false,
    this.backupOverdueNotified = false,
    List<int>? assetOverdueNotifiedIds,
    this.themeMode = AppThemeMode.system,
    this.rateFetchConsent = RateFetchConsent.unset,
  }) : assetOverdueNotifiedIds = assetOverdueNotifiedIds ?? [];

  factory AppSchema.defaults() => AppSchema(
    schemaVersion: currentSchemaVersion,
    baseCurrency: 'EUR',
    accounts: [],
    balances: [],
    assets: [],
    subscriptions: [],
    ratesCache: {},
    nextAccountId: 1,
    nextBalanceId: 1,
    nextAssetId: 1,
    nextSubscriptionId: 1,
    lastExportAt: null,
    window: WindowPrefs.defaults(),
  );

  /// Parses a decoded JSON value; null if it isn't a usable object at all.
  static AppSchema? fromDynamic(dynamic parsed) {
    if (parsed is! Map) return null;
    final json = parsed;

    final meta = (json['meta'] is Map) ? Map<String, dynamic>.from(json['meta'] as Map) : <String, dynamic>{};
    final windowRaw = (json['window'] is Map) ? Map<String, dynamic>.from(json['window'] as Map) : null;
    final ratesRaw = (json['ratesCache'] is Map)
        ? Map<String, dynamic>.from(json['ratesCache'] as Map)
        : <String, dynamic>{};

    // INFO: legacy in-store rates, parsed only so [AppStore] can migrate them into their own file.
    final ratesCache = <String, double>{};
    for (final entry in ratesRaw.entries) {
      final v = entry.value;
      if (v is num) ratesCache[entry.key] = v.toDouble();
    }

    final lastExportAtRaw = meta['lastExportAt'];

    return AppSchema(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      baseCurrency: json['baseCurrency'] is String ? json['baseCurrency'] as String : 'EUR',
      accounts: parseTolerantList(json['accounts'], Account.fromJson),
      balances: parseTolerantList(json['balances'], Balance.fromJson),
      assets: parseTolerantList(json['assets'], Asset.fromJson),
      subscriptions: parseTolerantList(json['subscriptions'], Subscription.fromJson),
      ratesCache: ratesCache,
      nextAccountId: (meta['nextAccountId'] as num?)?.toInt() ?? 1,
      nextBalanceId: (meta['nextBalanceId'] as num?)?.toInt() ?? 1,
      nextAssetId: (meta['nextAssetId'] as num?)?.toInt() ?? 1,
      nextSubscriptionId: (meta['nextSubscriptionId'] as num?)?.toInt() ?? 1,
      lastExportAt: lastExportAtRaw is String ? DateTime.tryParse(lastExportAtRaw) : null,
      window: windowRaw != null ? WindowPrefs.fromJson(windowRaw) : WindowPrefs.defaults(),
      notificationsEnabled: meta['notificationsOptIn'] is bool ? meta['notificationsOptIn'] as bool : false,
      backupOverdueNotified: meta['backupOverdueNotified'] is bool ? meta['backupOverdueNotified'] as bool : false,
      assetOverdueNotifiedIds: meta['assetOverdueNotifiedIds'] is List
          ? [
              for (final v in meta['assetOverdueNotifiedIds'] as List)
                if (v is num) v.toInt(),
            ]
          : <int>[],
      themeMode: appThemeModeFromJson(meta['themeMode'] as String?),
      rateFetchConsent: rateFetchConsentFromJson(meta['rateFetchConsent'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'baseCurrency': baseCurrency,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'balances': balances.map((b) => b.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'meta': {
      'nextAccountId': nextAccountId,
      'nextBalanceId': nextBalanceId,
      'nextAssetId': nextAssetId,
      'nextSubscriptionId': nextSubscriptionId,
      'lastExportAt': lastExportAt?.toIso8601String(),
      'notificationsOptIn': notificationsEnabled,
      'backupOverdueNotified': backupOverdueNotified,
      'assetOverdueNotifiedIds': assetOverdueNotifiedIds,
      'themeMode': appThemeModeToJson(themeMode),
      'rateFetchConsent': rateFetchConsentToJson(rateFetchConsent),
    },
    'window': window.toJson(),
  };

  /// Shape written by "Backup exportieren" / read by "Backup importieren"; excludes internal-only state.
  Map<String, dynamic> toExportJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'baseCurrency': baseCurrency,
    // No color: it is re-derived from the bank on import.
    'accounts': accounts.map((a) => a.toExportJson()).toList(),
    'balances': balances.map((b) => b.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
  };
}
