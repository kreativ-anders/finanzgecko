# Publishing FinanzGecko on the Mac App Store

Step-by-step checklist for the paid (one-time purchase) Mac App Store release. The free signed DMG on
finanzgecko.app stays free and unchanged — the store version buys convenience and automatic updates, not features.

Everything code-side is already in place: `kIsMacAppStore` (`lib/constants.dart`), `macos/Runner/AppStore.entitlements`,
`packaging/macos/build_appstore.sh`, and the sandbox itself (see dev/ai/persistence.md). What follows is the part that
happens in Apple's web UIs and cannot be scripted or tested from this repo.

> **Order matters more than usual here.** Certificates depend on the App ID, the provisioning profile depends on
> both, the build depends on the profile, and the upload depends on a finished agreement. Doing step 5 before
> step 2 means redoing step 5.

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
No capabilities need enabling — the app uses none of the entitlement-gated services (no iCloud, no Push, no
Sign in with Apple). Keychain sharing is covered by the `keychain-access-groups` entitlement in the build and
does not require a capability here.

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

**2c. Provisioning profile**
Profiles → `+` → **Mac App Store** distribution → App ID `de.finanzgecko.app` → the Mac App Distribution
certificate → name it e.g. `FinanzGecko Mac App Store`. Download the `.provisionprofile`.

Keep it outside the repo (it embeds your team identity) and pass it as `PROVISION_PROFILE`. Profiles expire
after a year — a failed upload a year from now is usually this.

---

## 3. Agreements, Tax and Banking

App Store Connect → Business (formerly "Agreements, Tax, and Banking"). **Nothing paid can ship until this is
green**, and the tax review takes days, so start it before you build.

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

Apps → `+` → New App → macOS → name, primary language German, bundle ID `de.finanzgecko.app`, SKU (free-form,
e.g. `finanzgecko-macos`).

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

## 5. Build and upload

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

1. **Guideline 2.4.5(iv) — self-updating.** The in-app update check must not exist in this build. It is compiled
   out via `kIsMacAppStore`, and the Hilfe section drops both the link and its sentence about the GitHub API.
   Verify in the built app before uploading; this is the rejection most likely to happen twice.
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

- The store version updates itself. Users who came from the DMG and switch will land in the **same sandbox
  container** (`de.finanzgecko.app`), so their migrated data is already there — but the App Store build is signed
  by Apple, not your Developer ID, so the **Keychain item may not carry over** and they may need *Backup
  importieren…*. Verify this before telling anyone otherwise.
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
