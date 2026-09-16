import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Writes an export the user chose a location for, so a crash never leaves a half-written file in its place.
// INFO: Linux also narrows it to the owner before any content lands — see dev/ai/persistence.md "Exports".
Future<void> writeExportFile(String path, String content, String operatingSystem) async {
  // WARNING: the macOS sandbox grants exactly the chosen file — a sibling temp file there is denied.
  if (operatingSystem == 'macos') {
    await File(path).writeAsString(content, flush: true);
    return;
  }
  final tmp = File('$path.tmp');
  try {
    await tmp.writeAsString('', flush: true);
    if (operatingSystem == 'linux') {
      // INFO: absolute for the same reason as in `AppStore`: `PATH` is attacker-influenced.
      await Process.run('/bin/chmod', ['600', tmp.path]);
    }
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(path);
  } finally {
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

/// Native counterpart in `macos/Runner/MainFlutterWindow.swift`.
const String macFinderChannelName = 'de.finanzgecko.app/finder';

const MethodChannel _macFinder = MethodChannel(macFinderChannelName);

/// Shows [filePath] selected in the OS file manager; false if it couldn't be shown.
// WARNING: never "simplify" this into opening the parent folder on macOS. Under the App Sandbox the app
// holds an extension for the file the user picked in the save dialog, not for the folder around it — the
// folder route fails with a macOS permission alert the user cannot answer. See dev/ai/platform.md.
Future<bool> revealFileInFileManager(String filePath, String operatingSystem) {
  if (operatingSystem == 'macos') return _invokeMacFinder('revealFile', filePath);
  // Windows and Linux have no sandbox in the way, and no portable "select this file" call either.
  return openFolderInFileManager(File(filePath).parent.path, operatingSystem);
}

/// Opens [directoryPath] itself in the OS file manager; false if it couldn't be opened.
// INFO: on macOS only sound for paths inside the app container (the data directory). A user-chosen folder
// belongs in [revealFileInFileManager] instead.
Future<bool> openFolderInFileManager(String directoryPath, String operatingSystem) {
  if (operatingSystem == 'macos') return _invokeMacFinder('openFolder', directoryPath);
  return launchUrl(Uri.directory(directoryPath, windows: operatingSystem == 'windows'));
}

/// Any channel failure collapses to false — the caller shows one "couldn't open" note either way.
Future<bool> _invokeMacFinder(String method, String path) async {
  try {
    return await _macFinder.invokeMethod<bool>(method, {'path': path}) ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
