import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../app_view.dart';
import '../theme.dart';

/// Maps a caught error to German user-facing text, in one place instead of at every catch site.
String describeError(Object err) {
  if (err is RecordNotFoundException) {
    return switch (err.entity) {
      'account' => 'Konto nicht gefunden.',
      'asset' => 'Vermögenswert nicht gefunden.',
      'subscription' => 'Fixposten nicht gefunden.',
      _ => 'Eintrag nicht gefunden.',
    };
  }
  if (err is UnsupportedBackupVersionException) {
    return 'Dieses Backup wurde mit einer neueren App-Version erstellt '
        '(Datenformat ${err.importedVersion}, unterstützt bis ${err.supportedVersion}). '
        'Bitte aktualisiere FinanzGecko und importiere erneut.';
  }
  if (err is AccountImportRejectedException) {
    return 'Import abgebrochen bei Konto "${err.accountName}": '
        'Unbekannte Bank "${err.unknownBank}" — bitte eine Bank aus der Liste verwenden.';
  }
  if (err is FormatException) {
    return 'Diese Datei ist kein gültiges FinanzGecko-Backup.';
  }
  return '$err';
}

DateTime? _lastSavedSnackBarAt;
String? _lastSavedSnackBarMessage;

// WARNING: repeated same-message calls inside 800ms are coalesced — otherwise debounced row edits flicker the bar.
/// Standard confirmation snackbar after any successful user change.
void showSavedSnackBar(BuildContext context, ValueChanged<AppView> onNavigate, {String message = 'Gespeichert.'}) {
  final now = DateTime.now();
  if (_lastSavedSnackBarMessage == message &&
      _lastSavedSnackBarAt != null &&
      now.difference(_lastSavedSnackBarAt!) < const Duration(milliseconds: 800)) {
    _lastSavedSnackBarAt = now;
    return;
  }
  _lastSavedSnackBarAt = now;
  _lastSavedSnackBarMessage = message;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
// INFO: SnackBar sets persist whenever an action is present, which disables the auto-dismiss timer.
      persist: false,
      action: SnackBarAction(label: 'Zum Dashboard', onPressed: () => onNavigate(AppView.dashboard)),
    ),
  );
}

/// Error snackbar in the danger color; hides the current bar first, or repeated errors queue up behind it.
void showErrorSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
// INFO: near-black on kDanger — white text there measures ~2.8:1, short of WCAG AA.
      content: Text(message, style: const TextStyle(color: Color(0xFF2B0000))),
      duration: const Duration(seconds: 4),
      backgroundColor: kDanger,
    ),
  );
}
