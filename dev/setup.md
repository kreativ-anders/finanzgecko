# Dev Setup

Flutter desktop builds are **not cross-compilable** — each platform must be set up on its own OS.

## Linux (e.g. Ubuntu/Debian, TUXEDO OS)

```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

Compiles/links the native GTK runner — without these packages `flutter build linux` fails at the CMake step.

```bash
# Flutter SDK, option A: via snap
sudo snap install flutter --classic

# Option B: manual
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

flutter config --enable-linux-desktop
flutter doctor   # "Linux toolchain" must show a checkmark
```

## Windows

```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
setx PATH "%PATH%;C:\src\flutter\bin"
```

Use `C:\src\flutter` instead of a path under the user profile — Flutter has issues with spaces/OneDrive sync in the
path. Open a new terminal afterward so `PATH` takes effect.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Workload "Desktop development with C++" — required for `flutter build windows` (MSBuild/CMake). Alternatively via
the [Visual Studio Installer](https://visualstudio.microsoft.com/downloads/).

```powershell
flutter config --enable-windows-desktop
flutter doctor   # "Visual Studio" must show a checkmark
```

## macOS

Full [Xcode](https://apps.apple.com/app/xcode/id497799835) from the App Store (not just the Command Line Tools —
codesigning/bundling need the full IDE), then accept the license:

```bash
sudo xcodebuild -license accept
```

```bash
# Flutter SDK, option A: via Homebrew
brew install --cask flutter

# Option B: manual
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

flutter config --enable-macos-desktop
flutter doctor
```

## Data directory (for debugging orientation)

| OS | Path |
|---|---|
| Linux | `~/.local/share/de.finanzgecko.app/` |
| macOS | `~/Library/Application Support/de.finanzgecko.app/` |
| Windows | `%APPDATA%\de.finanzgecko.app\` |

Encryption/file format details: [architecture.md](architecture.md).
