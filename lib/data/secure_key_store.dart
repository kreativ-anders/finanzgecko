import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

const String _keyName = 'finanzgecko_dek';

/// Holds the AES-256 data-encryption key in the OS-native credential store
/// (Windows Credential Locker/DPAPI, macOS Keychain, Linux
/// libsecret/kwallet) rather than anywhere in the app's own files, so the
/// on-disk store is only readable on this machine, by this OS user.
class SecureKeyStore {
  const SecureKeyStore();

  // NOT a free choice: the two macOS keychains store the item in different
  // places, so a build that switches sides can no longer read a key the other
  // one wrote. Flipping this for the DMG build would make every existing
  // user's data file undecryptable. Which build gets which, and why:
  // AI_MASTER §4.1 "macOS-Spezifika".
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore),
  );

  /// One CSPRNG for all 32 bytes. `Random.secure()` inside the generator
  /// callback constructed a fresh instance per byte — same security, 32x the
  /// setup.
  static final Random _secureRandom = Random.secure();

  /// Unlike the store's other OS calls (chmod, icacls, ...), a failure here
  /// is deliberately NOT swallowed: without a key the app cannot read or
  /// write its data at all, so the error is left to propagate up to the
  /// startup guard in `main()`, which shows it instead of silently
  /// continuing in a broken state.
  Future<SecretKey> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return SecretKey(base64Decode(existing));
    }

    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => _secureRandom.nextInt(256)));
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }
}
