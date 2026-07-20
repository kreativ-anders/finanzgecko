# Dev-Setup

Flutter-Desktop-Builds sind **nicht cross-kompilierbar** — jede Plattform muss auf ihrem eigenen OS eingerichtet
werden.

## Linux (z. B. Ubuntu/Debian, TUXEDO OS)

```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

Kompiliert/linkt den nativen GTK-Runner — ohne diese Pakete bricht `flutter build linux` beim CMake-Schritt ab.

```bash
# Flutter SDK, Variante A: per snap
sudo snap install flutter --classic

# Variante B: manuell
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

flutter config --enable-linux-desktop
flutter doctor   # "Linux toolchain" muss ✓ zeigen
```

## Windows

```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
setx PATH "%PATH%;C:\src\flutter\bin"
```

`C:\src\flutter` statt eines Pfads unterm Nutzerprofil — Flutter hat Probleme mit Leerzeichen/OneDrive-Sync im Pfad.
Neues Terminal öffnen, damit `PATH` greift.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Workload "Desktop development with C++" — nötig für `flutter build windows` (MSBuild/CMake). Alternativ über den
[Visual Studio Installer](https://visualstudio.microsoft.com/downloads/).

```powershell
flutter config --enable-windows-desktop
flutter doctor   # "Visual Studio" muss ✓ zeigen
```

## macOS

Volles [Xcode](https://apps.apple.com/app/xcode/id497799835) aus dem App Store (nicht nur Command Line Tools —
Codesigning/Bundling brauchen die volle IDE), dann Lizenz akzeptieren:

```bash
sudo xcodebuild -license accept
```

```bash
# Flutter SDK, Variante A: per Homebrew
brew install --cask flutter

# Variante B: manuell
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

flutter config --enable-macos-desktop
flutter doctor
```

## Datenverzeichnis (zur Orientierung beim Debuggen)

| OS | Pfad |
|---|---|
| Linux | `~/.local/share/de.finanzgecko.app/` |
| macOS | `~/Library/Application Support/de.finanzgecko.app/` |
| Windows | `%APPDATA%\de.finanzgecko.app\` |

Details zu Verschlüsselung/Dateiformat: [architecture.md](architecture.md).
