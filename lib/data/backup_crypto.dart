/// Password-protected backup files.
///
/// Deliberately its **own** format, separate from the data file's envelope
/// (`app_store.dart`): that one is encrypted with the device-bound key from
/// the OS and is therefore readable on exactly one machine. A backup should be
/// the opposite — readable anywhere, so its key is derived from a password the
/// person knows.
///
/// Encryption is **optional**: without a password the export still writes
/// exactly the previous plaintext JSON, and the import recognises both shapes
/// by their structure, so existing backups stay valid.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'apple_pbkdf2.dart';
import 'crypto_platform.dart';

/// Plaintext marker by which the import recognises an encrypted backup without
/// having to decrypt it.
const String _magic = 'finanzgecko-backup';
const int _formatVersion = 1;

/// PBKDF2-HMAC-SHA256. The number is stored **in the file**, not only here —
/// so it can be raised later without making older backups unreadable. 200,000
/// was a compromise against the pure-Dart implementation, which runs on the UI
/// isolate and must not make an export feel like it hangs. On Apple platforms
/// that constraint is gone (see [ApplePbkdf2]); the number stays where it is
/// until Windows and Linux can follow, so that one file format does not depend
/// on which machine wrote it.
const int _defaultIterations = 200000;

/// Wrong password (or a file altered afterwards — the failed MAC cannot tell
/// the two apart).
class WrongBackupPassphraseException implements Exception {
  const WrongBackupPassphraseException();

  @override
  String toString() => 'WrongBackupPassphraseException';
}

/// File looks like an encrypted backup but is incomplete or comes from a newer
/// version.
class UnsupportedBackupFormatException implements Exception {
  const UnsupportedBackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'UnsupportedBackupFormatException($reason)';
}

/// True if [decoded] (the result of `jsonDecode`) is a password-protected
/// backup. A plaintext backup lacks the marker and therefore still goes through
/// the previous import path unchanged.
bool isEncryptedBackup(dynamic decoded) => decoded is Map && decoded['format'] == _magic;

/// Encrypts [data] with [passphrase]; returns the complete file content
/// (JSON text).
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
    // Write the parameters along so that raising them later does not break old
    // files — decryption reads whatever is stored here.
    'kdf': {'algo': 'pbkdf2-hmac-sha256', 'salt': base64Encode(salt), 'iterations': _defaultIterations},
    'nonce': base64Encode(box.nonce),
    'cipherText': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

/// Counterpart to [encryptBackup]. Throws [WrongBackupPassphraseException] on a
/// wrong password and [UnsupportedBackupFormatException] on a broken or
/// too-new structure.
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
    // AES-GCM verifies the MAC — a wrong password fails exactly here.
    //
    // The catch stays deliberately broad. Narrowing it to the Dart
    // implementation's `SecretBoxAuthenticationError` would be more precise on
    // paper, but the OS-backed implementation may report a failed MAC as some
    // other error, and someone with a genuinely wrong password would then get
    // an internal message instead of the one that names the cause. What this
    // costs is that a broken platform path also reads as "wrong password" —
    // which is why the smoke test in dev/app-store.md checks that case
    // explicitly on a real macOS build.
    throw const WrongBackupPassphraseException();
  }

  final parsed = jsonDecode(utf8.decode(clear));
  if (parsed is! Map<String, dynamic>) {
    throw const UnsupportedBackupFormatException('Inhalt ist kein Objekt');
  }
  return parsed;
}

/// PBKDF2 is fully specified by RFC 2898, so both branches derive the same key
/// from the same password, salt and iteration count. Which one runs therefore
/// changes nothing about the file — only who computes it.
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
