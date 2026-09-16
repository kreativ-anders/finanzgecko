import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

const String _keyName = 'finanzgecko_dek';

/// Holds the AES-256 data-encryption key in the OS-native credential store, never in the app's own files.
class SecureKeyStore {
  const SecureKeyStore();

  // WARNING: flipping this switches macOS keychains and leaves every existing user's data file undecryptable.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore),
  );

  /// One CSPRNG for all 32 bytes: `Random.secure()` inside the callback built a fresh instance per byte.
  static final Random _secureRandom = Random.secure();

  // WARNING: a failure here must propagate to the startup guard in `main()`; swallowing it starts a keyless app.
  /// The stored key, or null when this installation has none yet.
  Future<SecretKey?> readKey() async {
    final existing = await _storage.read(key: _keyName);
    return existing == null ? null : SecretKey(base64Decode(existing));
  }

  /// A fresh random key that is NOT stored yet — [storeKey] is a separate, deliberate step.
  // INFO: split so a spuriously missing key never overwrites the real one, see dev/ai/persistence.md.
  SecretKey generateKey() => SecretKey(Uint8List.fromList(List<int>.generate(32, (_) => _secureRandom.nextInt(256))));

  Future<void> storeKey(SecretKey key) async {
    await _storage.write(key: _keyName, value: base64Encode(await key.extractBytes()));
  }
}
