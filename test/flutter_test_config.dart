import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auto-discovered by `flutter test` and wrapped around every test file in
/// this directory tree. Installs a mock handler for the
/// `flutter_local_notifications` platform channel so that constructing an
/// [AppState] with its default (real) NotificationService — as most existing
/// tests do, having no reason to know about the notification feature — never
/// makes a genuine platform-channel round trip. Without this, that call can
/// hang inside a testWidgets fake-async zone instead of failing fast. See
/// lib/services/notification_service.dart and AppStore(persistToDisk:) for
/// the same "keep real platform I/O out of tests" idea applied elsewhere.
///
/// `requestPermissions` answers true so a test that switches the toggle on
/// gets the granted path by default; a test that needs the denied path injects
/// its own fake NotificationService instead of relying on this handler.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => switch (call.method) {
      'initialize' => true,
      'requestPermissions' => true,
      _ => null,
    },
  );
  await testMain();
}
