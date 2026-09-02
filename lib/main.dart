import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'constants.dart';
import 'data/app_schema.dart';
import 'data/app_store.dart';
import 'data/crypto_platform.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'ui/backup_actions.dart';
import 'ui/navigation_shell.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/app_snackbar.dart';

/// Persists window size + maximized state (best-effort, debounced) so the app reopens as it was left.
class _WindowPrefsSaver with WindowListener {
  _WindowPrefsSaver(this.store);

  final AppStore store;
  Timer? _debounce;

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final maximized = await windowManager.isMaximized();
    final size = await windowManager.getSize();
    await store.setWindowPrefs(WindowPrefs(width: size.width, height: size.height, maximized: maximized));
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INFO: the only way to check which crypto implementation is live in a signed build, see dev/ai/persistence.md.
  debugPrint(describeCryptoPlatform());

  try {
    final store = AppStore();
    await store.ensureInitialized();
    await _startApp(store);
  } on ForeignKeyDataException catch (err) {
    // INFO: debug-gated unlike the case below: debugPrint reaches the OS log, and this line carries the data path.
    if (kDebugMode) {
      debugPrint('FinanzGecko: data file belongs to a different installation: ${err.filePath}');
    }
    runApp(const _ForeignDataApp());
  } catch (err, stack) {
    // INFO: deliberately not debug-gated — the one message an "it won't start" report needs, carrying no user data.
    debugPrint('FinanzGecko startup failed: $err\n$stack');
    runApp(_StartupErrorApp(error: err));
  }
}

/// The single path into the real UI: window, notifications and [AppState] on top of an initialized [AppStore].
// INFO: also called from [_ForeignDataApp] once the user resolved a foreign data file, hence not inlined in main().
Future<void> _startApp(AppStore store) async {
  final windowPrefs = store.windowPrefs;

  // WARNING: must precede WindowOptions — its backgroundColor reads kBackground, still the dark default here.
  primeThemeBrightness(store.themeMode);

  await windowManager.ensureInitialized();
  final windowOptions = WindowOptions(
    size: Size(windowPrefs.width, windowPrefs.height),
    minimumSize: const Size(960, 640),
    center: true,
    title: 'FinanzGecko',
    backgroundColor: kBackground,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (windowPrefs.maximized) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });
  windowManager.addListener(_WindowPrefsSaver(store));

  final notificationService = NotificationService();
  await notificationService.init();

  final appState = AppState(store, notificationService: notificationService);
  await appState.init();

  runApp(FinanzGeckoApp(appState: appState));
}

/// Explains in everyday language — without "key", "keychain" or "encryption" — why a file from elsewhere won't
/// open, and offers the two ways on: import a backup, or start empty. Never a dead end.
// INFO: the store build hits this on the SAME Mac after a channel switch, where "anderer Computer" would be wrong.
// INFO: why the two builds share a container but not a key: dev/ai/persistence.md "Channel switch".
class _ForeignDataApp extends StatefulWidget {
  const _ForeignDataApp();

  @override
  State<_ForeignDataApp> createState() => _ForeignDataAppState();
}

class _ForeignDataAppState extends State<_ForeignDataApp> {
  bool _busy = false;
  String? _error;

  Future<void> _importBackup() async {
    final file = await openFile(acceptedTypeGroups: backupTypeGroups);
    if (file == null || !mounted) return; // dialog cancelled
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await file.readAsString();
      if (!mounted) return;
      final payload = await decodeBackupPayload(context, raw);
      if (payload == null) {
        // Password dialog cancelled — back to the explanation, nothing touched.
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _resumeWith(payload);
    } catch (err) {
      _failed(err);
    }
  }

  Future<void> _startEmpty() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _resumeWith(null);
    } catch (err) {
      _failed(err);
    }
  }

  /// Boots the app on a store that leaves the foreign file alone; [payload] is imported before the first frame.
  Future<void> _resumeWith(Map<String, dynamic>? payload) async {
    final store = AppStore(ignoreForeignData: true);
    await store.ensureInitialized();
    if (payload != null) await store.importAllData(payload);
    await _startApp(store);
  }

  void _failed(Object err) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = describeError(err);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanzGecko',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: kBackground,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: kPrimary, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    kIsMacAppStore
                        ? 'Diese Daten gehören zur anderen FinanzGecko-Version'
                        : 'Diese Datei gehört zu einem anderen Computer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kIsMacAppStore
                        ? 'Deine Daten sind so gespeichert, dass nur die FinanzGecko-Version sie lesen kann, mit '
                              'der du sie angelegt hast. Diese Daten stammen von der Version aus dem Download auf '
                              'finanzgecko.app — die App-Store-Version kann sie deshalb nicht öffnen.'
                        : 'Deine Daten sind so gespeichert, dass nur der Computer sie lesen kann, auf dem sie '
                              'angelegt wurden. Diese Datei wurde auf einem anderen Computer erstellt und lässt '
                              'sich hier deshalb nicht öffnen.',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kIsMacAppStore
                        ? 'So holst du sie hierher: Öffne noch einmal die Version von finanzgecko.app und wähle '
                              'dort "Backup exportieren". Die entstandene Datei liest du hier unten über "Backup '
                              'importieren" ein.'
                        : 'So holst du sie hierher: Öffne FinanzGecko auf dem ursprünglichen Computer und wähle '
                              'dort "Backup exportieren". Die entstandene Datei liest du hier unten über "Backup '
                              'importieren" ein.',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _busy ? null : _importBackup,
                        child: noSelect(const Text('Backup importieren…')),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _startEmpty,
                        child: noSelect(const Text('Ohne Daten starten')),
                      ),
                      if (_busy)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: kDangerText, height: 1.5)),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Es wird nichts verändert und nichts gelöscht — auch nicht, wenn du ohne Daten startest. Die '
                    'andere Datei bleibt unangetastet an ihrem Platz, falls du sie später doch noch brauchst.',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Startup-failure fallback UI, deliberately free of [AppState]/[AppStore] — those may be what failed.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanzGecko',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: kBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: kDanger, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'FinanzGecko konnte nicht gestartet werden.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: TextStyle(color: kMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanzGeckoApp extends StatelessWidget {
  const FinanzGeckoApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      // WARNING: keep the inner Builder — buildAppTheme() must run inside ThemeScope, not as its child argument.
      child: Consumer<AppState>(
        builder: (context, app, _) => ThemeScope(
          mode: app.themeMode,
          child: Builder(
            builder: (context) => MaterialApp(
              title: 'FinanzGecko',
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: const SelectionArea(child: SplashScreen(child: NavigationShell())),
            ),
          ),
        ),
      ),
    );
  }
}
