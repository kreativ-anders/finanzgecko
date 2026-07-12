import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _keyName = 'finanzgecko_dek';

/// Holds the AES-256 data-encryption key in the OS-native credential store
/// (Windows Credential Locker/DPAPI, macOS Keychain, Linux
/// libsecret/kwallet) rather than anywhere in the app's own files, so the
/// on-disk store is only readable on this machine, by this OS user.
class SecureKeyStore {
  const SecureKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<SecretKey> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return SecretKey(base64Decode(existing));
    }

    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }
}
