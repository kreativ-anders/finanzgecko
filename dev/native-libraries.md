# Native vs. bundled implementations

Which of FinanzGecko's dependencies do their work through an operating-system API and which ship their own
implementation — and what that means for the Mac App Store's export-compliance question.

Written when the App Store submission was blocked on exactly this. The short version: as of v1.10 every
cryptographic algorithm the app *performs* runs in Apple's implementation, with one honest residue documented at
the bottom. Implementation details live in AI_MASTER §4.1 "Export compliance"; this file is the audit behind it.

---

## Why this matters at all

Apple's App Store Connect help reduces the whole question to three cases:

| What the app does | Documentation required |
|---|---|
| Encryption limited to that within the Apple operating system | **none** |
| An industry-standard algorithm **not** provided by the Apple OS | French encryption declaration |
| Proprietary algorithms not accepted by IEEE/IETF/ITU | US CCATS **and** French declaration |

Up to and including v1.9, FinanzGecko was case two — not because it invented anything, but because
`package:cryptography` carries its own Dart AES-GCM and PBKDF2 into the binary. AES-256-GCM is as standard as an
algorithm gets; the problem was never the algorithm, only whose code ran it.

Note what the table does *not* say: nothing here is about the app being less secure before. The Dart
implementation is sound. This is a distribution classification, and the fix is a change of implementation, never
of format.

---

## The audit

### Cryptography — the part that was actually blocking

| Where | What | Before v1.10 | Now |
|---|---|---|---|
| `data/app_store.dart` | AES-256-GCM over the whole database | Dart (`package:cryptography`) | **OS** — CryptoKit/CommonCrypto via `cryptography_flutter` |
| `data/backup_crypto.dart` | AES-256-GCM over the backup | Dart | **OS** — same path |
| `data/backup_crypto.dart` | PBKDF2-HMAC-SHA256, 200,000 iterations | Dart | **OS** — CommonCrypto via `dart:ffi` (`data/apple_pbkdf2.dart`) |
| `data/secure_key_store.dart` | Storage of the 256-bit data key | Keychain (`flutter_secure_storage`) | unchanged — already native |
| `data/secure_key_store.dart` | Generation of that key | `Random.secure()` → OS CSPRNG | unchanged — already native |
| `data/app_store.dart` | SHA-256 key fingerprint (`keyId`) | Dart | unchanged — see below |
| `services/update_service.dart` | SHA-256 of a downloaded release asset | Dart | unchanged — and compiled out of the App Store build (`kIsMacAppStore`) |

**Why SHA-256 was left alone.** A one-way hash provides no confidentiality and is not an encryption item under
the US export regulations the App Store question implements; both uses here are integrity checks, and one of them
does not exist in the App Store binary at all. `CC_SHA256` would be a three-line addition to `apple_pbkdf2.dart`
if that judgement is ever challenged — but changing it would mean touching the `keyId` code path that decides
whether a user's data file is considered foreign, which is a poor trade for a paragraph.

**Why PBKDF2 needed its own FFI binding.** `cryptography_flutter` maps algorithms to native APIs unevenly:

| Algorithm | macOS / iOS | Android | Windows / Linux |
|---|---|---|---|
| AES-GCM | native | native | background isolate (Dart) |
| ChaCha20-Poly1305 | native | native | background isolate |
| Ed25519 / X25519 / NIST ECDH-ECDSA | native | — | background isolate |
| **PBKDF2** | **background isolate** | native | background isolate |
| **HMAC** | — | native | — |

PBKDF2 is native on Android only. Since it is what protects every password-protected backup, leaving it on the
Dart implementation would have kept the app in case two of Apple's table for the sake of one algorithm.
`CCKeyDerivationPBKDF` is exported from libSystem, so binding it takes `dart:ffi` and no plugin — which also means
no CocoaPods entry, worth having with that registry going read-only on 2026-12-02.

**Two traps in `cryptography_flutter` worth knowing about.**

1. *It falls back silently, by design.* If the platform channel is unavailable it uses the Dart implementation and
   says nothing. That is the right behaviour for a performance plugin and the wrong behaviour for a compliance
   claim, so `main()` logs which implementation is live and `dev/app-store.md` §4a makes reading that line a
   release step.
2. *It only uses the OS above a size threshold.* `FlutterAesGcm`'s default `CryptographyChannelPolicy` skips the
   platform channel for small payloads, because a round trip costs more than encrypting a few bytes. A new user's
   database is small. `buildAesGcm256()` in `data/crypto_platform.dart` therefore passes
   `CryptographyChannelPolicy(minLength: 0, maxLength: null)` explicitly.

**What no automated test can cover.** `cryptography_flutter` works over a platform channel, and `flutter test`
runs without a plugin registrant — so under test the plugin is always absent and the Dart fallback always wins.
The existing crypto tests still earn their keep (they prove both implementations agree on the format), but the
question "is the OS implementation actually running" is answerable only on a real build. Hence the smoke test.
The PBKDF2 binding is the exception: it is plain FFI, so it does run under `flutter test` on macOS, and the
existing backup tests exercise it for free.

### Everything else

| Dependency | Does it touch an OS API? | Verdict |
|---|---|---|
| `flutter_secure_storage` | Keychain / DPAPI / libsecret | native, unchanged, **do not touch** (holds every user's data key) |
| `file_selector` | NSOpenPanel / Powerbox | native |
| `url_launcher` | `NSWorkspace` | native |
| `package_info_plus` | bundle metadata | native |
| `path_provider` | Foundation directories | native (transitive) |
| `window_manager`, `screen_retriever` | AppKit | native |
| `flutter_local_notifications` | `UNUserNotificationCenter` | native, current. Replaced `local_notifier` (`NSUserNotification`, deprecated since macOS 11, ~20 build warnings, no SwiftPM support). Not a compliance issue either way — no crypto. The modern API needs user authorization, which is why the Einstellungen toggle is opt-in and owns the prompt; see AI_MASTER §5 |
| `http` → `dart:io` | **no** — TLS is BoringSSL, linked into the Flutter engine | the residue; see below |
| `fl_chart`, `provider`, `intl`, `path` | no OS API involved | pure Dart by nature, no crypto, nothing to migrate |
| `ffi` | binding layer only | pure Dart, no implementation of its own |

---

## The residue: TLS

`dart:io`'s secure sockets use BoringSSL compiled into the Dart runtime, not Apple's Network.framework. So the
one HTTPS request the app makes — `api.frankfurter.dev` for exchange rates — does not go through the OS TLS
stack, and BoringSSL sits in the binary whatever the app code does.

Strictly, "encryption limited to that within the operating system" is therefore not literally true of any Flutter
app that makes a network request. In practice:

- Apple's own guidance names HTTPS as the example of exempt, OS-provided encryption.
- No FinanzGecko code calls BoringSSL; it is reached only as the transport under `package:http`.
- The engine links it whether or not the app opens a socket, so removing the request would not remove the library.

**This is a judgement, and it is the weakest part of the declaration.** It is recorded here rather than glossed
over. If it ever needs closing, the route is `package:cupertino_http`, which backs `package:http`'s `Client`
interface with `NSURLSession`; `services/currency_service.dart` already takes an injectable `http.Client`, so the
change is one platform-conditional factory and no logic. It was left out deliberately: it adds a dependency and a
second network code path to a branch whose whole point is that nothing observable changes.

---

## What would invalidate this document

Any of these means re-reading the smoke test in `dev/app-store.md` §4a before the next submission, and possibly
changing `ITSAppUsesNonExemptEncryption` back:

- `cryptography_flutter` dropping macOS support, or changing how `CryptographyChannelPolicy` is applied.
- A new dependency that performs encryption of its own.
- Using `package:cryptography` directly for a new algorithm without checking the table above first.
- Apple restating the three cases.
