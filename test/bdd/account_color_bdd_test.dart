// Gherkin: gherkin/executable/account_color.feature
// Quelle: lib/constants.dart (resolveAccountColor, bankColorHex, tagColorHex)
import 'package:finanzgecko/constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

void main() {
  runFeature('gherkin/executable/account_color.feature', (s) {
    s.step(r'ich die Farbe für Bank "(.*)" und Kontotyp "(.*)" auflöse', (w, a) {
      try {
        w.data['color'] = resolveAccountColor(bank: a[0], tag: a[1]);
        w.data['error'] = null;
      } on FormatException catch (e) {
        w.data['color'] = null;
        w.data['error'] = e;
      }
    });

    s.step(r'ist die Farbe die Markenfarbe der Bank "(.*)"', (w, a) {
      expect(w.data['error'], isNull);
      expect(w.data['color'], bankColorHex(a[0]));
    });

    s.step(r'ist die Farbe die Kontotyp-Farbe von "(.*)"', (w, a) {
      expect(w.data['error'], isNull);
      expect(w.data['color'], tagColorHex(a[0]));
    });

    s.step(r'wird ein Fehler ausgelöst', (w, a) {
      expect(w.data['error'], isA<FormatException>());
    });

    s.step(r'ich die Farbe "(.*)" für den Hintergrund "(.*)" lesbar mache', (w, a) {
      w.data['input'] = a[0];
      w.data['bg'] = a[1];
      w.data['readable'] = readableOn(a[0], a[1]);
    });

    s.step(r'ist das Ergebnis unverändert "(.*)"', (w, a) {
      expect(w.data['readable'], a[0]);
    });

    s.step(r'erreicht das Ergebnis mindestens ([\d.]+):1 gegen "(.*)"', (w, a) {
      expect(contrastRatio(w.data['readable'] as String, a[1]), greaterThanOrEqualTo(double.parse(a[0])));
    });

    s.step(r'ist das Ergebnis heller als "(.*)"', (w, a) {
      expect(relativeLuminance(w.data['readable'] as String), greaterThan(relativeLuminance(a[0])));
    });

    s.step(r'ist das Ergebnis dunkler als "(.*)"', (w, a) {
      expect(relativeLuminance(w.data['readable'] as String), lessThan(relativeLuminance(a[0])));
    });

    s.step(r'ich jede Farbe aus kBanks und kTagColors gegen beide Flächen lesbar mache', (w, a) {
      final results = <String, double>{};
      final colors = [...kBanks.map((b) => b.colorHex), ...kTagColors.values];
      for (final hex in colors) {
        for (final bg in [kSurfaceDarkHex, kSurfaceLightHex]) {
          results['$hex on $bg'] = contrastRatio(readableOn(hex, bg), bg);
        }
      }
      w.data['contrasts'] = results;
    });

    s.step(r'erreicht jedes Ergebnis mindestens ([\d.]+):1', (w, a) {
      final min = double.parse(a[0]);
      final contrasts = w.data['contrasts'] as Map<String, double>;
      // Named per combination so a regression points at the exact color.
      contrasts.forEach((label, ratio) => expect(ratio, greaterThanOrEqualTo(min), reason: label));
    });

    s.step(r'beträgt der Kontrast zwischen "(.*)" und "(.*)" ([\d.]+)', (w, a) {
      expect(contrastRatio(a[0], a[1]), closeTo(double.parse(a[2]), 0.01));
    });
  });
}
