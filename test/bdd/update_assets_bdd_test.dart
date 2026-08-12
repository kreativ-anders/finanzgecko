// Gherkin: gherkin/executable/update_assets.feature
// Quelle: lib/utils/update_assets.dart (selectAssetName, parseChecksums, digestMatches)
import 'package:finanzgecko/utils/update_assets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

void main() {
  runFeature('gherkin/executable/update_assets.feature', (s) {
    s.step(r'ich das Asset für "(.*)" aus "(.*)" wähle', (w, a) {
      final names = a[1].split(',').map((n) => n.trim()).where((n) => n.isNotEmpty);
      w.data['asset'] = selectAssetName(names, a[0]);
    });

    s.step(r'ist das gewählte Asset "(.*)"', (w, a) {
      expect(w.data['asset'], a[0]);
    });

    s.step(r'wird kein Asset gewählt', (w, a) {
      expect(w.data['asset'], isNull);
    });

    // Ein Schritt steht immer auf EINER Zeile, echte Zeilenumbrüche sind im
    // Feature also nicht darstellbar — "\n" wird hier zurückübersetzt.
    s.step(r'ich die Prüfsummen "(.*)" parse', (w, a) {
      w.data['sums'] = parseChecksums(a[0].replaceAll(r'\n', '\n'));
    });

    s.step(r'ist der Hash für "(.*)" gleich "(.*)"', (w, a) {
      expect((w.data['sums'] as Map<String, String>)[a[0]], a[1]);
    });

    s.step(r'enthält das Ergebnis genau (\d+) Eintrag', (w, a) {
      expect((w.data['sums'] as Map<String, String>).length, int.parse(a[0]));
    });

    s.step(r'gibt es keinen Hash für "(.*)"', (w, a) {
      expect((w.data['sums'] as Map<String, String>)[a[0]], isNull);
    });

    s.step(r'ich die Bytes "(.*)" hex-kodiere', (w, a) {
      w.data['hex'] = hexEncode([for (final b in a[0].split(',')) int.parse(b.trim())]);
    });

    s.step(r'ist die Hex-Darstellung "(.*)"', (w, a) {
      expect(w.data['hex'], a[0]);
    });

    s.step(r'ich den Digest "(.*)" mit "(.*)" vergleiche', (w, a) {
      w.data['match'] = digestMatches(a[0], a[1]);
    });

    s.step(r'stimmen die Digests überein', (w, a) {
      expect(w.data['match'], isTrue);
    });

    s.step(r'stimmen die Digests nicht überein', (w, a) {
      expect(w.data['match'], isFalse);
    });
  });
}
