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

  // Which macOS keychain the key lives in — and this is NOT a free choice:
  // the two variants store the item in different places, so a build that
  // switches sides can no longer read a key the other one wrote. Changing
  // this for the DMG build would make every existing user's data file
  // undecryptable. See AI_MASTER §4.1 "macOS-Spezifika".
  //
  // DMG/Developer-ID build (kIsMacAppStore == false) → legacy keychain.
  // The data-protection variant ties the item to the app's Team-ID-derived
  // access group, which needs a `keychain-access-groups` entitlement; a build
  // without one — including every locally built, ad-hoc-signed `.app` — fails
  // with errSecMissingEntitlement (-34018). The legacy keychain has no such
  // requirement, which is why the shipped build has always used it and keeps
  // using it now that a Developer ID exists: switching would strand the
  // installed base for no user-visible gain.
  //
  // App Store build (kIsMacAppStore == true) → data-protection keychain.
  // A sandboxed app has no access to the legacy keychain at all, so this one
  // is mandatory rather than preferable. It works because that build is
  // signed with the matching `keychain-access-groups` entitlement
  // (macos/Runner/AppStore.entitlements). Its users are fresh installs with
  // no pre-existing key, so there is nothing to strand.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore),
  );

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

    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }
}
