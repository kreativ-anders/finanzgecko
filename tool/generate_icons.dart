// Einziger Einstiegspunkt für die komplette Icon-Pipeline: ruft
// flutter_launcher_icons für macOS auf, skaliert den Master zusätzlich auf
// die Linux-Hicolor-Größen (das Package kennt kein Linux-Target) und baut das
// Windows-.ico selbst (siehe [generateWindowsIcon] unten). Aufruf:
// dart run tool/generate_icons.dart
//
// Die Linux-Skalierung ([generateLinuxIcons]) und die Windows-ICO-Generierung
// ([generateWindowsIcon]) sind reine Funktionen und werden zusätzlich von
// `flutter test` ausgeführt (test/tooling_test.dart), damit beide aus dem
// Master reproduzierbar mitgeneriert werden. Nur der macOS-Schritt bleibt ein
// Subprozess und damit außerhalb der Tests.

// Dev-CLI-Skript (kein App-Code): Fortschritt landet bewusst per print auf
// der Konsole, ein Logging-Framework wäre hier unangemessen.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

const masterPath = 'assets/icon/icon.png';
const linuxTargets = {'icons/icon-512.png': 512, 'icons/icon-192.png': 192};
const windowsIconPath = 'windows/runner/resources/app_icon.ico';
const windowsIconSizes = [16, 32, 48, 64, 128, 256];

Future<void> main() async {
  await _runFlutterLauncherIcons();
  print('==> Linux (Hicolor-Icons aus $masterPath)');
  for (final p in generateLinuxIcons()) {
    print('Geschrieben: $p');
  }
  print('==> Windows (Multi-Size-ICO aus $masterPath)');
  print('Geschrieben: ${generateWindowsIcon()}');
}

Future<void> _runFlutterLauncherIcons() async {
  print('==> macOS (flutter_launcher_icons)');
  final process = await Process.start('dart', ['run', 'flutter_launcher_icons'], mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) {
    stderr.writeln('flutter_launcher_icons ist mit Code $code fehlgeschlagen.');
    exit(code);
  }
}

/// Scales the master PNG to the Linux hicolor sizes and writes them. Pure
/// (reads [master], writes the [targets] paths); returns the written paths.
/// Throws if the master can't be decoded — no `exit()` so it's test-safe.
List<String> generateLinuxIcons({String master = masterPath, Map<String, int> targets = linuxTargets}) {
  final decoded = img.decodePng(File(master).readAsBytesSync());
  if (decoded == null) throw StateError('Konnte $master nicht dekodieren.');
  final written = <String>[];
  for (final entry in targets.entries) {
    final resized = img.copyResize(
      decoded,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    written.add(entry.key);
  }
  return written;
}

/// Builds a proper multi-resolution .ico ([sizes], 16..256px) from the master
/// and writes it to [out]; returns the written path. Pure like
/// [generateLinuxIcons]. `flutter_launcher_icons`' own Windows generator only
/// ever writes a single 256px frame (`WindowsIconGenerator._generateIcon`),
/// which Explorer/taskbar/Start-Menü for a shortcut/exe render blank instead
/// of downscaling — hence generating this ourselves instead of relying on
/// its Windows target (disabled in pubspec.yaml).
String generateWindowsIcon({String master = masterPath, String out = windowsIconPath, List<int> sizes = windowsIconSizes}) {
  final decoded = img.decodePng(File(master).readAsBytesSync());
  if (decoded == null) throw StateError('Konnte $master nicht dekodieren.');
  final frames = [
    for (final size in sizes) img.copyResize(decoded, width: size, height: size, interpolation: img.Interpolation.average),
  ];
  File(out).writeAsBytesSync(img.IcoEncoder().encodeImages(frames));
  return out;
}
