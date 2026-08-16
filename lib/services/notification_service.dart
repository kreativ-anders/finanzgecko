import 'package:local_notifier/local_notifier.dart';

/// Thin wrapper around `local_notifier` (native OS Benachrichtigungen for
/// Linux/macOS/Windows). Best-effort: a missing notification daemon (Linux) or
/// a denied permission (macOS) must never crash the app, so errors are
/// swallowed here instead of propagated.
class NotificationService {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await localNotifier.setup(appName: 'FinanzGecko');
      _initialized = true;
    } catch (_) {
      // No notification backend available — Benachrichtigungen stay off, the
      // rest of the app works unchanged.
    }
  }

  Future<void> show({required String title, required String body}) async {
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {
      // See init(): best-effort, never fatal.
    }
  }
}
