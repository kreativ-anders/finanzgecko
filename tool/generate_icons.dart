// Einziger Einstiegspunkt für die komplette Icon-Pipeline: ruft
// flutter_launcher_icons für macOS/Windows auf und skaliert den Master
// zusätzlich auf die Linux-Hicolor-Größen (das Package kennt kein
// Linux-Target). Aufruf: dart run tool/generate_icons.dart

// Dev-CLI-Skript (kein App-Code): Fortschritt landet bewusst per print auf
// der Konsole, ein Logging-Framework wäre hier unangemessen.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

const masterPath = 'assets/icon/icon.png';
const linuxTargets = {'icons/icon-512.png': 512, 'icons/icon-192.png': 192};

Future<void> main() async {
  await _runFlutterLauncherIcons();
  _generateLinuxIcons();
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

void _generateLinuxIcons() {
  print('==> Linux (Hicolor-Icons aus $masterPath)');
  final master = img.decodePng(File(masterPath).readAsBytesSync());
  if (master == null) {
    stderr.writeln('Konnte $masterPath nicht dekodieren.');
    exit(1);
  }

  for (final entry in linuxTargets.entries) {
    final resized = img.copyResize(
      master,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    print('Geschrieben: ${entry.key} (${entry.value}x${entry.value})');
  }
}
