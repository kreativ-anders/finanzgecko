// Einziger Einstiegspunkt für die komplette Icon-Pipeline: ruft
// flutter_launcher_icons für macOS/Windows auf und skaliert den Master
// zusätzlich auf die Linux-Hicolor-Größen (das Package kennt kein
// Linux-Target). Aufruf: dart run tool/generate_icons.dart
//
// Die Linux-Skalierung ([generateLinuxIcons]) ist eine reine Funktion und wird
// zusätzlich von `flutter test` ausgeführt (test/tooling_test.dart), damit die
// Hicolor-Icons aus dem Master reproduzierbar mitgeneriert werden. Der
// macOS/Windows-Schritt bleibt ein Subprozess und damit außerhalb der Tests.

// Dev-CLI-Skript (kein App-Code): Fortschritt landet bewusst per print auf
// der Konsole, ein Logging-Framework wäre hier unangemessen.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

const masterPath = 'assets/icon/icon.png';
const linuxTargets = {'icons/icon-512.png': 512, 'icons/icon-192.png': 192};

Future<void> main() async {
  await _runFlutterLauncherIcons();
  print('==> Linux (Hicolor-Icons aus $masterPath)');
  for (final p in generateLinuxIcons()) {
    print('Geschrieben: $p');
  }
}

Future<void> _runFlutterLauncherIcons() async {
  print('==> macOS/Windows (flutter_launcher_icons)');
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
