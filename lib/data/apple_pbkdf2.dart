/// PBKDF2-HMAC-SHA256 through Apple's CommonCrypto.
///
/// INFO: bound directly because `FlutterPbkdf2` is native on Android only — see dev/ai/persistence.md.
/// INFO: libSystem means no plugin, no CocoaPods entry, no Podfile — unaffected by the CocoaPods registry freeze.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// `kCCPBKDF2` from `<CommonCrypto/CommonKeyDerivation.h>`.
const int _kCCPBKDF2 = 2;

/// `kCCPRFHmacAlgSHA256` from the same header.
const int _kCCPRFHmacAlgSHA256 = 3;

/// `kCCSuccess` from `<CommonCrypto/CommonCryptoError.h>`.
const int _kCCSuccess = 0;

/// INFO: `char *` and `uint8_t *` are the same pointer at the ABI level, so the passphrase needs no conversion.
typedef _CCKeyDerivationPBKDFNative =
    ffi.Int32 Function(
      ffi.Uint32 algorithm,
      ffi.Pointer<ffi.Uint8> password,
      ffi.Size passwordLen,
      ffi.Pointer<ffi.Uint8> salt,
      ffi.Size saltLen,
      ffi.Uint32 prf,
      ffi.Uint32 rounds,
      ffi.Pointer<ffi.Uint8> derivedKey,
      ffi.Size derivedKeyLen,
    );

typedef _CCKeyDerivationPBKDFDart =
    int Function(
      int algorithm,
      ffi.Pointer<ffi.Uint8> password,
      int passwordLen,
      ffi.Pointer<ffi.Uint8> salt,
      int saltLen,
      int prf,
      int rounds,
      ffi.Pointer<ffi.Uint8> derivedKey,
      int derivedKeyLen,
    );

/// The OS-provided key derivation used for password-protected backups.
///
/// INFO: byte-identical to `package:cryptography`'s `Pbkdf2` for the same inputs — implementation, never format.
class ApplePbkdf2 {
  const ApplePbkdf2._();

  /// The platforms whose libSystem exports `CCKeyDerivationPBKDF`.
  static bool get isAvailable => Platform.isMacOS || Platform.isIOS;

  static _CCKeyDerivationPBKDFDart? _cached;

  /// WARNING: no fallback on a failed lookup — a silent Dart path would falsify ITSAppUsesNonExemptEncryption.
  static _CCKeyDerivationPBKDFDart get _deriveKeyFn {
    return _cached ??= ffi.DynamicLibrary.process()
        .lookupFunction<_CCKeyDerivationPBKDFNative, _CCKeyDerivationPBKDFDart>('CCKeyDerivationPBKDF');
  }

  /// Derives [bits] of key material from [password] and [salt].
  ///
  /// INFO: synchronous on purpose — 200,000 native iterations stay well under 0.1 s; wrap in `Isolate.run` if raised.
  static Uint8List deriveKey({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int bits,
  }) {
    final passwordLen = password.length;
    final saltLen = salt.length;
    final keyLen = bits ~/ 8;

    // `calloc` rejects a zero-byte allocation, and an empty passphrase is a real case on import.
    final passwordPtr = calloc<ffi.Uint8>(passwordLen == 0 ? 1 : passwordLen);
    final saltPtr = calloc<ffi.Uint8>(saltLen == 0 ? 1 : saltLen);
    final keyPtr = calloc<ffi.Uint8>(keyLen);
    try {
      if (passwordLen > 0) {
        passwordPtr.asTypedList(passwordLen).setAll(0, password);
      }
      if (saltLen > 0) {
        saltPtr.asTypedList(saltLen).setAll(0, salt);
      }

      final status = _deriveKeyFn(
        _kCCPBKDF2,
        passwordPtr,
        passwordLen,
        saltPtr,
        saltLen,
        _kCCPRFHmacAlgSHA256,
        iterations,
        keyPtr,
        keyLen,
      );
      if (status != _kCCSuccess) {
        throw StateError('CCKeyDerivationPBKDF failed with status $status');
      }
      return Uint8List.fromList(keyPtr.asTypedList(keyLen));
    } finally {
      // Overwrite before freeing: released heap keeps the passphrase and the key legible otherwise.
      passwordPtr.asTypedList(passwordLen == 0 ? 1 : passwordLen).fillRange(0, passwordLen == 0 ? 1 : passwordLen, 0);
      keyPtr.asTypedList(keyLen).fillRange(0, keyLen, 0);
      calloc.free(passwordPtr);
      calloc.free(saltPtr);
      calloc.free(keyPtr);
    }
  }
}
