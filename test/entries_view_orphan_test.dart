import 'package:finanzgecko/data/app_store.dart';
import 'package:finanzgecko/state/app_state.dart';
import 'package:finanzgecko/ui/views/entries_view.dart';
import 'package:finanzgecko/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Fakes the flutter_secure_storage platform channel with an in-memory map —
/// same approach as app_store_encryption_test.dart — so these widget tests
/// exercise the real AppStore without needing a real OS keychain.
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
    // In-memory: widget tests run under a fake-async clock that never pumps
    // the real event loop, so any real dart:io file I/O would hang. See the
    // AppStore(persistToDisk:) doc. Persistence is covered by the plain
    // test()-based store tests instead.
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

  // The default test surface (800x600) is smaller than the app's real minimum
  // window and clips the archived-accounts section, so its buttons render
  // off-screen and tap() misses them. Give the tests a tall surface so the
  // whole view is laid out and hit-testable. Reset after each test.
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('archived account balance shows under "Archivierte Konten" with a Wiederherstellen action', (
    tester,
  ) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    final archived = await store.addAccount(name: 'Altes Konto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await store.upsertBalance(
      accountId: archived.id,
      period: currentPeriod(),
      amountOriginal: 500,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 500,
    );
    await store.archiveAccount(archived.id);
    // A live account keeps EntriesView out of its "no accounts yet" empty state.
    await store.addAccount(name: 'Girokonto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    expect(find.text('Archivierte Konten'), findsOneWidget);
    expect(find.text('Altes Konto'), findsOneWidget);
    expect(find.text('Wiederherstellen'), findsOneWidget);
    expect(find.text('Bearbeiten'), findsNothing);

    await tester.tap(find.text('Wiederherstellen'));
    await tester.pumpAndSettle();

    expect(store.getAccount(archived.id)!.archived, isFalse);
    // Restored account's balance moves back into the normal editable list,
    // so the whole archived-accounts section disappears.
    expect(find.text('Archivierte Konten'), findsNothing);
  });

  testWidgets('Löschen permanently removes the orphaned balance entry', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    final archived = await store.addAccount(name: 'Altes Konto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await store.upsertBalance(
      accountId: archived.id,
      period: currentPeriod(),
      amountOriginal: 500,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 500,
    );
    await store.archiveAccount(archived.id);
    await store.addAccount(name: 'Girokonto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Eintrag löschen'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Löschen'));
    await tester.pumpAndSettle();

    expect(store.getAllBalances(), isEmpty);
    expect(find.text('Archivierte Konten'), findsNothing);
    // The account itself stays archived — only the balance entry was killed.
    expect(store.getAccount(archived.id)!.archived, isTrue);
  });

  testWidgets('existing balance prefills the amount field with German grouping, not raw toString', (tester) async {
    useLargeSurface(tester);
    final appState = await bootAppState();
    final store = appState.store;
    final acc = await store.addAccount(name: 'Konto', tag: 'giro', currency: 'EUR', color: '#00c878');
    await store.upsertBalance(
      accountId: acc.id,
      period: currentPeriod(),
      amountOriginal: 12345.6,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 12345.6,
    );
    await appState.init();

    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '12.345,6');
  });
}
