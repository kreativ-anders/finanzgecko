// Gherkin: gherkin/executable/update_assets.feature
// Source: lib/utils/update_assets.dart (selectAssetName, parseChecksums, digestMatches)
import 'package:finanzgecko/utils/update_assets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

void main() {
  runFeature('gherkin/executable/update_assets.feature', (s) {
    s.step(r'I pick the asset for "(.*)" from "(.*)"', (w, a) {
      final names = a[1].split(',').map((n) => n.trim()).where((n) => n.isNotEmpty);
      w.data['asset'] = selectAssetName(names, a[0]);
    });

    s.step(r'the chosen asset is "(.*)"', (w, a) {
      expect(w.data['asset'], a[0]);
    });

    s.step(r'no asset is picked', (w, a) {
      expect(w.data['asset'], isNull);
    });

    // A step always sits on ONE line, so real line breaks can't appear
    // in the feature file — "\n" gets translated back here.
    s.step(r'I parse the checksums "(.*)"', (w, a) {
      w.data['sums'] = parseChecksums(a[0].replaceAll(r'\n', '\n'));
    });

    s.step(r'the hash for "(.*)" equals "(.*)"', (w, a) {
      expect((w.data['sums'] as Map<String, String>)[a[0]], a[1]);
    });

    s.step(r'the result contains exactly (\d+) entry', (w, a) {
      expect((w.data['sums'] as Map<String, String>).length, int.parse(a[0]));
    });

    s.step(r'there is no hash for "(.*)"', (w, a) {
      expect((w.data['sums'] as Map<String, String>)[a[0]], isNull);
    });

    s.step(r'I hex-encode the bytes "(.*)"', (w, a) {
      w.data['hex'] = hexEncode([for (final b in a[0].split(',')) int.parse(b.trim())]);
    });

    s.step(r'the hex representation is "(.*)"', (w, a) {
      expect(w.data['hex'], a[0]);
    });

    s.step(r'I compare digest "(.*)" with "(.*)"', (w, a) {
      w.data['match'] = digestMatches(a[0], a[1]);
    });

    s.step(r'the digests match', (w, a) {
      expect(w.data['match'], isTrue);
    });

    s.step(r'the digests do not match', (w, a) {
      expect(w.data['match'], isFalse);
    });
  });
}
