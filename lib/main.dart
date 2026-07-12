import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'data/app_data.dart';
import 'data/app_store.dart';
import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

/// Persists window size + maximized state (best-effort, debounced) so the
/// app reopens the way it was left — the previous Neutralino build got this
/// for free via `"useSavedState": true`.
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

  final store = AppStore();
  await store.ensureInitialized();
  final windowPrefs = store.windowPrefs;

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

  final appState = AppState(store);
  await appState.init();

  runApp(FinanzGeckoApp(appState: appState));
}

class FinanzGeckoApp extends StatelessWidget {
  const FinanzGeckoApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'FinanzGecko',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    );
  }
}
