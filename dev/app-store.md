# Publishing FinanzGecko on the Mac App Store

Step-by-step checklist for the paid (one-time purchase) Mac App Store release. The free signed DMG on
finanzgecko.app stays free and unchanged — the store version buys convenience and automatic updates, not features.

Everything code-side is already in place: `kIsMacAppStore` (`lib/constants.dart`), `macos/Runner/AppStore.entitlements`,
`packaging/macos/build_appstore.sh`, and the sandbox itself (see dev/ai/persistence.md). What follows is the part that
happens in Apple's web UIs and cannot be scripted or tested from this repo.

> **Order matters more than usual here.** Certificates depend on the App ID, the provisioning profile depends on
> both, the build depends on the profile, and selling depends on a finished agreement. Doing step 5 before
> step 2 means redoing step 5.
>
> **Working through this the first time? The route is §3 in parallel with §2 → §4 → [§4b TestFlight](#4b-testflight-first--do-this-before-submitting-anything) → §5.**
> TestFlight needs neither the agreements nor App Review, and it is the only way to observe this app's keychain
> and crypto behaviour under App Store signing before committing to a submission.

---

## 0. Before you start — two decisions that are hard to reverse

**Bundle ID is permanent.** `de.finanzgecko.app` is already the bundle ID of the shipped DMG build and is also the
sandbox container name. Register exactly this. It cannot be changed or reused later.

**The licence question is real.** The repo is GPL-3.0 with a Commons Clause. GPL-3.0 and the App Store's terms are
a known conflict (the VLC precedent): the GPL forbids adding the usage restrictions Apple's terms impose. This is
only resolvable because **you hold the copyright** — a sole author may distribute their own work under different
terms to different channels. Two things to verify before submitting:

- No third-party dependency is GPL/AGPL. Current direct dependencies (Flutter, `provider`, `http`, `fl_chart`,
  `file_selector`, `window_manager`, `intl`, `url_launcher`, `flutter_secure_storage`, `cryptography`,
  `cryptography_flutter`, `ffi`, `flutter_local_notifications`, `package_info_plus`, `path`) are BSD/MIT/Apache — confirm with
  `flutter pub deps` before each submission, not just once.
- Decide how the store listing describes licensing. Simplest honest framing: the source stays GPL on GitHub, the
  App Store binary is distributed by you under Apple's standard EULA.

---

## 1. Apple Developer Program membership

You already have this (it is what issued the Developer ID used for notarizing the DMG). Confirm it is active and
not near expiry — **$99/year**, and if it lapses, the App Store listing is removed, not merely frozen.

Note the **Team ID** (ten characters, App Store Connect → Membership details). `build_appstore.sh` requires it as
`TEAM_ID`; it is substituted into the `keychain-access-groups` entitlement.

---

## 2. Certificates, Identifiers & Profiles

At <https://developer.apple.com/account/resources>.

**2a. App ID**
Identifiers → `+` → App IDs → App → Description "FinanzGecko", Bundle ID **explicit** `de.finanzgecko.app`.

The App ID editor has three tabs. **Tick nothing in any of them.**

| Tab | What it is | FinanzGecko |
|---|---|---|
| Capabilities | Entitlement-gated Apple services (iCloud, Push, Sign in with Apple, Apple Pay, Game Center, Network Extensions, …) | none — the app uses no Apple service |
| App Services | Opt-in services attached to the App ID (ad attribution and similar) | none |
| Capability Requests | Application form for *managed* capabilities Apple must approve per account | nothing to request |

Three that look like they might apply and do not:

- **Keychain sharing** is not on this page at all, and does not need to be. Every App ID automatically has
  keychain access; the `keychain-access-groups` entitlement in `AppStore.entitlements` uses the app's own
  App ID prefix, which needs no capability. (Apple DTS states this explicitly.)
- **App Sandbox** and **Hardened Runtime** appear in Apple's macOS capability reference, but they are entitlements
  the build sets and `build_appstore.sh` asserts — not something to enable here.
- **In-App Purchase** is for purchases *inside* the app. A paid-up-front app needs nothing; the price is set in
  App Store Connect, not here.

If a keychain error `-34018` ever shows up at runtime, the cause is the Team ID substitution in the entitlements
(`build_appstore.sh` checks it), not a missing capability. Confirm what the profile actually grants with:

```
security cms -D -i FinanzGecko_Mac_App_Store.provisionprofile | plutil -p - | grep -A3 keychain-access-groups
```

**2b. Two new certificates**
These are *different* from your Developer ID certificate and do not replace it:

| Certificate | Signs | Used by |
|---|---|---|
| Mac App Distribution (`3rd Party Mac Developer Application`) | the `.app` | `APP_SIGN_IDENTITY` |
| Mac Installer Distribution (`3rd Party Mac Developer Installer`) | the `.pkg` | `PKG_SIGN_IDENTITY` |

Create both via Certificates → `+`, using a CSR from Keychain Access
(*Certificate Assistant → Request a Certificate From a Certificate Authority*, "Saved to disk"). Download and
double-click each to install into the login keychain.

Verify both landed:

```
security find-identity -v -p codesigning | grep "3rd Party Mac Developer Application"
security find-identity -v              | grep "3rd Party Mac Developer Installer"
```

**If those print nothing, the certificates are almost certainly fine and the intermediate is missing.**
`find-identity -v` lists only *valid* identities, and a certificate whose issuer chain can't be built is not
valid — so it is silently omitted, which reads exactly like "the certificate didn't install". Keychain Access
tells the truth: under *login → My Certificates* the entry is there in red, "certificate is not trusted".

The cause is that these chain through **Apple Worldwide Developer Relations CA**, while the Developer ID
certificate used for the DMG chains through a different intermediate you already have — so DMG signing keeps
working and only the store certificates look broken. Apple publishes five WWDR generations; installing all of
them is harmless:

```
cd ~/Downloads
for g in G2 G3 G4 G5 G6; do
  curl -sO "https://www.apple.com/certificateauthority/AppleWWDRCA$g.cer"
  security import "AppleWWDRCA$g.cer" -k ~/Library/Keychains/login.keychain-db
done
security find-identity -v
```

Do **not** revoke or regenerate the certificates over this — nothing is wrong with them, and a new CSR would
just produce two more untrusted certificates.

**Duplicate entries.** `find-identity` may list the same SHA-1 twice (one per keychain the certificate reached).
Harmless in itself, but `codesign` can refuse a name that matches more than one identity as ambiguous. If that
happens, pass the fingerprints instead of the names — `build_appstore.sh` greps its identity variable against
`find-identity` output, so a hash works verbatim:

```
export APP_SIGN_IDENTITY=<sha1 of the Application cert>
export PKG_SIGN_IDENTITY=<sha1 of the Installer cert>
```

**2c. Provisioning profile**
Profiles → `+` → **Mac App Store** distribution → App ID `de.finanzgecko.app` → the Mac App Distribution
certificate → name it e.g. `FinanzGecko Mac App Store`. Download the `.provisionprofile`.

Keep it outside the repo (it embeds your team identity) and pass it as `PROVISION_PROFILE`. Profiles expire
after a year — a failed upload a year from now is usually this.

---

## 3. Agreements, Tax and Banking

App Store Connect → Business (formerly "Agreements, Tax, and Banking"). **Nothing paid can ship until this is
green**, and the tax review takes days, so start it before you build.

It gates *selling*, not testing: TestFlight (§4b) runs under the Apple Developer Program License Agreement you
already have. You can also create the app record without it — you just cannot set a price until it is signed.
So start this now and get on with §2 and §4b while it clears.

Strict order, because Apple only reveals each step after the previous one:

1. **Paid Applications Agreement** — request and accept.
2. **Bank account** — a German IBAN in your or your business's name.
3. **Tax forms** — you will be prompted through them. As a German developer you will complete a **W-8BEN**
   (individual) or **W-8BEN-E** (company) for US withholding, claiming Germany–US treaty benefits, plus German
   tax details. Apple acts as commissionaire for EU sales, so Apple handles VAT toward the customer — but your
   own income tax and the question of Kleinunternehmerregelung vs. Regelbesteuerung are yours. **I am not a tax
   advisor; treat this paragraph as a pointer, not advice, and confirm the treaty and VAT handling with a
   Steuerberater before the first payout.**

**Small Business Program** — apply at <https://developer.apple.com/app-store/small-business-program/>. Under
$1M proceeds in the prior calendar year, commission drops **30% → 15%**. It is an annual opt-in, not automatic,
and it is the single highest-value form on this page. Do it now.

---

## 4. The App Store Connect record

> **Listing text, keywords, review notes and screenshot order are written out ready to paste in
> [app-store-listing.md](app-store-listing.md).** Keep that file and `docs/index.html` in agreement — they make
> the same promises to the same people.

Apps → `+` → New App → macOS → name, primary language German, bundle ID `de.finanzgecko.app`, SKU.

**SKU:** internal only — never shown to users, never part of a URL, and **permanent** once set. It identifies the
app in financial and sales reports. Use `finanzgecko-macos`. Encode nothing that can change: no price, no version,
no year, no "v2"; and don't reuse the bundle ID, which only invites confusing the two later.

**Price** — one-time purchase: pick a tier. Apple's pricing is tier-based per storefront; you set the base and
Apple derives the rest.

**Screenshots** — you already have these at native Retina resolution in `docs/assets/screenshots/`, produced by
`tool/capture_screenshots.sh` (see [ai/screenshots.md](ai/screenshots.md)). Apple requires 1280×800, 1440×900, 2560×1600 or 2880×1800; the
existing crops will likely need re-exporting to an accepted size. Use the **demo data** shots
(`demo/finanzgecko-demo.json`) — never real finances.

**App Privacy** — answer "Data Not Collected". This is accurate and unusually easy to defend: the app makes
exactly two network calls (`api.frankfurter.dev` for rates, `api.github.com` for the update check, the latter
compiled out of this build), sends no identifiers, and has no analytics. Link the privacy policy to
<https://finanzgecko.app/datenschutz.html>.

**Category** — Finance. Already declared in `Info.plist` as `public.app-category.finance`.

**Export compliance** — answered in `macos/Runner/Info.plist`, so App Store Connect does not ask. The key is
`ITSAppUsesNonExemptEncryption = false`, claimed on Apple's first case: *encryption limited to that within the
Apple operating system*. Since v1.10 that is what the app does — AES-256-GCM through `cryptography_flutter`
(CryptoKit/CommonCrypto) and PBKDF2-HMAC-SHA256 through CommonCrypto (`lib/data/apple_pbkdf2.dart`).

This reverses the earlier position in this file, which was that the app used the `cryptography` package's own
implementation and that the exemption was therefore an open legal call. It was — that is why the work was done
rather than the question answered optimistically. The full reasoning, the per-dependency audit, and the one
residue that is *not* solved (the Flutter engine links BoringSSL for `dart:io` TLS) are in
[native-libraries.md](native-libraries.md).

**The declaration is only true while the OS implementations are the ones actually running.** `cryptography_flutter`
falls back to a bundled Dart implementation silently, and no automated test can catch that: `flutter test` runs
without a plugin registrant and always sees the fallback. The check is therefore manual, and it is the reason for
the smoke test below. If it ever fails, change the `Info.plist` key back before submitting — a wrong `false` is a
compliance problem, not a formality.

---

## 4a. Crypto smoke test — run before every submission

Not optional and not automatable. `flutter test` covers that both implementations produce the same bytes; it
cannot cover which one runs, because it runs without a plugin registrant. Everything below is done on a real
build, in this order. Any step failing means the `ITSAppUsesNonExemptEncryption` key in `macos/Runner/Info.plist`
does not currently describe the app.

**Before you start:** make a copy of your real data file and of one encrypted backup written by the *previous*
version. Steps 3 and 4 are the ones that would otherwise cost you data.

1. **The implementations in use.** Launch the build, then in Console.app filter on `FinanzGecko crypto`. Expected,
   exactly:

   ```
   FinanzGecko crypto: AES-256-GCM = OS (cryptography_flutter), PBKDF2-HMAC-SHA256 = OS (CommonCrypto)
   ```

   `= Dart` on either side means the fallback is live. Do not submit. This is the single most important line on
   this page.

2. **Run it for both delivery forms.** The DMG build (`build_dmg.sh`) and the App Store build
   (`build_appstore.sh`) register plugins the same way, but the sandbox and the App Store signing identity differ,
   and this has surprised us before with the keychain. Check the log line in both.

3. **An existing data file still opens.** Start the new build against your real (copied) data file. All accounts,
   Kontostände, Vermögenswerte and Fixposten present, no "Diese Datei gehört zu einem anderen Computer", no
   `.unreadable-*` file appearing next to it. This proves the key fingerprint and the envelope are unchanged.

4. **An old encrypted backup still imports.** *Backup importieren…* with a password-protected backup written by
   the previous version. It must open with its original password. This is the PBKDF2 change under test: if
   CommonCrypto and the Dart implementation disagreed by a single byte, this is where it shows.

5. **A new backup still opens elsewhere.** Export a password-protected backup from the new macOS build and import
   it on Windows or Linux, where the Dart implementation runs. Then the reverse. Both must succeed — one file
   format, regardless of which machine wrote it.

6. **A wrong password still says so.** Import an encrypted backup with a deliberately wrong password. The message
   must be the ordinary wrong-password one, not an internal error. `decryptBackup` reports every decryption
   failure as a wrong password, so a broken platform path would hide here wearing the wrong label.

7. **Plaintext backups are untouched.** Export without a password, reimport. Still plain JSON, still lossless.

8. **The update path is still absent from the App Store build.** Unchanged by this work, but it shares the build
   script and it is the rejection most likely to happen twice — see §6.1.

## 4b. TestFlight first — do this before submitting anything

TestFlight is not a nicety here. Three things about this app can only be observed on a build that Apple has
signed and sandboxed: whether the OS crypto still runs, what a DMG user actually sees when they switch channels,
and whether `UpdateService` really left the binary. A TestFlight build goes through the **identical** signing and
packaging pipeline as a store submission, so it reproduces all three on your own Mac — without publishing
anything, and without App Review seeing it.

**What TestFlight does *not* need:**

- **No Paid Apps Agreement, no bank account, no tax forms.** Those gate *selling*. The Apple Developer Program
  License Agreement you already have covers beta distribution. Do start the Business paperwork in parallel
  (§3) — it has the longest lead time — but it does not block this.
- **No Beta App Review**, because you are your own *internal* tester. Internal testing is immediate; only
  external testers (up to 10,000) need the one-time review of a first build.
- **No price, no screenshots, no listing copy.** Set those later.

**What it does need**, and this is the whole of §2 plus a record: the App ID, both distribution certificates, the
Mac App Store provisioning profile, and an App Store Connect app record with bundle ID `de.finanzgecko.app`.
You can create the record before the Paid Apps Agreement is signed — you just cannot set a *price* until it is,
so leave the pricing untouched for now.

**The build must contain the store hardening.** The `v1.10.0` tag sits one commit before it, so a TestFlight
build can never come from that tag. Cut a patch release first and build from it — both channels then mean the
same thing by a version number, which is worth more than saving a release.
Every re-upload bumps the build number (`+22`, `+23`); App Store Connect rejects a repeat, even for the same
version string.

Build and upload exactly as in §5, then in App Store Connect: TestFlight → Internal Testing → new group → add
yourself → attach the build once processing finishes (10–60 minutes, you get an email). Install
**TestFlight from the Mac App Store** and install FinanzGecko from there. Builds expire after 90 days.

### What this run has to answer

Run these in order on your own Mac. Steps 2–4 are the ones that were argued about from first principles for two
weeks; this is where they get settled.

**Before you start:** copy your real data file somewhere safe, and keep an encrypted backup written by the DMG
build. Steps 3 and 4 are the ones that would otherwise cost you data.

1. **The full §4a crypto smoke test, on the TestFlight build.** Console.app must show
   `AES-256-GCM = OS (cryptography_flutter), PBKDF2-HMAC-SHA256 = OS (CommonCrypto)`. This is the first time
   those paths run under App Store signing and the sandbox together — §4a step 2 exists precisely for this.

2. **`UpdateService` is really gone from the binary.** The nullable `AppState.updateService` is supposed to let
   the tree shaker drop the class and its URL. Verify rather than trust:

   ```
   strings /Applications/FinanzGecko.app/Contents/Frameworks/App.framework/Versions/A/App | grep -c api.github.com
   ```

   Expect **0** on the TestFlight build. Run the same command against the DMG build's bundle for contrast — it
   should be non-zero there. A non-zero count on the store build means something still references the service;
   the build is not wrong, but Guideline 2.4.5 gets harder to argue and the cause is worth finding.

3. **The channel switch, with your real data.** With the DMG build's data file in the container, launch the
   TestFlight build. Expected: the `_ForeignDataApp` screen with the **App Store wording** ("andere
   FinanzGecko-Version", not "anderer Computer"), no `.unreadable-*` file appearing beside the data, no keychain
   password prompt. Then quit, reinstall the DMG build, and confirm all data is back untouched. That round trip
   is the claim in §7; this is the only way to know it holds.

4. **The backup route across channels.** Export a password-protected backup from the DMG build, import it into
   the TestFlight build. It must open with its original password. This is the path you will be telling switchers
   to use, so it has to work before you tell anyone.

5. **A store→store update keeps data.** Upload `+22`, update through TestFlight, confirm the data written by
   `+21` still opens with no prompt. This is the claim that Apple's re-signing is harmless because access hangs
   off `keychain-access-groups` rather than a per-item ACL — cheap to verify here, expensive to get wrong later.

6. **The ≤1.7 case, deliberately reproduced.** Move the container aside so only a pre-sandbox
   `~/Library/Application Support/de.finanzgecko.app/` remains, then launch the TestFlight build. Expected —
   and this is the known open gap — an empty app with no explanation, because `AppStore.entitlements` has no
   temporary exception and `SandboxMigration` cannot reach the old path. Look at it, decide whether it ships
   like that, and fix it before the real submission rather than after.

If steps 1–5 pass and step 6 gets whatever treatment you choose, the submission in §5 onwards is a formality.

---

## 5. Build and upload

**Version and build number come from `pubspec.yaml` alone.** `macos/Runner/Info.plist` maps
`CFBundleShortVersionString` to `$(FLUTTER_BUILD_NAME)` and `CFBundleVersion` to `$(FLUTTER_BUILD_NUMBER)`, both
derived from `version: <name>+<number>`. Nothing needs editing in Xcode.

Two App Store rules that the DMG channel doesn't have:

- **`CFBundleShortVersionString` must increase from one store version to the next.** Component-wise numeric
  comparison, so `1.10.0` > `1.9.0` is fine.
- **`CFBundleVersion` must increase with every *upload*, even for the same version.** A rejected or replaced
  build cannot be re-uploaded under the same build number. So a resubmission goes `1.10.0+20` → `1.10.0+21`,
  and the DMG channel just carries the higher number along at the next release.

Don't submit a store version whose number never shipped anywhere else — keep the two channels on the same
`pubspec.yaml` version so a support mail naming "1.10.0" means one thing.

```
export TEAM_ID=XXXXXXXXXX
export PROVISION_PROFILE=~/secure/FinanzGecko_Mac_App_Store.provisionprofile
./packaging/macos/build_appstore.sh
```

The script builds with `--dart-define=FINANZGECKO_MAS=true`, substitutes the Team ID into the entitlements,
signs inside-out with the Mac App Distribution certificate, asserts the sandbox is actually present, and produces
a signed `.pkg`. Unlike `build_dmg.sh` it **aborts** on a missing identity rather than producing an unsigned
artifact — an unsigned `.pkg` is never useful.

Then validate before uploading (the validate step catches most rejections in seconds instead of hours):

```
xcrun altool --validate-app  -f FinanzGecko-mac-appstore.pkg -t macos \
  --apiKey "$APPLE_API_KEY_ID" --apiIssuer "$APPLE_API_ISSUER_ID"
xcrun altool --upload-package  FinanzGecko-mac-appstore.pkg -t macos \
  --apiKey "$APPLE_API_KEY_ID" --apiIssuer "$APPLE_API_ISSUER_ID"
```

`--upload-app` is deprecated in favour of `--upload-package`. The Transporter app from the Mac App Store does the
same thing with a GUI if you prefer.

Uploaded builds take 10–60 minutes to appear in App Store Connect. **No notarization step** — App Review covers it.

---

## 6. Review risk, specific to this app

Ordered by how likely each is to actually bite:

1. **Guideline 2.4.5(iv) — self-updating.** The in-app update check must not exist in this build. Three things
   drop together via `kIsMacAppStore`: the *Nach Updates suchen* entry, the Hilfe section's sentence about the
   GitHub API, and `UpdateService` itself, because `AppState.updateService` is `null` there and nothing
   references the class. That last part is what actually keeps the `api.github.com` URL out of the
   binary; the hidden button alone never did. Verify in the built app before uploading; this is the rejection
   most likely to happen twice. See [ai/persistence.md](ai/persistence.md).
2. **Sandbox actually active.** `build_appstore.sh` asserts this, because a build that merely *looks* like a
   store build otherwise fails at review instead of at build time.
3. **Finance category scrutiny.** Reviewers may ask how the app handles financial data. The answer is short and
   true: manual entry only, no bank connection, no PSD2, no account aggregation, nothing leaves the device.
   Put this in the Review Notes proactively.
4. **Demo data.** Provide `demo/finanzgecko-demo.json` context in Review Notes — the app has no login, so no demo
   account is needed, but a reviewer opening an empty app may not see what it does. Say "import
   *Backup importieren…* or just add an account".
5. **Same-binary confusion.** If a reviewer finds the free GitHub download, that is fine and permitted — you may
   distribute the same app outside the store. No action needed unless asked.

---

## 7. After approval

- The store version updates itself, and store→store updates cannot lose data: keychain access is decided by the
  `keychain-access-groups` entitlement, not by a per-item ACL, so Apple re-signing each version is harmless. Only
  a Team-ID change or an app transfer to another team would break it.
- **A DMG user who switches will need a Backup round trip, and that is not a maybe.** Both builds are sandboxed
  into the same container (`de.finanzgecko.app`), so the store build finds the file — but its key lives in the
  data-protection keychain and the DMG build's in the login keychain. The `keyId` fingerprint won't match, the
  app shows `_ForeignDataApp`, in wording branched for the store build, and writes nothing. Reinstalling the DMG
  build restores full access. Say this plainly on the download page rather than letting people discover it.
- Update the website: `docs/download.html` gains a Mac App Store option, and the "ist und bleibt kostenlos"
  framing on `docs/index.html` plus the Stripe support button need rewording so the free and paid channels do not
  read as contradictory.
- Add the App Store link to `README.md` and `docs/llms.txt`.
- Note in `docs/datenschutz.html` that the App Store version is distributed by Apple (Apple then processes
  purchase data as its own controller) — required, and currently unlisted among the third parties.

---

## Recurring, not one-time

- Developer Program membership: renews yearly, **$99**.
- Small Business Program: re-confirmed each January against the prior year's proceeds.
- Provisioning profile: expires yearly.
- Certificates: expire (typically 5 years) — a build failure long after everything worked is usually this.
