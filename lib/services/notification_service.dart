import 'package:local_notifier/local_notifier.dart';

/// Thin wrapper around `local_notifier` (native OS-Benachrichtigungen für
/// Linux/macOS/Windows). Best-effort: ein fehlender Notification-Daemon
/// (Linux) oder eine verweigerte Berechtigung (macOS) darf die App nie zum
/// Absturz bringen, deshalb werden Fehler hier verschluckt statt propagiert.
class NotificationService {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await localNotifier.setup(appName: 'FinanzGecko');
      _initialized = true;
    } catch (_) {
      // Kein Notification-Backend verfügbar — Benachrichtigungen bleiben aus,
      // der Rest der App funktioniert unverändert.
    }
  }

  Future<void> show({required String title, required String body}) async {
    try {
      await LocalNotification(title: title, body: body).show();
    } catch (_) {
      // Siehe init(): best-effort, niemals fatal.
    }
  }
}
