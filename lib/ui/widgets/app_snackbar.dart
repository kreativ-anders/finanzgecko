import 'package:flutter/material.dart';

import '../app_view.dart';
import '../theme.dart';

/// Standard confirmation snackbar shown after any successful user change
/// (save, add, delete, settings update, …) so feedback is consistent across
/// the whole app.
void showSavedSnackBar(BuildContext context, ValueChanged<AppView> onNavigate, {String message = 'Gespeichert.'}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      // SnackBar defaults `persist` to true whenever an `action` is set, which
      // disables the auto-dismiss timer entirely (it just sits there until
      // replaced or dismissed) — force it off so the confirmation still
      // times out on its own.
      persist: false,
      action: SnackBarAction(label: 'Zum Dashboard', onPressed: () => onNavigate(AppView.dashboard)),
    ),
  );
}

/// Standard error/validation snackbar, styled in the danger color so it reads
/// as distinct from the (neutral) success snackbar above. Always hides
/// whatever snackbar is currently showing first — without that, a validation
/// error retriggered on every keystroke (e.g. while a field is transiently
/// invalid) queues up behind itself and the bar never seems to go away.
void showErrorSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      backgroundColor: kDanger,
    ),
  );
}
