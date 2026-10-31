// Renders website screenshots headless from the demo data — never the user's data file. Recipe: dev/ai/screenshots.md.
//
//   flutter test tool/screenshots/website_screenshots_test.dart
//
// macOS only: it renders with the system font (SF) so the shots look like the real app.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:finanzgecko/constants.dart';
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:finanzgecko/ui/theme.dart';
import 'package:finanzgecko/ui/views/entries_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

// Width of the app's centered content column (navigation_shell.dart) and Retina scale.
const double _kColumnWidth = 1100;
const double _kPixelRatio = 2;

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void _fakePlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final secrets = <String, String>{};
  messenger.setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async {
    final args = (call.arguments as Map?) ?? const {};
    return switch (call.method) {
      'read' => secrets[args['key']],
      'write' => secrets[args['key'] as String] = args['value'] as String,
      'delete' => secrets.remove(args['key']),
      'readAll' => secrets,
      'containsKey' => secrets.containsKey(args['key']),
      _ => null,
    };
  });
  messenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' || call.method == 'requestPermissions',
  );
}

Future<AppState> _demoAppState() async {
  final store = AppStore(persistToDisk: false);
  await store.ensureInitialized();
  final appState = AppState(store);
  await appState.init();
  final demo = jsonDecode(File('demo/finanzgecko-demo.json').readAsStringSync()) as Map<String, dynamic>;
  await appState.importAllData(demo);
  return appState;
}

/// Writes [key]'s pixels down to [bottom] (logical px) — the same box for both themes, so each pair matches in size.
Future<void> _capture(WidgetTester tester, GlobalKey key, double bottom, String theme, String slug) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _kPixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final full = img.decodePng(png!.buffer.asUint8List())!;
    final cropped = img.copyCrop(full, x: 0, y: 0, width: full.width, height: (bottom * _kPixelRatio).round());
    File('build/screenshots/$theme/$slug.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(cropped));
  });
}

void main() {
  setUpAll(() async {
    _fakePlatformChannels();
    // Material falls back to Roboto on the test platform; map it to SF like the macOS app.
    await _loadFont('Roboto', '/System/Library/Fonts/SFNS.ttf');
    await _loadFont(
      'MaterialIcons',
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  });

  for (final theme in [AppThemeMode.dark, AppThemeMode.light]) {
    testWidgets('finanzgecko-kontostaende-monatlich-erfassen (${theme.name})', (tester) async {
      tester.view.physicalSize = const Size(_kColumnWidth, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final appState = (await tester.runAsync(_demoAppState))!;
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: ThemeScope(
            mode: theme,
            child: Builder(
              builder: (context) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: key,
                      child: ColoredBox(
                        color: kBackground,
                        child: EntriesView(onNavigate: (_) {}),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // No focused field: a caret in the first Betrag would end up on the website.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final cardBottom = tester.getRect(find.byType(Card).first).bottom;
      await _capture(tester, key, cardBottom + 24, theme.name, 'finanzgecko-kontostaende-monatlich-erfassen');
    });
  }
}
