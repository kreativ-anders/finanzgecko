// Gherkin: gherkin/settings.feature
import 'package:finanzgecko/utils/file_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the two macOS sandbox rules the "Im Ordner zeigen" bug came down to:
/// a downloaded file is revealed as a FILE, and the data directory is opened
/// unshortened (the old code took `.parent` on macOS and landed in $HOME).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(macFinderChannelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var nativeResult = true;

  setUp(() {
    calls.clear();
    nativeResult = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return nativeResult;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('revealFileInFileManager auf macOS', () {
    const downloaded = '/Users/beispiel/Downloads/FinanzGecko-1.10.0-mac.dmg';

    test('zeigt die Datei selbst — nicht ihren Ordner, für den es kein Sandbox-Recht gibt', () async {
      expect(await revealFileInFileManager(downloaded, 'macos'), isTrue);

      expect(calls.single.method, 'revealFile');
      expect(calls.single.arguments, {'path': downloaded});
    });

    test('meldet false, wenn die native Seite ablehnt', () async {
      nativeResult = false;

      expect(await revealFileInFileManager(downloaded, 'macos'), isFalse);
    });

    test('meldet false statt zu werfen, wenn der Kanal fehlt', () async {
      messenger.setMockMethodCallHandler(channel, null);

      expect(await revealFileInFileManager(downloaded, 'macos'), isFalse);
    });
  });

  group('openFolderInFileManager auf macOS', () {
    test('öffnet das Datenverzeichnis unverkürzt', () async {
      const dataDir = '/Users/beispiel/Library/Application Support/FinanzGecko';

      expect(await openFolderInFileManager(dataDir, 'macos'), isTrue);

      expect(calls.single.method, 'openFolder');
      expect(calls.single.arguments, {'path': dataDir});
    });
  });

  test('andere Systeme benutzen den Kanal nicht', () async {
    // Der url_launcher-Pfad selbst ist UI-/Integrationsgebiet und darf hier scheitern — geprüft wird
    // nur, dass Linux nicht versehentlich über den macOS-Kanal geleitet wird.
    try {
      await openFolderInFileManager('/home/beispiel/.local/share', 'linux');
    } catch (_) {
      // erwartet: ohne Plugin-Registrierung gibt es im Test keinen Dateimanager
    }

    expect(calls, isEmpty);
  });
}
