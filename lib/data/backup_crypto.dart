/// Passwortgeschützte Backup-Dateien.
///
/// Bewusst ein **eigenes** Format, getrennt vom Envelope der Datendatei
/// (`app_store.dart`): jener wird mit dem gerätegebundenen Schlüssel aus dem
/// Betriebssystem verschlüsselt und ist deshalb nur auf genau einem Rechner
/// lesbar. Ein Backup soll das Gegenteil sein — überall einlesbar. Der
/// Schlüssel wird daher aus einem Passwort abgeleitet, das die Person kennt.
///
/// Die Verschlüsselung ist **optional**: ohne Passwort schreibt der Export
/// weiterhin exakt das bisherige Klartext-JSON, und der Import erkennt beide
/// Formen an ihrer Struktur. Bestehende Backups bleiben damit gültig.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Marker im Klartext, an dem der Import ein verschlüsseltes Backup erkennt,
/// ohne es entschlüsseln zu müssen.
const String _magic = 'finanzgecko-backup';
const int _formatVersion = 1;

/// PBKDF2-HMAC-SHA256. Die Zahl steht **in der Datei**, nicht nur hier — so
/// lässt sie sich später anheben, ohne ältere Backups unlesbar zu machen.
/// 200.000 ist ein Kompromiss: die reine Dart-Implementierung läuft im
/// UI-Isolate, und ein Export darf nicht gefühlt hängen bleiben.
const int _defaultIterations = 200000;

/// Falsches Passwort (oder nachträglich veränderte Datei — beides ist am
/// fehlgeschlagenen MAC nicht unterscheidbar).
class WrongBackupPassphraseException implements Exception {
  const WrongBackupPassphraseException();

  @override
  String toString() => 'WrongBackupPassphraseException';
}

/// Datei sieht aus wie ein verschlüsseltes Backup, ist aber unvollständig oder
/// stammt aus einer neueren Version.
class UnsupportedBackupFormatException implements Exception {
  const UnsupportedBackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'UnsupportedBackupFormatException($reason)';
}

/// True, wenn [decoded] (das Ergebnis von `jsonDecode`) ein passwortgeschütztes
/// Backup ist. Ein Klartext-Backup hat diesen Marker nicht und läuft dadurch
/// unverändert über den bisherigen Importpfad.
bool isEncryptedBackup(dynamic decoded) => decoded is Map && decoded['format'] == _magic;

/// Verschlüsselt [data] mit [passphrase]. Ergebnis ist der komplette
/// Dateiinhalt (JSON-Text).
Future<String> encryptBackup(Map<String, dynamic> data, String passphrase) async {
  if (passphrase.isEmpty) {
    throw ArgumentError('encryptBackup ohne Passwort aufgerufen — der Aufrufer entscheidet über Klartext.');
  }
  final salt = _randomBytes(16);
  final key = await _deriveKey(passphrase, salt, _defaultIterations);
  final box = await AesGcm.with256bits().encrypt(utf8.encode(jsonEncode(data)), secretKey: key);

  return const JsonEncoder.withIndent('  ').convert({
    'format': _magic,
    'v': _formatVersion,
    // Parameter mitschreiben, damit ein späteres Anheben alte Dateien nicht
    // bricht — beim Entschlüsseln wird gelesen, was hier steht.
    'kdf': {'algo': 'pbkdf2-hmac-sha256', 'salt': base64Encode(salt), 'iterations': _defaultIterations},
    'nonce': base64Encode(box.nonce),
    'cipherText': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

/// Gegenstück zu [encryptBackup]. Wirft [WrongBackupPassphraseException] bei
/// falschem Passwort und [UnsupportedBackupFormatException] bei kaputter oder
/// zu neuer Struktur.
Future<Map<String, dynamic>> decryptBackup(Map decoded, String passphrase) async {
  if (!isEncryptedBackup(decoded)) {
    throw const UnsupportedBackupFormatException('kein verschlüsseltes Backup');
  }
  final version = decoded['v'];
  if (version is! int || version > _formatVersion) {
    throw const UnsupportedBackupFormatException('neuere Backup-Version — bitte FinanzGecko aktualisieren');
  }
  final kdf = decoded['kdf'];
  if (kdf is! Map || kdf['algo'] != 'pbkdf2-hmac-sha256' || kdf['salt'] is! String || kdf['iterations'] is! int) {
    throw const UnsupportedBackupFormatException('unvollständige Schlüsselableitungs-Angaben');
  }
  if (decoded['nonce'] is! String || decoded['cipherText'] is! String || decoded['mac'] is! String) {
    throw const UnsupportedBackupFormatException('unvollständige Datei');
  }

  final key = await _deriveKey(passphrase, base64Decode(kdf['salt'] as String), kdf['iterations'] as int);
  final box = SecretBox(
    base64Decode(decoded['cipherText'] as String),
    nonce: base64Decode(decoded['nonce'] as String),
    mac: Mac(base64Decode(decoded['mac'] as String)),
  );

  final List<int> clear;
  try {
    clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
  } catch (_) {
    // AES-GCM prüft den MAC — ein falsches Passwort scheitert genau hier.
    throw const WrongBackupPassphraseException();
  }

  final parsed = jsonDecode(utf8.decode(clear));
  if (parsed is! Map<String, dynamic>) {
    throw const UnsupportedBackupFormatException('Inhalt ist kein Objekt');
  }
  return parsed;
}

Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int iterations) async {
  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
  return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
}

Uint8List _randomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
}
