/// Which cryptographic implementation the app actually runs on.
///
/// Everything here exists for one reason: the Mac App Store build declares
/// `ITSAppUsesNonExemptEncryption = false` on the grounds that all encryption
/// it performs is the operating system's own. `cryptography_flutter` is what
/// makes that true for AES-GCM — but it is built to fall back to the bundled
/// Dart implementation silently, and a silent fallback here turns a filed
/// declaration into a false one. See AI_MASTER §4.1 "Export compliance".
library;

import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

import 'apple_pbkdf2.dart';

/// Where `cryptography_flutter` delegates AES-GCM to an OS API rather than to
/// a Dart implementation running in a background isolate. Written out as an
/// explicit platform list instead of asking the package: the list is what the
/// export-compliance claim is about, so it should be readable here.
bool get _osProvidesAesGcm => Platform.isMacOS || Platform.isIOS || Platform.isAndroid;

/// Hands every AES-GCM call to the platform, whatever its size.
///
/// `FlutterAesGcm` defaults to a size threshold, below which it encrypts in
/// Dart because a platform-channel round trip costs more than the work itself.
/// That trade is right for performance and wrong here: a new user's database is
/// small, and would then be encrypted by the bundled implementation — the one
/// case the declaration says does not occur.
final CryptographyChannelPolicy _alwaysPlatform = CryptographyChannelPolicy(minLength: 0, maxLength: null);

/// The AES-256-GCM cipher for the data file and for backups.
///
/// Falls back to the package default where no platform implementation exists
/// (Windows, Linux) or no plugin is registered (`flutter test`, which has no
/// plugin registrant). Both cases produce the same ciphertext format — AES-GCM
/// is AES-GCM — so a file written by one is readable by the other.
AesGcm buildAesGcm256() {
  if (!_osProvidesAesGcm || !FlutterCryptography.isPluginPresent) {
    return AesGcm.with256bits();
  }
  return FlutterAesGcm.with256bits(channelPolicy: _alwaysPlatform);
}

/// One line for the OS log, naming the implementations actually in use.
///
/// The only way to tell a working native path from a silent fallback on a
/// signed, sandboxed build — `flutter test` cannot answer this, because the
/// plugin registrant does not run there. Carries no secret and no path, unlike
/// the messages in `main()` that are debug-gated for that reason.
String describeCryptoPlatform() {
  final aes = (_osProvidesAesGcm && FlutterCryptography.isPluginPresent) ? 'OS (cryptography_flutter)' : 'Dart';
  final pbkdf2 = ApplePbkdf2.isAvailable ? 'OS (CommonCrypto)' : 'Dart';
  return 'FinanzGecko crypto: AES-256-GCM = $aes, PBKDF2-HMAC-SHA256 = $pbkdf2';
}
