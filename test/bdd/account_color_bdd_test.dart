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
  });
}
