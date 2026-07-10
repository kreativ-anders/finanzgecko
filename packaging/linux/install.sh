#!/usr/bin/env bash
# Installiert FinanzGecko für den aktuellen Benutzer als Desktop-Anwendung
# (Startmenü-Eintrag + Taskleisten-Icon unter Wayland/X11).
#
# Hintergrund: Neutralino setzt keine GTK-Application-ID, daher bestimmt
# argv[0] die Wayland-app_id/X11-WM_CLASS des Fensters. Ohne passende
# .desktop-Datei kann die Shell (GNOME/KDE) kein Icon zuordnen und zeigt
# ein generisches Fallback-Icon in der Taskleiste. Dieses Skript legt
# einen stabil benannten Symlink an ("finanzgecko"), installiert dazu
# eine .desktop-Datei mit passendem StartupWMClass sowie die Icons im
# hicolor-Theme.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$(uname -m)" in
  x86_64) bin_suffix="linux_x64" ;;
  aarch64) bin_suffix="linux_arm64" ;;
  armv7l|armhf) bin_suffix="linux_armhf" ;;
  *) echo "Nicht unterstützte Architektur: $(uname -m)" >&2; exit 1 ;;
esac

release_bin="$repo_dir/dist/finanzgecko/finanzgecko-$bin_suffix"
dev_bin="$repo_dir/bin/neutralino-$bin_suffix"

if [ -x "$release_bin" ]; then
  target_bin="$release_bin"
elif [ -x "$dev_bin" ]; then
  target_bin="$dev_bin"
else
  echo "Kein Binary gefunden. Erst 'neu update' oder 'neu build --release' ausführen." >&2
  exit 1
fi

bin_dir="$HOME/.local/bin"
app_dir="$HOME/.local/share/applications"
icon_theme_dir="$HOME/.local/share/icons/hicolor"

mkdir -p "$bin_dir" "$app_dir" "$icon_theme_dir/512x512/apps" "$icon_theme_dir/192x192/apps"

# Kein reiner Symlink: Neutralino sucht resources.neu/neutralino.config.json
# relativ zum Verzeichnis von argv[0], nicht relativ zum aufgelösten Symlink-
# Ziel. Ein Symlink nach ~/.local/bin würde also die Standard-Neutralino-
# Demo statt der App laden. Der Wrapper hält argv[0] = "finanzgecko" (für
# WM_CLASS) und übergibt den echten Ressourcen-Pfad explizit per --path.
target_dir="$(dirname "$target_bin")"
cat > "$bin_dir/finanzgecko" <<EOF
#!/usr/bin/env bash
exec -a finanzgecko "$target_bin" --path="$target_dir" "\$@"
EOF
chmod +x "$bin_dir/finanzgecko"
cp "$repo_dir/icons/icon-512.png" "$icon_theme_dir/512x512/apps/de.finanzgecko.app.png"
cp "$repo_dir/icons/icon-192.png" "$icon_theme_dir/192x192/apps/de.finanzgecko.app.png"

# Exec mit absolutem Pfad installieren, damit es unabhängig von PATH funktioniert.
sed "s|^Exec=finanzgecko\$|Exec=$bin_dir/finanzgecko|" \
  "$repo_dir/packaging/linux/de.finanzgecko.app.desktop" \
  > "$app_dir/de.finanzgecko.app.desktop"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$app_dir" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "$icon_theme_dir" >/dev/null 2>&1 || true

echo "Installiert: $target_bin"
echo "         ->  $bin_dir/finanzgecko"
echo "Desktop-Eintrag: $app_dir/de.finanzgecko.app.desktop"
echo
echo "Falls die App gerade läuft: einmal beenden und über das Startmenü neu starten,"
echo "damit die Taskleiste das neue Icon übernimmt."
