// Gherkin: gherkin/executable/backup_file_limits.feature
// Source: lib/data/backup_crypto.dart (isAcceptableNewBackupPassphrase, encryptBackup, decryptBackup)
import 'dart:convert';

import 'package:finanzgecko/data/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gherkin_runner.dart';

const Map<String, dynamic> _content = {'schemaVersion': 1, 'baseCurrency': 'CHF'};

Map<String, dynamic> _file(World w) => w.data['file']! as Map<String, dynamic>;

void main() {
  runFeature('gherkin/executable/backup_file_limits.feature', (s) {
    s.step(r'I check the new backup password "(.*)"', (w, a) {
      w.data['accepted'] = isAcceptableNewBackupPassphrase(a[0]);
    });

    s.step(r'the password is accepted', (w, a) => expect(w.data['accepted'], isTrue));
    s.step(r'the password is rejected', (w, a) => expect(w.data['accepted'], isFalse));

    s.step(r'a backup protected with password "(.*)"', (w, a) async {
      w.data['file'] = jsonDecode(await encryptBackup(_content, a[0])) as Map<String, dynamic>;
    });

    s.step(r'its iteration count is changed to (-?\d+)', (w, a) {
      (_file(w)['kdf'] as Map)['iterations'] = int.parse(a[0]);
    });

    s.step(r'its salt is emptied', (w, a) {
      (_file(w)['kdf'] as Map)['salt'] = '';
    });

    s.step(r'I decrypt it with password "(.*)"', (w, a) async {
      try {
        w.data['restored'] = await decryptBackup(_file(w), a[0]);
      } on Exception catch (e) {
        w.data['error'] = e;
      }
    });

    s.step(r'the backup content is restored', (w, a) {
      expect(w.data['error'], isNull);
      expect(w.data['restored'], _content);
    });

    s.step(r'it is rejected as an unsupported backup format', (w, a) {
      expect(w.data['error'], isA<UnsupportedBackupFormatException>());
    });
  });
}
