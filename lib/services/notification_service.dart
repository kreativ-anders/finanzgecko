import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around `flutter_local_notifications` (native OS
/// Benachrichtigungen for Linux/macOS/Windows). Best-effort throughout: a
/// missing notification daemon (Linux) or denied authorization (macOS) must
/// never crash the app, so errors are swallowed here instead of propagated.
///
/// macOS is the reason this class has a [requestPermission] separate from
/// [init]: `UNUserNotificationCenter` needs explicit user authorization, and
/// asking for it at startup would put a system dialog in front of an app that
/// otherwise asks for nothing. So the toggle in Einstellungen is opt-in and
/// owns the prompt. See AI_MASTER §5 "Desktop notifications" and
/// gherkin/notifications.feature.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin}) : _injectedPlugin = plugin;

  final FlutterLocalNotificationsPlugin? _injectedPlugin;

  /// Lazy on purpose: a test double that overrides every method of this class
  /// then never constructs the real plugin at all.
  late final FlutterLocalNotificationsPlugin _plugin = _injectedPlugin ?? FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Identifies FinanzGecko to the Windows toast API. Generated once and must
  /// stay stable — changing it makes Windows treat the notifications as coming
  /// from a different application.
  static const String _windowsGuid = '71b365b0-9392-4a56-a0d5-f671406337bf';

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          // All three deliberately false: the authorization prompt belongs to
          // the moment the user switches the feature on, not to startup. See
          // [requestPermission].
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          // Shown by some Linux notification servers as the label of the
          // notification's default click action. The app has nothing to
          // navigate to, so it only opens the window.
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
      // No notification backend available — Benachrichtigungen stay off, the
      // rest of the app works unchanged.
    }
  }

  /// Asks macOS for authorization and reports whether notifications may now be
  /// shown. Linux and Windows have no such concept and always report true.
  ///
  /// macOS shows its dialog only on the first call ever; every later call
  /// returns the answer already on record without asking again. That is why a
  /// user who denied once has to change it in the Systemeinstellungen — the
  /// toggle in Einstellungen cannot re-ask.
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

  /// [id] keeps the two reminder kinds apart: reusing one id would make the
  /// Vermögenswerte message replace the backup message when both fire in the
  /// same check cycle. See `kBackupNotificationId`/`kAssetNotificationId`.
  Future<void> show({required int id, required String title, required String body}) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          // Spelled out rather than left to the plugin's fallbacks: the app
          // fires these while it is running and often frontmost, and macOS
          // suppresses a foreground notification unless presentBanner/
          // presentList say otherwise. presentBadge is false because init()
          // never asks for the badge permission.
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
