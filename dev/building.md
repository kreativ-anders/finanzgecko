# Bauen & Release

## Entwickeln

```bash
flutter pub get
flutter run -d windows   # oder: -d linux / -d macos
```

`-d` wählt explizit das Desktop-Target — nötig, sobald mehr als ein Gerät verfügbar ist.

## Release-Build

### Linux

```bash
flutter build linux --release
```

Ergebnis: `build/linux/x64/release/bundle/` — ein Ordner, kein Single-File-Binary (Executable braucht `data/` und
`lib/*.so` daneben). Direkt ausprobieren:

```bash
./build/linux/x64/release/bundle/finanzgecko
```

**Startmenü-/Taskleisten-Icon lokal registrieren:**

```bash
flutter build linux --release
./packaging/linux/install.sh
```

Kopiert das Bundle nach `~/.local/share/finanzgecko/`, legt Symlink, `.desktop`-Eintrag und Hicolor-Icons an. Danach
über das Startmenü starten, nicht mehr direkt aus `build/` (sonst fehlt WM_CLASS/`app_id` für die Icon-Zuordnung).

**Für die Weitergabe an Nutzer:** AppImage statt Bundle-Ordner.

```bash
flutter build linux --release
./packaging/linux/build_appimage.sh
```

Erzeugt `FinanzGecko-x86_64.AppImage` (CI setzt `OUT_FILE=FinanzGecko-<Version>-x86_64.AppImage`).

### macOS / Windows

Nicht cross-kompilierbar — jede Plattform baut nur auf ihrem eigenen OS.

```bash
flutter build macos --release     # auf einem Mac
flutter build windows --release   # unter Windows
```

`flutter build macos` erzeugt bereits ein fertiges `FinanzGecko.app` (Info.plist, Icon, Ad-hoc-Signatur) — kein
zusätzliches Packaging-Skript nötig. `flutter build windows` erzeugt einen Ordner
(`build/windows/x64/runner/Release/`), der komplett verteilt werden muss; die CI verpackt ihn mit Inno Setup
(`packaging/windows/finanzgecko.iss`) zu `FinanzGecko-<Version>-Setup.exe`.

```powershell
.\build\windows\x64\runner\Release\finanzgecko.exe
```

### Alle drei Plattformen (CI)

Lokal baut immer nur die eigene Plattform. Alle drei zusammen laufen ausschließlich über
`.github/workflows/release.yml` — ein nativer Runner pro OS (ubuntu/macos/windows-latest). Vor den Build-Jobs läuft
ein `gate`-Job (`flutter analyze` + `flutter test` + Icon-Pipeline); schlägt er fehl, wird nichts gebaut. Details
zum Anstoßen (Tag-Release vs. Ad-hoc-Testbuild): "Release-Prozess" unten.

## Icon-Pipeline

Ein Master speist alle Plattform-Icon-Formate:

- **Master:** `assets/icon/icon.png`, 1024×1024 PNG, quadratisch (kleiner = unscharfe macOS-Variante).
- **Generieren:**

  ```bash
  dart run tool/generate_icons.dart
  ```

  macOS läuft über `flutter_launcher_icons` (Config in `pubspec.yaml`). Windows-`.ico` (Multi-Size 16–256px) und
  Linux-Hicolor-PNGs generiert das Skript selbst (`generateWindowsIcon`/`generateLinuxIcons`) — bewusst nicht über
  `flutter_launcher_icons` für Windows, dessen Generator nur eine 256px-Größe schreibt und nach der Installation in
  Explorer/Taskleiste/Startmenü als fehlendes Icon endet.

Nach jedem Austausch von `icon.png` einmal ausführen und die generierten Dateien mitcommitten (kein Build-Schritt
erzeugt sie automatisch).

## Release-Prozess

1. Version in `pubspec.yaml` hochzählen, committen.
2. Tag pushen: `git tag v1.1.0 && git push origin v1.1.0`.
3. CI baut alle drei Pakete und lädt sie sowohl versioniert (`FinanzGecko-<Version>-…`) als auch als unversionierte
   Alias-Kopie (`FinanzGecko-Setup.exe`, `FinanzGecko-mac.app.zip`, `FinanzGecko-x86_64.AppImage`) hoch — darauf
   verlinkt `docs/download.html` fest über `.../releases/latest/download/<Alias>`, damit die Download-Seite ohne
   API-Aufruf immer auf die neueste Version zeigt.
4. `CHANGELOG.md` wird vom `release`-Job automatisch aus den Commit-Messages seit dem letzten Tag gepflegt — nicht
   von Hand editieren.

**Ad-hoc-Testbuild ohne Release:** *Actions → Release → Run workflow* (jeder Branch, kein Tag nötig) — baut
dieselben drei Pakete als Workflow-Artifacts, ohne GitHub-Release oder CHANGELOG-Update.
