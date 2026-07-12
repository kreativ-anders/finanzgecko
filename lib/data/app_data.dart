import '../models/account.dart';
import '../models/asset.dart';
import '../models/balance.dart';
import '../models/subscription.dart';

const int currentSchemaVersion = 1;

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

/// In-memory representation of the whole app database — a single JSON file
/// on disk, mirroring the previous Neutralino `store.js` schema so existing
/// exports/backups stay readable.
class AppData {
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

  AppData({
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
  });

  factory AppData.defaults() => AppData(
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

  /// Parses a decoded JSON value. Returns null if it isn't a usable object
  /// at all (caller then falls back to fresh [AppData.defaults]). Individual
  /// malformed list entries are skipped rather than failing the whole file.
  static AppData? fromDynamic(dynamic parsed) {
    if (parsed is! Map) return null;
    final json = parsed;

    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      final result = <T>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(fromJson(item));
          } catch (_) {
            // Skip malformed entry, keep the rest of the file usable.
          }
        } else if (item is Map) {
          try {
            result.add(fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      return result;
    }

    final meta = (json['meta'] is Map) ? Map<String, dynamic>.from(json['meta'] as Map) : <String, dynamic>{};
    final windowRaw = (json['window'] is Map) ? Map<String, dynamic>.from(json['window'] as Map) : null;
    final ratesRaw = (json['ratesCache'] is Map) ? Map<String, dynamic>.from(json['ratesCache'] as Map) : <String, dynamic>{};

    // Cached rates are just an optimization (re-fetchable from the API), so a
    // single malformed entry here must never cost the caller its accounts,
    // balances, assets and subscriptions — skip the bad entry instead of
    // throwing, which would otherwise abort parsing of the whole file.
    final ratesCache = <String, double>{};
    for (final entry in ratesRaw.entries) {
      final v = entry.value;
      if (v is num) ratesCache[entry.key] = v.toDouble();
    }

    final lastExportAtRaw = meta['lastExportAt'];

    return AppData(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      baseCurrency: json['baseCurrency'] is String ? json['baseCurrency'] as String : 'EUR',
      accounts: parseList('accounts', Account.fromJson),
      balances: parseList('balances', Balance.fromJson),
      assets: parseList('assets', Asset.fromJson),
      subscriptions: parseList('subscriptions', Subscription.fromJson),
      ratesCache: ratesCache,
      nextAccountId: (meta['nextAccountId'] as num?)?.toInt() ?? 1,
      nextBalanceId: (meta['nextBalanceId'] as num?)?.toInt() ?? 1,
      nextAssetId: (meta['nextAssetId'] as num?)?.toInt() ?? 1,
      nextSubscriptionId: (meta['nextSubscriptionId'] as num?)?.toInt() ?? 1,
      lastExportAt: lastExportAtRaw is String ? DateTime.tryParse(lastExportAtRaw) : null,
      window: windowRaw != null ? WindowPrefs.fromJson(windowRaw) : WindowPrefs.defaults(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'baseCurrency': baseCurrency,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'balances': balances.map((b) => b.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'ratesCache': ratesCache,
    'meta': {
      'nextAccountId': nextAccountId,
      'nextBalanceId': nextBalanceId,
      'nextAssetId': nextAssetId,
      'nextSubscriptionId': nextSubscriptionId,
      'lastExportAt': lastExportAt?.toIso8601String(),
    },
    'window': window.toJson(),
  };

  /// Shape written by "Backup exportieren" / read by "Backup importieren" —
  /// intentionally excludes ratesCache/meta/window (internal-only state).
  Map<String, dynamic> toExportJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'baseCurrency': baseCurrency,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'balances': balances.map((b) => b.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
  };
}
