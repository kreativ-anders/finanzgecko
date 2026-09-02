# Troubleshooting

**`flutter doctor`: "Linux toolchain" ✗ / `clang++` missing:**
`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev` (see [setup.md](setup.md)).

**App starts but shows no taskbar icon (Linux):** Expected for a bundle launched directly from `build/` — run
`./packaging/linux/install.sh` (see [building.md](building.md)).

**Windows: no icon in taskbar/title bar**, even after `dart run tool/generate_icons.dart` + rebuild: usually not
the `.ico` itself but a stale shortcut left behind by `local_notifier`, which the app used until the switch to
`flutter_local_notifications`. That plugin registered an AUMID plus a start-menu shortcut on first run
(`%APPDATA%\Microsoft\Windows\Start Menu\Programs\FinanzGecko.lnk`); if it points at a path that's since been
deleted/moved, the taskbar stays blank for every later build, regardless of how correct its `.ico` is. Nothing
writes that shortcut any more, so a fresh machine can't hit this — but an old one still carries the file. Fix:
quit `finanzgecko.exe`, delete the `.lnk` file, restart the app.

**`flutter build windows` fails with a CMake/MSBuild error:** the "Desktop development with C++" workload is
missing, see [setup.md](setup.md).

**`flutter doctor` fails on Windows with `PathNotFoundException` at an `AndroidStudioXXXX.X\.home` path:** known
Flutter behavior from a stale AppData leftover of an uninstalled/updated Android Studio version. Irrelevant to this
app (no Android target) — ignore it or delete the folder under `%LOCALAPPDATA%\Google\`.

**macOS: crashes on first launch with `PlatformException(..., -34018, "A required entitlement isn't present.")`:**
See [architecture.md](architecture.md#why-no-database-engine) — the fix is
`MacOsOptions(usesDataProtectionKeychain: false)` in `lib/data/secure_key_store.dart`. Only happens if that
parameter gets accidentally removed.

**Exchange-rate lookup fails / "offline":** not a bug — the deliberate offline fallback. When entering a balance or
subscription in a foreign currency without network access and no cached rate, the app asks for a manually entered
rate instead.

## Known limitations

- **No background auto-updater.** *Einstellungen → Nach Updates suchen* downloads the artifact for this platform
  and verifies it against the published `SHA256SUMS`, but only when you ask for it — the app never checks on its
  own. Installing it is still a manual step (re-run the Windows installer, replace the Linux AppImage, drag the
  macOS app out of the new DMG). The data directory depends only on the data path, not the install location —
  existing user data stays untouched.
- **First launch on Windows:** the installer is unsigned, so SmartScreen shows a warning — "More info" → "Run
  anyway". A certificate costs money every year and, unlike on macOS, would not remove the warning outright (see
  [ROADMAP.md](../ROADMAP.md)). macOS releases are signed with a Developer ID and notarized, so they start without
  a prompt; only a locally built `.app` is ad-hoc signed and thus valid solely on the machine that built it.

## Upgrading vs. moving to a new device

**Upgrading in place is easy going:** install the new release and start it — your existing data file is picked up
automatically. If the release bumped the data schema, it migrates forward on first launch by itself (with an
automatic safety backup); see [architecture.md](architecture.md#schema-migration-on-startup). No manual
export/import needed.

**Export/Import is for moving to a new device (or as an extra manual backup):** old machine → *Einstellungen →
Backup exportieren…*, new machine → *Backup importieren…* (same schema/field names either way). Import also
validates the schema version and rejects a backup from a newer app version instead of reading it incompletely.

## Recovering when someone reset or imported without ever exporting first

Support scenario, not something to point a user at directly — the app deliberately never surfaces these
filenames or shows a selectable data path. Before every reset and every import, `AppStore` writes an encrypted
`pre-reset-backup-<timestamp>.json` resp. `pre-import-backup-<timestamp>.json` snapshot of the state that's
about to be replaced (`_writeSnapshotBackup`, see [persistence.md](ai/persistence.md)). If someone reset
the app or imported over their data without ever having exported, this is the only way back — walk them through
it yourself:

1. **Quit FinanzGecko** on their machine first — a running instance will overwrite whatever you place there on
   its next save.
2. **Open the data directory** for their OS (table above). On sandboxed macOS this is
   `~/Library/Containers/de.finanzgecko.app/Data/Library/Application Support/FinanzGecko/`.
3. **Find the newest matching snapshot** — sort by the timestamp in the filename (ISO-8601, so the
   lexicographically largest is the most recent) and pick `pre-reset-backup-*` or `pre-import-backup-*`
   depending on which action they want undone. Only the newest 10 of each survive automatic pruning
   (`_maxSnapshotsPerLabel`), so check there's a recent enough one before promising anything.
4. **Move the current main file aside first**, don't delete it — rename `finanzgecko-data.json` (or
   `finanzgecko-data-appstore.json` on the Mac App Store build) to something like `finanzgecko-data.broken.json`,
   in case the snapshot turns out to be the wrong one.
5. **Rename the chosen snapshot file to the exact main filename** their build reads —
   `finanzgecko-data.json` or `finanzgecko-data-appstore.json`, matching step 4.
6. **Relaunch the app.** It reads the renamed file through the normal startup path (`ensureInitialized()`),
   decrypts it with the same OS-keychain key that wrote it, and opens as if nothing happened.

This only works **on the same device and the same delivery channel** that produced the snapshot — the
AES-256-GCM key never leaves that machine's OS credential store, so the file is unreadable anywhere else,
including by you. There's no way to import a snapshot through the in-app *Backup importieren…* dialog: it isn't
an export (no `schemaVersion`, wrong structure) and `AppStore.importAllData()` rejects it outright — this has to
be a manual file swap.
