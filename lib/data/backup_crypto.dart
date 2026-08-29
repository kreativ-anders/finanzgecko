/// Password-protected backup files.
///
/// INFO: own format, password-derived key, and optional encryption — see dev/ai/persistence.md.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'apple_pbkdf2.dart';
import 'crypto_platform.dart';

/// Plaintext marker letting the import recognise an encrypted backup without decrypting it.
const String _magic = 'finanzgecko-backup';
const int _formatVersion = 1;

/// INFO: stored in the file so it can be raised later; kept at 200,000 until Windows and Linux can follow too.
const int _defaultIterations = 200000;

/// Wrong password, or a file altered afterwards — a failed MAC cannot tell the two apart.
class WrongBackupPassphraseException implements Exception {
  const WrongBackupPassphraseException();

  @override
  String toString() => 'WrongBackupPassphraseException';
}

/// File looks like an encrypted backup but is incomplete or comes from a newer version.
class UnsupportedBackupFormatException implements Exception {
  const UnsupportedBackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'UnsupportedBackupFormatException($reason)';
}

/// True if [decoded] (the result of `jsonDecode`) is a password-protected backup.
bool isEncryptedBackup(dynamic decoded) => decoded is Map && decoded['format'] == _magic;

/// Encrypts [data] with [passphrase]; returns the complete file content as JSON text.
Future<String> encryptBackup(Map<String, dynamic> data, String passphrase) async {
  if (passphrase.isEmpty) {
    throw ArgumentError('encryptBackup ohne Passwort aufgerufen — der Aufrufer entscheidet über Klartext.');
  }
  final salt = _randomBytes(16);
  final key = await _deriveKey(passphrase, salt, _defaultIterations);
  final box = await buildAesGcm256().encrypt(utf8.encode(jsonEncode(data)), secretKey: key);

  return const JsonEncoder.withIndent('  ').convert({
    'format': _magic,
    'v': _formatVersion,
    'kdf': {'algo': 'pbkdf2-hmac-sha256', 'salt': base64Encode(salt), 'iterations': _defaultIterations},
    'nonce': base64Encode(box.nonce),
    'cipherText': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

/// Counterpart to [encryptBackup]; throws on a wrong password or a broken or too-new structure.
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
    clear = await buildAesGcm256().decrypt(box, secretKey: key);
  } catch (_) {
    // WARNING: keep this catch broad — the OS-backed cipher may report a failed MAC as some other error type.
    // INFO: the cost is that a broken platform path also reads as "wrong password"; dev/app-store.md smoke-tests it.
    throw const WrongBackupPassphraseException();
  }

  final parsed = jsonDecode(utf8.decode(clear));
  if (parsed is! Map<String, dynamic>) {
    throw const UnsupportedBackupFormatException('Inhalt ist kein Objekt');
  }
  return parsed;
}

/// INFO: both branches derive the same key from the same inputs, so which one runs never changes the file.
Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int iterations) async {
  if (ApplePbkdf2.isAvailable) {
    return SecretKey(
      ApplePbkdf2.deriveKey(password: utf8.encode(passphrase), salt: salt, iterations: iterations, bits: 256),
    );
  }
  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
  return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
}

Uint8List _randomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
}
