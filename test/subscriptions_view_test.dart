// Gherkin: gherkin/subscriptions.feature
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:finanzgecko/ui/views/subscriptions_view.dart';
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
        child: Scaffold(body: SubscriptionsView(onNavigate: (_) {})),
      ),
    );
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder byNameFieldText(String name) => find.byWidgetPredicate((w) => w is TextField && w.controller?.text == name);

  Finder byLabel(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);

  testWidgets('income and expenses are each ordered by monthly amount, highest first', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    await store.addSubscription(
      name: 'Dividenden',
      interval: 'monthly',
      amountOriginal: 50,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 50,
    );
    await store.addSubscription(
      name: 'Gehalt',
      interval: 'monthly',
      amountOriginal: 3000,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 3000,
    );
    await store.addSubscription(
      name: 'Netflix',
      interval: 'monthly',
      amountOriginal: -15,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: -15,
    );
    await store.addSubscription(
      name: 'Miete',
      interval: 'monthly',
      amountOriginal: -1200,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: -1200,
    );
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    double dyOf(String name) => tester.getTopLeft(byNameFieldText(name)).dy;

    // Income group (highest first), then expense group (biggest expense first).
    expect(dyOf('Gehalt'), lessThan(dyOf('Dividenden')));
    expect(dyOf('Dividenden'), lessThan(dyOf('Miete')));
    expect(dyOf('Miete'), lessThan(dyOf('Netflix')));
  });

  testWidgets('Enter in the "Neuer Fixposten" form submits it, same as clicking "Anlegen"', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.enterText(byLabel('Name'), 'Spotify');
    await tester.enterText(byLabel('Betrag'), '9,99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.getSubscriptions().map((s) => s.name), contains('Spotify'));
  });
}
