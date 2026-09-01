// Gherkin: gherkin/assets.feature
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:finanzgecko/ui/views/assets_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Same fake-secure-storage approach as entries_view_orphan_test.dart, so this widget test exercises the
/// real AppStore without a real OS keychain.
class _FakeSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;

  static const MethodChannel _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'read':
          return values[(call.arguments as Map)['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          values[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          values.remove((call.arguments as Map)['key'] as String);
          return null;
        case 'readAll':
          return values;
        case 'deleteAll':
          values.clear();
          return null;
        case 'containsKey':
          return values.containsKey((call.arguments as Map)['key'] as String);
        default:
          return null;
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> bootAppState() async {
    _FakeSecureStorage(<String, String>{}).install();
    final store = AppStore(persistToDisk: false);
    await store.ensureInitialized();
    final appState = AppState(store);
    await appState.init();
    return appState;
  }

  Widget wrap(AppState appState) {
    return MaterialApp(
      home: ChangeNotifierProvider.value(
        value: appState,
        child: Scaffold(body: AssetsView(onNavigate: (_) {})),
      ),
    );
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder byLabel(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);

  testWidgets('the list is ordered by value, highest first', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    await store.addAsset(name: 'Fahrrad', value: 500);
    await store.addAsset(name: 'MacBook Pro', value: 2000);
    await store.addAsset(name: 'Sofa', value: 800);
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    double dyOf(String name) => tester.getTopLeft(find.text(name)).dy;

    expect(dyOf('MacBook Pro'), lessThan(dyOf('Sofa')));
    expect(dyOf('Sofa'), lessThan(dyOf('Fahrrad')));
  });

  testWidgets('Enter in the "Neuer Vermögenswert" form submits it, same as clicking "Anlegen"', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.enterText(byLabel('Bezeichnung'), 'Fernseher');
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith('Wert')),
      '600',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.getAssets().map((a) => a.name), contains('Fernseher'));
  });
}
