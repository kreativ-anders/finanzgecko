#!/usr/bin/env bash
# Installs FinanzGecko as a proper desktop app on Linux (Wayland/X11):
# a stable symlink on PATH, a start-menu entry, and the app icon in the
# hicolor theme. Needed because a directly-launched Flutter Linux bundle has
# no desktop-file association, so the shell can't show a taskbar/dock icon
# for it (see README "Linux: als Desktop-Anwendung installieren").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BUNDLE_SRC="${1:-$REPO_ROOT/build/linux/x64/release/bundle}"

if [ ! -x "$BUNDLE_SRC/finanzgecko" ]; then
  echo "Fehler: $BUNDLE_SRC/finanzgecko nicht gefunden." >&2
  echo "Erst 'flutter build linux --release' ausfuehren, oder den Pfad zu einem" >&2
  echo "entpackten Release-Bundle als Argument uebergeben." >&2
  exit 1
fi

INSTALL_DIR="$HOME/.local/share/finanzgecko"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"

mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_BASE/512x512/apps" "$ICON_BASE/192x192/apps"

# The whole bundle directory (executable + data/ + lib/*.so) must move
# together — unlike the old single-file Neutralino binary, this is not one
# self-contained file.
rm -rf "$INSTALL_DIR"
cp -r "$BUNDLE_SRC" "$INSTALL_DIR"

ln -sf "$INSTALL_DIR/finanzgecko" "$BIN_DIR/finanzgecko"

cp "$REPO_ROOT/icons/icon-512.png" "$ICON_BASE/512x512/apps/de.finanzgecko.app.png"
cp "$REPO_ROOT/icons/icon-192.png" "$ICON_BASE/192x192/apps/de.finanzgecko.app.png"

cp "$SCRIPT_DIR/de.finanzgecko.app.desktop" "$DESKTOP_DIR/de.finanzgecko.app.desktop"

command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f "$ICON_BASE" || true

echo "Installiert nach $INSTALL_DIR."
echo "App ueber das Startmenue starten (Suche: FinanzGecko), nicht mehr direkt ueber build/."
