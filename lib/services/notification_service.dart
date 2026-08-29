import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around `flutter_local_notifications` (native OS Benachrichtigungen, Linux/macOS/Windows).
// INFO: best-effort throughout — a missing daemon (Linux) or denied authorization (macOS) never crashes.
// INFO: [requestPermission] is separate from [init] so macOS never shows its system dialog at startup.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin}) : _injectedPlugin = plugin;

  final FlutterLocalNotificationsPlugin? _injectedPlugin;

  /// Lazy on purpose: a test double overriding every method never constructs the real plugin.
  late final FlutterLocalNotificationsPlugin _plugin = _injectedPlugin ?? FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Identifies FinanzGecko to the Windows toast API.
  // WARNING: must stay stable — changing it makes Windows treat the notifications as a different app.
  static const String _windowsGuid = '71b365b0-9392-4a56-a0d5-f671406337bf';

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          // INFO: the authorization prompt belongs to [requestPermission], not to startup.
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          // INFO: some Linux notification servers show this as the default click action's label.
          linux: LinuxInitializationSettings(defaultActionName: 'Öffnen'),
          windows: WindowsInitializationSettings(
            appName: 'FinanzGecko',
            appUserModelId: 'de.finanzgecko.app',
            guid: _windowsGuid,
          ),
        ),
      );
      _initialized = true;
    } catch (_) {
      // No notification backend available — Benachrichtigungen stay off.
    }
  }

  /// Asks macOS for authorization; Linux and Windows have no such concept and always report true.
  // INFO: macOS asks only on the very first call — after a denial the user must use the Systemeinstellungen.
  Future<bool> requestPermission() async {
    await init();
    if (!Platform.isMacOS) return true;
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [id] keeps the two reminder kinds apart (`kBackupNotificationId`/`kAssetNotificationId`).
  // WARNING: reusing one id makes the Vermögenswerte reminder replace the backup one in the same cycle.
  Future<void> show({required int id, required String title, required String body}) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          // INFO: macOS suppresses a foreground notification unless presentBanner/presentList are set.
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
            presentBadge: false,
          ),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (_) {
      // See init(): best-effort, never fatal.
    }
  }
}
