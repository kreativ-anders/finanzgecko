/// Which cryptographic implementation the app actually runs on.
///
/// INFO: guards the `ITSAppUsesNonExemptEncryption = false` claim — see dev/ai/persistence.md "Export compliance".
library;

import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

import 'apple_pbkdf2.dart';

/// INFO: spelled out rather than asked of the package — this list is what the export-compliance claim covers.
bool get _osProvidesAesGcm => Platform.isMacOS || Platform.isIOS || Platform.isAndroid;

/// Hands every AES-GCM call to the platform, whatever its size.
///
/// WARNING: without this policy `FlutterAesGcm`'s size threshold silently encrypts small databases in Dart.
final CryptographyChannelPolicy _alwaysPlatform = CryptographyChannelPolicy(minLength: 0, maxLength: null);

/// The AES-256-GCM cipher for the data file and for backups.
///
/// INFO: falls back to the Dart cipher on Windows/Linux and in `flutter test`; the ciphertext format is the same.
AesGcm buildAesGcm256() {
  if (!_osProvidesAesGcm || !FlutterCryptography.isPluginPresent) {
    return AesGcm.with256bits();
  }
  return FlutterAesGcm.with256bits(channelPolicy: _alwaysPlatform);
}

/// One line for the OS log, naming the implementations actually in use.
///
/// INFO: the only way to spot a silent fallback on a signed build — `flutter test` has no plugin registrant.
/// INFO: carries no key material and no path, so unlike the messages in `main()` it is not debug-gated.
String describeCryptoPlatform() {
  final aes = (_osProvidesAesGcm && FlutterCryptography.isPluginPresent) ? 'OS (cryptography_flutter)' : 'Dart';
  final pbkdf2 = ApplePbkdf2.isAvailable ? 'OS (CommonCrypto)' : 'Dart';
  return 'FinanzGecko crypto: AES-256-GCM = $aes, PBKDF2-HMAC-SHA256 = $pbkdf2';
}
