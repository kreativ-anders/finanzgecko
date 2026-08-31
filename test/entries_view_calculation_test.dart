// Gherkin: gherkin/balances_entries.feature
import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:finanzgecko/ui/views/entries_view.dart';
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
        child: Scaffold(body: EntriesView(onNavigate: (_) {})),
      ),
    );
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('an arithmetic expression is evaluated and the sum is what gets saved', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    final acc = await store.addAccount(name: 'Trade Republic', tag: 'depot', currency: 'EUR', color: '#00c878');
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1300,12 +5201.75');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Alle speichern'));
    await tester.pumpAndSettle();

    final balances = store.getAllBalances();
    expect(balances, hasLength(1));
    expect(balances.first.accountId, acc.id);
    expect(balances.first.amountOriginal, closeTo(6501.87, 1e-9));
  });

  testWidgets('unparseable text is rejected on Enter: no save, a toast appears', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    await store.addAccount(name: 'Girokonto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '100x50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Ungültige Eingabe — nur Zahlen und Rechenzeichen (+ - * /) sind erlaubt.'), findsOneWidget);
    expect(store.getAllBalances(), isEmpty);
  });

  testWidgets('a plain number still saves as before (no regression)', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    final acc = await store.addAccount(name: 'Girokonto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1.234,56');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Alle speichern'));
    await tester.pumpAndSettle();

    final balances = store.getAllBalances();
    expect(balances, hasLength(1));
    expect(balances.first.accountId, acc.id);
    expect(balances.first.amountOriginal, closeTo(1234.56, 1e-9));
  });
}
