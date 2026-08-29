# FinanzGecko — Platform specifics, CI & release

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

- **Minimum OS versions follow Flutter, without an extra check of our own.** If a Flutter upgrade raises a
  platform floor (most recently: 3.47 raises macOS from 10.15 to 12), that's adopted rather than weighed against
  our own list. Rationale, worked out once on 2026-08-16: Flutter's floors sit **behind** each vendor's support
  window, not ahead of it — macOS 12 got its last security updates in September 2024, Windows 10 in October 2025,
  Debian 10 (even LTS) in June 2024; all three remain Flutter's minimum. Anyone affected by such a bump has
  therefore been running an unpatched system for years already. For an app whose promise is the security of
  local financial data, carrying such systems along isn't the more generous choice — it's the worse one. Google
  maintains these deadlines against vendor cycles anyway — a second list in the repo would just be one more place
  to go stale.
  **The one exception that needs a real decision:** a bump that excludes an OS version the vendor is *still*
  shipping security updates for. That has never happened so far.
- **Intel Macs are the one thing that needs watching** — hardware, not OS. macOS 26 Tahoe is the last macOS
  version for Intel; Flutter currently demotes x64 macOS to a warning. If that turns into a hard error, the two
  "Apple Silicon & Intel" claims in `docs/download.html` need to be updated in the same commit (a candidate for a
  guard in `test/docs_consistency_test.dart`).

- Cross-platform builds are **not possible** — every platform has to be built on its own OS; all three at once
  only via GitHub Actions (`.github/workflows/release.yml`, on a tag push `v*.*.*` or manually via
  `workflow_dispatch`). A `gate` job (analyze + test + icon pipeline) runs before the build jobs; if it fails, no
  bundle gets built/released. There's deliberately no separate push/PR CI workflow — `flutter analyze`,
  `flutter test`, and `dart format` run locally before commit (see [`CLAUDE.md`](../../CLAUDE.md)), release.yml is the
  only GitHub workflow in the repo.
  **Build jobs' `if:` conditions must start with `!cancelled() &&`** — not cosmetic: `bump-version` is
  deliberately skipped on a tag push and on "bump: none", and GitHub by default skips everything hanging off a
  skipped job via `needs`. This inheritance only turns off once the condition contains a status-check function;
  the also-present `needs.bump-version.result == 'skipped'` is **not** enough on its own, even though it reads as
  if it should be. Without `!cancelled()`, neither ad-hoc test builds nor tag-push releases (path A) ran — only
  the bump-button path (path B) did — and the run was reported fully green regardless, just without a single
  built job. Don't "clean this up".
- **Splash logo per theme** (`assets/logo/`): two files with an identical crop (512×333 each, taken from
  `kreativ-anders/static-assets`). **The names describe the image's color, not the theme** —
  `kreativ-anders-light-512.png` is the *light* logo (white text) and belongs on the **dark** background,
  `kreativ-anders-dark-512.png` the *dark* one (black text) on the **light** one. `splash_screen.dart` picks via
  `kIsDarkTheme` (`theme.dart`). Before this, the light logo ran on both themes and only reached 1.3:1 on
  light — practically invisible; now 13.7:1 resp. 6.4:1. The mapping looks swapped at first glance, but isn't:
  don't "straighten it out".
- Icon pipeline: a single 1024×1024 master (`assets/icon/icon.png`) feeds every platform format via
  `dart run tool/generate_icons.dart` — `flutter_launcher_icons` is only used for macOS now (`pubspec.yaml`,
  `windows.generate: false`); Windows `.ico` and Linux Hicolor icons are built by `tool/generate_icons.dart`
  itself (`generateWindowsIcon`/`generateLinuxIcons`, both pure functions, also run by `flutter test`). Reason:
  `flutter_launcher_icons`' own Windows generator writes only a single 256px size into the `.ico`
  (`icon_size` config), which leaves Explorer/taskbar/start menu without an icon after install instead of
  downscaling — `generateWindowsIcon` instead produces a real multi-size `.ico` (16–256px).
- Release artifacts are **finished packages rather than raw bundle folders** (which confused test users and broke
  the start when individual files were deleted): Windows → Inno Setup installer `FinanzGecko-<version>-Setup.exe`
  (`packaging/windows/finanzgecko.iss`, built with `iscc` in the `windows` job), Linux → a single executable
  AppImage `FinanzGecko-<version>-x86_64.AppImage` (`packaging/linux/build_appimage.sh` via `appimagetool`),
  macOS → a disk image `FinanzGecko-<version>-mac.dmg` (`hdiutil` step in the `macos` job, image =
  `FinanzGecko.app` + a symlink to `/Applications`). The version is read from `pubspec.yaml` in every build job
  (not from the git tag), so even untagged ad-hoc test builds (`workflow_dispatch`, `bump: none`) get a versioned
  file name. `packaging/linux/install.sh` remains as an alternative for the Linux start menu from an unpacked bundle.
- **Windows: the three VC++ runtime DLLs (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`) ship next to
  `finanzgecko.exe`**, copied into the build output by the `windows` job in `release.yml` right after `flutter
  build windows --release`, before `iscc` packages `{#BuildDir}\*` (no change needed in `finanzgecko.iss` itself).
  `windows/CMakeLists.txt` is the stock Flutter template — dynamically linked against the VC++ runtime, no
  `CMAKE_MSVC_RUNTIME_LIBRARY` override — and that runtime is usually already present on a real user's machine
  (Windows Update, other software) but isn't guaranteed everywhere. This surfaced as a real gap: the winget-pkgs
  submission (PR #417767) failed `Validation-Executable-Error` because their validation VM lacks it —
  `finanzgecko.exe` exited with `STATUS_DLL_NOT_FOUND` (`0xC0000135`) before ever opening a window, which the
  automated test reports as "executable not found." App-local DLLs (Windows' own DLL search order checks the exe's
  own folder first) rather than a system-wide redistributable install: covers `finanzgecko.exe`,
  `flutter_windows.dll`, *and* any prebuilt plugin DLL that dynamically links the CRT (e.g. `dartjni.dll`) equally,
  without needing admin rights or an extra installer step — switching to a statically-linked CRT
  (`CMAKE_MSVC_RUNTIME_LIBRARY`) would only cover binaries built from this repo's own CMake, not prebuilt
  third-party plugin DLLs. Source path: `vswhere.exe` → the VS installation → `VC\Redist\MSVC\<version>\x64\
  Microsoft.VC*.CRT\`, the path Microsoft itself documents for redistributing these files, not `System32` (avoids
  depending on whatever happens to be installed on the runner already).
- **macOS: DMG instead of a zipped `.app` bundle** (since August 2026). Two reasons, the second is the real one:
  first, "open the image, drag the app onto `Programme`" is the macOS-familiar flow — with the ZIP, the bundle
  landed in the downloads folder and often got launched from there. Second, a DMG can carry the notarization
  ticket (`xcrun stapler staple`), a ZIP can't: its ticket would need Gatekeeper to look it up online at Apple on
  first launch. The switch is therefore a prerequisite for the planned signing/notarization (see
  [ROADMAP.md](../../ROADMAP.md)) and was deliberately done *beforehand*, so the file name doesn't change twice.
  `hdiutil` instead of `create-dmg`: present on every macOS runner, no extra dependency.
- **Signing/notarizing runs through `packaging/macos/build_dmg.sh`** — one script for local *and* CI (like
  `packaging/linux/build_appimage.sh`), so the hand-tested build and the CI build never diverge. It signs
  inside-out (first embedded `.dylib`s, then every framework, the bundle last; deliberately **no** `--deep`,
  which Apple doesn't intend for distribution), with Hardened Runtime (`--options runtime`, required for
  notarization) and `--timestamp`. Only the outer bundle gets entitlements.
  **Notarized twice**: once a ZIP of the app, to staple the ticket *into the app* via `stapler`, and once the
  finished DMG. Stapling only the DMG isn't enough — the app pulled out of it would then carry no ticket of its
  own, and Gatekeeper would have to check online on first launch, exactly what the DMG path is meant to avoid.
  If identity or credentials are missing, the script builds an **unsigned** DMG and warns instead of aborting:
  forks and ad-hoc test builds have no secrets, and a hard failure would block the atomic release chain there.
  `SIGN_IDENTITY` is deliberately just the substring `Developer ID Application` (codesign resolves it as long as
  exactly one identity matches) — no name and no team ID in the repo.
  Every `codesign` call runs through a `retry` function (5 attempts, growing pause). This is **not** precautionary
  decoration: `--timestamp` is a network call per signature to Apple's timestamp service, which occasionally
  doesn't answer; codesign reports that as `errSecInternalComponent` and aborts, the same call goes through
  unchanged seconds later (exactly what happened on the first local signing run). Don't remove it.
- **Checksums:** the `release` job additionally drops a `SHA256SUMS` over the three platform packages as a
  release asset and writes the same hashes into the release text (`body_path`). That's the one allowed exception
  to the rule below — not a binary duplicate, but a text file in `sha256sum -c`'s standard format.
  `sha256sum FinanzGecko-*` instead of `sha256sum *`: the shell creates the target file via the redirect *before*
  the command runs, so a `*` would hash the still-empty `SHA256SUMS` against itself. For `docs/download.html` the
  file is uncritical: asset resolution matches via `data-asset-suffix`, and `SHA256SUMS` carries none of those.
  The release text itself is **English** ([code-style.md](code-style.md) "Language") and claims integrity, not authenticity —
  `SHA256SUMS` is unsigned.
- **No unversioned alias assets:** every release carries exactly **one** binary per platform (the versioned
  name). An earlier approach additionally uploaded a byte-identical unversioned copy
  (`cp`/`Copy-Item` before the respective `upload-artifact` step), so `docs/download.html` could link firmly to
  `.../releases/latest/download/<fixed name>` — but that doubled the upload and the asset list per release for
  pure duplicates. Stays abolished.
- **`docs/download.html` resolves the concrete asset client-side** (progressive enhancement, since August 2026).
  Three equal cards ship, whose `href` statically points at `.../releases/latest` — exactly the state that stays
  correct without JavaScript, without network, and under an API rate limit. A script at the end of the page adds
  two independent improvements:
  1. **OS detection** (`navigator.userAgentData.platform`, falling back to `navigator.platform`/user agent): the
     matching card moves to the front via `grid.insertBefore` and gets `.download-card-primary` + a "Für dein
     System erkannt" badge. The other two stay **equally sized and visible** — a misdetection must never cut
     anyone off from the right download. That's why there's deliberately *no* single big button. Mobile UAs
     (iOS/Android) are deliberately not detected: there's no mobile version, so all three cards stay equal there.
  2. **Asset resolution** via `api.github.com/repos/.../releases/latest`: per card, the asset is matched via
     `data-asset-suffix` (`-Setup.exe`, `-mac.dmg`, `-x86_64.AppImage`), the button's target is set to its
     `browser_download_url`, and version + file size appear in `.download-meta`. If no matching asset is found
     (e.g. because a platform build failed in that release), that **one** card keeps the fallback link.

  Reason for the reversal against the earlier "no JS/GitHub-API calls on the static page" rule: all three buttons
  used to end up on the same release page, where users had to pick the right one out of five assets (three
  binaries + two source archives) — the single biggest hurdle on the whole page for this audience. The rule was
  already broken anyway, since `docs/index.html` queries the same API for the star counter.
  **The suffixes are coupled to the artifact names in `release.yml`** — if a file name changes there, the
  `data-asset-suffix` attributes must be updated too, otherwise the page silently falls back to the release page
  (no visible error, easy to miss). Every new network call the website makes additionally belongs in
  `docs/datenschutz.html`.
- **Website under its own domain `finanzgecko.app`** (GitHub Pages + `docs/CNAME`). Absolute URLs consistently
  belong on this domain — `kreativ-anders.github.io/finanzgecko` must appear nowhere anymore (GitHub does
  redirect, but a `canonical`/`og:url` on the old host splits SEO and analytics signals across two hostnames).
- **Reach measurement with Pirsch Analytics** (`<script defer src="https://api.pirsch.io/pa.js" id="pianjs"
  data-code="…">` in the `<head>` of **every** page under `docs/`, don't forget it on new pages). Deliberately
  chosen because it's cookie-free, doesn't store IPs, and is hosted in Germany: so no cookie banner and no
  consent under § 25 TDDDG are needed, matching the product's privacy promise. That applies **only to the
  website** — the app itself still sends **no** telemetry; keep that separation clean in `docs/index.html`,
  `docs/llms.txt`, and `docs/datenschutz.html`. Every additional third-party integration must be added to
  `docs/datenschutz.html`.
- **No automatic/silent auto-updater — but a checked download on click** (changed in August 2026; the earlier
  version excluded the download too, the rationale being the missing signing certificate. That no longer holds
  for macOS, still does for Windows — see [ROADMAP.md](../../ROADMAP.md)). What stays unchanged is the crucial part:
  **every** network call happens because of a click. No startup check, no periodic check, no background download.
  Flow via `UpdateService` (`lib/services/update_service.dart`):
  1. Einstellungen → Hilfe → "Nach Updates suchen" fetches the latest release tag
     (`api.github.com/repos/kreativ-anders/finanzgecko/releases/latest`) and compares it against `PackageInfo`.
     **Already current** and **failed** (offline, GitHub down, rate limit) stay snackbars, the latter with a
     generic "please try again later" instead of an error dialog. **New version available** is deliberately an
     `AlertDialog` (actionable, must not disappear on its own), with "Später" and "Herunterladen".
  2. Only on "Herunterladen": a save-location dialog (`getSaveLocation`) — **no** silently dropping it in
     `~/Downloads`, which triggers its own TCC prompt on macOS ("Zugriff auf den Ordner Downloads") that would be
     especially out of place for this app. The asset for the current platform is suggested
     (`selectAssetName`, `lib/utils/update_assets.dart`).
  3. Download, then a comparison against `SHA256SUMS` from the same release. **Only written after the check
     passes** — an unverified file must never sit in the target folder looking installable.
  4. Then a dialog with the platform-dependent next step and "Im Ordner zeigen".
     The app **doesn't execute the file** and doesn't replace itself: on Windows that would mean "start the
     installer" — launching a freshly downloaded executable file. The hint to **quit** FinanzGecko first appears
     once for all platforms in the dialog (previously worded per platform — and forgotten under Linux), mirrored
     in the update FAQ on `docs/index.html` including its JSON-LD copy.
  What the checksum proves and what it doesn't: `SHA256SUMS` arrives over HTTPS but is **not signed**. A match
  shows the file arrived unchanged and belongs to this release — it is **not** proof of authenticity. That comes,
  on macOS, from notarization, which the OS checks on launch anyway. UI text is worded accordingly as "geprüft",
  not "verifiziert/echt". If the release is missing the file for this platform or `SHA256SUMS` (older releases),
  **nothing is guessed** — `docs/download.html` opens instead.
- **`CHANGELOG.md`** is maintained exclusively by the `release` job in `release.yml`: on every actual release
  (tag push or version-bump dispatch, not on a plain test build with `bump: none`), a section with the commit
  messages since the previous tag gets prepended and pushed straight to `main`. Deliberately **no** separate
  push/PR workflow for this — that would water down the "single workflow" decision above.

## The update check, in detail

- The **200 MB asset ceiling** is a memory bound, not a policy: releases are ~20 MB, and the whole download is
  held in memory to be hashed before anything touches disk. Without the cap, an unbounded response is an OOM.
- `UpdateCheckStatus.unavailable` and `.failed` are deliberately **distinct states**. "No file for your system" is
  permanent and explainable (a platform build failed, or the release predates `SHA256SUMS`); network trouble is
  transient. Both fall back to the download page, but the wording differs — a user who is told "try again later"
  about a permanent condition tries again forever.
