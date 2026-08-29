/// PBKDF2-HMAC-SHA256 through Apple's CommonCrypto.
///
/// Why this file exists at all: `cryptography_flutter` covers AES-GCM with the
/// operating system's own implementation, but its `FlutterPbkdf2` is native on
/// **Android only** — on macOS and iOS it falls back to the bundled Dart
/// implementation. A bundled implementation is exactly what Apple's
/// "encryption limited to that within the Apple operating system" exemption
/// rules out, so the one algorithm the plugin cannot cover is bound here
/// directly. `CCKeyDerivationPBKDF` lives in libSystem, so this needs no
/// plugin, no CocoaPods entry and no Podfile change — which also keeps it
/// working past the CocoaPods registry going read-only. See dev/ai/persistence.md
/// "Export compliance".
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

/// `int CCKeyDerivationPBKDF(CCPBKDFAlgorithm, const char *, size_t,
/// const uint8_t *, size_t, CCPseudoRandomAlgorithm, unsigned, uint8_t *,
/// size_t)`. `char *` and `uint8_t *` are the same pointer at the ABI level;
/// declaring both as `Uint8` avoids a needless conversion of the passphrase.
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
/// Produces byte-identical output to `package:cryptography`'s `Pbkdf2` for the
/// same password, salt and iteration count — PBKDF2 is fully specified by
/// RFC 2898, so this is a change of implementation, never of format. Backups
/// written before this existed stay readable, and backups written now stay
/// readable on Windows and Linux.
class ApplePbkdf2 {
  const ApplePbkdf2._();

  /// The platforms whose libSystem exports `CCKeyDerivationPBKDF`.
  static bool get isAvailable => Platform.isMacOS || Platform.isIOS;

  static _CCKeyDerivationPBKDFDart? _cached;

  /// Deliberately **not** wrapped in a `try`/`catch` that degrades to the Dart
  /// implementation. On Apple platforms this symbol is always present, so a
  /// failed lookup means the assumption the export-compliance declaration in
  /// `macos/Runner/Info.plist` rests on is broken. That has to surface, not be
  /// papered over by a silent fallback.
  static _CCKeyDerivationPBKDFDart get _deriveKeyFn {
    return _cached ??= ffi.DynamicLibrary.process()
        .lookupFunction<_CCKeyDerivationPBKDFNative, _CCKeyDerivationPBKDFDart>('CCKeyDerivationPBKDF');
  }

  /// Derives [bits] of key material from [password] and [salt].
  ///
  /// Synchronous on purpose: 200,000 native iterations take well under a tenth
  /// of a second, far below the pure-Dart cost this replaces, so the extra
  /// failure surface of an isolate hop buys nothing here. If the iteration
  /// count is ever raised far enough to be felt, `Isolate.run` around this call
  /// is the fix.
  static Uint8List deriveKey({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int bits,
  }) {
    final passwordLen = password.length;
    final saltLen = salt.length;
    final keyLen = bits ~/ 8;

    // `calloc` rejects a zero-byte allocation, and an empty passphrase is a
    // real case: import hands one straight through so that the MAC — not an
    // argument check — is what reports the wrong password.
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
      // Overwrite before freeing: the passphrase and the derived key would
      // otherwise stay legible in released heap memory until something else
      // happens to reuse it.
      passwordPtr.asTypedList(passwordLen == 0 ? 1 : passwordLen).fillRange(0, passwordLen == 0 ? 1 : passwordLen, 0);
      keyPtr.asTypedList(keyLen).fillRange(0, keyLen, 0);
      calloc.free(passwordPtr);
      calloc.free(saltPtr);
      calloc.free(keyPtr);
    }
  }
}
