#!/usr/bin/env bash
# Packt das Flutter-Linux-Bundle (Executable + data/ + lib/*.so) in ein
# einzelnes, ausführbares AppImage. Damit bekommen Testnutzer EINE Datei
# (FinanzGecko-x86_64.AppImage) statt eines Ordners voller loser Dateien, die
# beim Löschen einzelner Teile den Start brechen: `chmod +x` (bei Downloads
# meist schon gesetzt), Doppelklick, läuft — ohne Entpacken, ohne Installation.
#
# Aufruf (siehe .github/workflows/release.yml, Job "linux"):
#   ./packaging/linux/build_appimage.sh
# Optional: Pfad zu einem entpackten Bundle als $1 (Default: der build/-Pfad).
#
# Benötigt appimagetool im PATH oder lädt es bei Bedarf nach $TMPDIR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BUNDLE_SRC="${1:-$REPO_ROOT/build/linux/x64/release/bundle}"
OUT_FILE="${OUT_FILE:-$REPO_ROOT/FinanzGecko-x86_64.AppImage}"

if [ ! -x "$BUNDLE_SRC/finanzgecko" ]; then
  echo "Fehler: $BUNDLE_SRC/finanzgecko nicht gefunden." >&2
  echo "Erst 'flutter build linux --release' ausfuehren, oder den Pfad zu einem" >&2
  echo "entpackten Release-Bundle als Argument uebergeben." >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APPDIR="$WORK/FinanzGecko.AppDir"

# AppDir-Layout: das komplette Bundle nach usr/bin (muss zusammenbleiben),
# AppRun als Starter, .desktop + Icon im Wurzelverzeichnis (von appimagetool
# erwartet).
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE_SRC/." "$APPDIR/usr/bin/"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/finanzgecko" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# .desktop fürs AppImage: Exec/Icon ohne Pfad, Namen wie in packaging/linux.
cat > "$APPDIR/de.finanzgecko.app.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=FinanzGecko
Comment=Nativer Vermögenstracker – lokal, ohne Cloud
Exec=finanzgecko
Icon=de.finanzgecko.app
Terminal=false
Categories=Office;Finance;
StartupWMClass=de.finanzgecko.app
EOF

cp "$REPO_ROOT/icons/icon-512.png" "$APPDIR/de.finanzgecko.app.png"

# appimagetool beschaffen (falls nicht im PATH).
if command -v appimagetool >/dev/null 2>&1; then
  APPIMAGETOOL="appimagetool"
else
  APPIMAGETOOL="$WORK/appimagetool"
  curl -fsSL -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

# APPIMAGE_EXTRACT_AND_RUN=1: umgeht FUSE, das auf CI-Runnern oft fehlt.
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=x86_64
"$APPIMAGETOOL" "$APPDIR" "$OUT_FILE"

echo "AppImage erstellt: $OUT_FILE"
