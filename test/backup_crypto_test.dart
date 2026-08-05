// Gherkin: gherkin/backup_restore.feature
//
// Passwortgeschützte Backups. Der wichtigste Test ist nicht "Verschlüsseln
// funktioniert", sondern dass die Verschlüsselung **optional** bleibt: alte
// Klartext-Backups müssen unverändert erkannt und eingelesen werden, sonst
// wäre das ein Breaking Change für jedes bereits exportierte Backup.
import 'dart:convert';

import 'package:finanzgecko/data/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _backup() => {
  'schemaVersion': 1,
  'exportedAt': '2026-08-05T10:00:00.000',
  'baseCurrency': 'EUR',
  'accounts': [
    {'id': 1, 'name': 'Girokonto', 'bank': 'DKB', 'tag': 'Girokonto', 'currency': 'EUR', 'archived': false},
  ],
  'balances': <dynamic>[],
  'assets': <dynamic>[],
  'subscriptions': <dynamic>[],
};

void main() {
  group('Format-Erkennung', () {
    test('Klartext-Backup wird NICHT als verschlüsselt erkannt', () {
      expect(isEncryptedBackup(_backup()), isFalse);
    });

    test('verschlüsseltes Backup wird erkannt, ohne es zu entschlüsseln', () async {
      final raw = await encryptBackup(_backup(), 'hunter2');
      expect(isEncryptedBackup(jsonDecode(raw)), isTrue);
    });

    test('beliebiges JSON ist kein verschlüsseltes Backup', () {
      expect(isEncryptedBackup({'irgendwas': 1}), isFalse);
      expect(isEncryptedBackup('text'), isFalse);
      expect(isEncryptedBackup(null), isFalse);
    });
  });

  group('Verschlüsseln und wieder lesen', () {
    test('Runde durch Verschlüsseln und Entschlüsseln liefert dieselben Daten', () async {
      final original = _backup();
      final raw = await encryptBackup(original, 'ein langes Passwort');
      final restored = await decryptBackup(jsonDecode(raw) as Map, 'ein langes Passwort');
      expect(restored, original);
    });

    test('die Datei enthält keine Klartextdaten', () async {
      final raw = await encryptBackup(_backup(), 'hunter2');
      expect(raw, isNot(contains('Girokonto')));
      expect(raw, isNot(contains('DKB')));
      expect(raw, isNot(contains('hunter2')), reason: 'Das Passwort darf nirgends in der Datei stehen');
    });

    test('zweimal dasselbe Backup ergibt unterschiedliche Dateien (eigenes Salt und Nonce)', () async {
      final a = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map;
      final b = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map;
      expect(a['kdf']['salt'], isNot(b['kdf']['salt']));
      expect(a['nonce'], isNot(b['nonce']));
      expect(a['cipherText'], isNot(b['cipherText']));
    });

    test('Ableitungsparameter stehen in der Datei, nicht nur im Code', () async {
      final decoded = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map;
      expect(decoded['kdf']['algo'], 'pbkdf2-hmac-sha256');
      expect(decoded['kdf']['iterations'], isA<int>());
      expect(decoded['kdf']['iterations'], greaterThanOrEqualTo(100000));
    });
  });

  group('Fehlerfälle', () {
    test('falsches Passwort wirft WrongBackupPassphraseException', () async {
      final raw = await encryptBackup(_backup(), 'richtig');
      await expectLater(
        decryptBackup(jsonDecode(raw) as Map, 'falsch'),
        throwsA(isA<WrongBackupPassphraseException>()),
      );
    });

    test('nachträglich veränderte Datei wird abgelehnt', () async {
      final decoded = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map<String, dynamic>;
      final tampered = base64Decode(decoded['cipherText'] as String);
      tampered[0] = tampered[0] ^ 0xff;
      decoded['cipherText'] = base64Encode(tampered);
      await expectLater(
        decryptBackup(decoded, 'hunter2'),
        throwsA(isA<WrongBackupPassphraseException>()),
        reason: 'Der MAC schlägt an — für Nutzer nicht von einem falschen Passwort unterscheidbar',
      );
    });

    test('unvollständige Datei wirft UnsupportedBackupFormatException', () async {
      final decoded = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map<String, dynamic>;
      decoded.remove('nonce');
      await expectLater(decryptBackup(decoded, 'hunter2'), throwsA(isA<UnsupportedBackupFormatException>()));
    });

    test('neuere Formatversion wird erkannt statt falsch gelesen', () async {
      final decoded = jsonDecode(await encryptBackup(_backup(), 'hunter2')) as Map<String, dynamic>;
      decoded['v'] = 99;
      await expectLater(decryptBackup(decoded, 'hunter2'), throwsA(isA<UnsupportedBackupFormatException>()));
    });

    test('encryptBackup ohne Passwort ist ein Programmierfehler, kein stiller Klartext', () async {
      await expectLater(encryptBackup(_backup(), ''), throwsA(isA<ArgumentError>()));
    });
  });
}
