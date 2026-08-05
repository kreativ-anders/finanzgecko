import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'data/app_schema.dart';
import 'data/app_store.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'ui/navigation_shell.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

/// Persists window size + maximized state (best-effort, debounced) so the
/// app reopens the way it was left.
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

  try {
    final store = AppStore();
    await store.ensureInitialized();
    final windowPrefs = store.windowPrefs;

    // Muss vor dem WindowOptions-Aufbau stehen: dessen backgroundColor liest
    // kBackground, und das steht ohne diesen Aufruf noch auf dem dunklen
    // Standard, weil ThemeScope erst nach runApp() baut.
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
  } on ForeignKeyDataException catch (err) {
    // Kein Fehler im eigentlichen Sinn, sondern eine Situation, die erklärt
    // werden muss: die Datei ist in Ordnung, sie gehört nur zu einem anderen
    // Computer. Wichtig ist vor allem, was hier NICHT passiert — es wird
    // nichts verschoben und nichts geschrieben.
    debugPrint('FinanzGecko: Datei gehört zu einer anderen Installation: ${err.filePath}');
    runApp(_ForeignDataApp(filePath: err.filePath));
  } catch (err, stack) {
    // A failure this early (e.g. no OS keychain/secret-service daemon
    // available for SecureKeyStore) would otherwise crash before a single
    // frame is drawn, with nothing shown to the user at all — show a
    // minimal, dependency-free error screen instead of a silent crash.
    debugPrint('FinanzGecko startup failed: $err\n$stack');
    runApp(_StartupErrorApp(error: err));
  }
}

/// Erklärt in Alltagssprache, warum eine mitgebrachte Datendatei sich hier
/// nicht öffnen lässt — ohne "Schlüssel", "Keychain" oder "Verschlüsselung"
/// als Erklärung zu benutzen. Wer die Datei aus einem Cloud-Ordner kennt,
/// erwartet, dass sie sich überall öffnen lässt; diese Erwartung muss der
/// Text abräumen und gleichzeitig sagen, was stattdessen zu tun ist.
class _ForeignDataApp extends StatelessWidget {
  const _ForeignDataApp({required this.filePath});

  final String filePath;

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
                    'Diese Datei gehört zu einem anderen Computer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deine Daten sind so gespeichert, dass nur der Computer sie lesen kann, auf dem sie '
                    'angelegt wurden. Diese Datei wurde auf einem anderen Computer erstellt und lässt '
                    'sich hier deshalb nicht öffnen.',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Um deine Daten hierher zu holen, öffne FinanzGecko auf dem ursprünglichen Computer, '
                    'wähle dort "Backup exportieren" und lies die entstandene Datei hier über '
                    '"Backup importieren" wieder ein.',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Es wurde nichts verändert und nichts gelöscht. Die Datei liegt unverändert hier:',
                    style: TextStyle(color: kMuted, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(filePath, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal fallback UI for a startup failure — deliberately doesn't depend on
/// [AppState]/[AppStore] (those are exactly what may have failed to
/// initialize), so it has nothing else that could fail along the way.
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
      // Consumer rebuilds this subtree whenever AppState changes (including
      // setThemeMode), and ThemeScope resolves the active brightness before
      // its child is built. The inner Builder matters: buildAppTheme() must
      // run *during* a build that's a descendant of ThemeScope, not while
      // MaterialApp is merely being constructed as ThemeScope's child
      // argument (which would happen too early, against the previous
      // brightness).
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
