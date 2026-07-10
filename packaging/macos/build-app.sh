#!/usr/bin/env bash
# Baut ein echtes macOS-App-Bundle (Contents/MacOS + Contents/Resources +
# Info.plist + .icns) aus dem von `neu build --release` erzeugten rohen
# Mach-O-Binary.
#
# Hintergrund: `neu build --macos-bundle` erzeugt *kein* echtes App-Bundle,
# sondern hängt nur die Endung ".app" an die rohe Binary-Datei an (siehe
# neutralinojs-cli/src/modules/bundler.js). Ohne Contents/Info.plist und
# Contents/Resources/icon.icns zeigt Finder weder ein eigenes Dock-Icon noch
# behandelt er die Datei als richtiges Bundle. Dieses Skript baut die
# Bundle-Struktur von Hand zusammen.
#
# Muss auf einem Mac laufen (nutzt die Apple-Tools sips/iconutil).
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
arch="${1:-universal}"

if [ "$(uname)" != "Darwin" ]; then
  echo "Dieses Skript muss auf macOS laufen (benötigt sips/iconutil)." >&2
  exit 1
fi

case "$arch" in
  x64|arm64|universal) ;;
  *) echo "Unbekannte Architektur: $arch (erlaubt: x64, arm64, universal)" >&2; exit 1 ;;
esac

# Sehr simpler Extraktor für einzeilige "key": "value"-Einträge -- reicht für
# das Format von neutralino.config.json, ohne eine jq-Abhängigkeit einzuführen.
read_config() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" \
    "$repo_dir/neutralino.config.json" | head -n1
}

app_id="$(read_config applicationId)"
app_name="$(read_config applicationName)"
app_version="$(read_config version)"
binary_name="$(sed -n 's/.*"binaryName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$repo_dir/neutralino.config.json" | head -n1)"

: "${app_id:?applicationId fehlt in neutralino.config.json}"
: "${app_name:=$binary_name}"
: "${app_version:=1.0.0}"
: "${binary_name:?cli.binaryName fehlt in neutralino.config.json}"

src_binary="$repo_dir/dist/$binary_name/$binary_name-mac_$arch"
if [ ! -f "$src_binary" ]; then
  echo "Kein Build gefunden: $src_binary" >&2
  echo "Erst 'neu build --release' ausführen." >&2
  exit 1
fi

resources_neu="$repo_dir/dist/$binary_name/resources.neu"
if [ ! -f "$resources_neu" ]; then
  echo "resources.neu fehlt in $repo_dir/dist/$binary_name/ -- 'neu build --release' erneut ausführen." >&2
  exit 1
fi

app_dir="$repo_dir/dist/$binary_name/$app_name.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

echo "Baue $app_name.app ($arch)..."
rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"

cp "$src_binary" "$macos_dir/$binary_name"
chmod +x "$macos_dir/$binary_name"
# Neutralino sucht resources.neu relativ zum Verzeichnis der Binary (argv[0]),
# nicht relativ zum Bundle-Root -- deshalb landet sie in Contents/MacOS/.
cp "$resources_neu" "$macos_dir/resources.neu"

# .icns aus dem größten vorhandenen PNG erzeugen (source: icons/icon-512.png).
icon_png="$repo_dir/icons/icon-512.png"
iconset_dir="$(mktemp -d)/icon.iconset"
mkdir -p "$iconset_dir"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$icon_png" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$icon_png" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$resources_dir/icon.icns"
rm -rf "$(dirname "$iconset_dir")"

cat > "$contents_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$app_name</string>
  <key>CFBundleDisplayName</key>
  <string>$app_name</string>
  <key>CFBundleIdentifier</key>
  <string>$app_id</string>
  <key>CFBundleVersion</key>
  <string>$app_version</string>
  <key>CFBundleShortVersionString</key>
  <string>$app_version</string>
  <key>CFBundleExecutable</key>
  <string>$binary_name</string>
  <key>CFBundleIconFile</key>
  <string>icon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>$(read_config copyright)</string>
</dict>
</plist>
PLIST

# Ad-hoc-Signatur (kein Apple-Zertifikat nötig): auf Apple Silicon verlangt
# macOS eine Signatur, damit die App überhaupt startet ("--sign -" reicht
# dafür aus). Ersetzt keine echte Signierung/Notarisierung -- Gatekeeper
# zeigt beim allerersten Start weiterhin die "nicht verifizierter
# Entwickler"-Warnung (siehe README, per Rechtsklick -> Öffnen bestätigen).
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$app_dir"
fi

echo "Fertig: $app_dir"
