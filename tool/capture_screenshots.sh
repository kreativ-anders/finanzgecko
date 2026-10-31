#!/usr/bin/env bash
# Captures the FinanzGecko window at native Retina resolution for the docs website.
#
#   tool/capture_screenshots.sh dark
#   tool/capture_screenshots.sh light
#   tool/capture_screenshots.sh dark <slug>...   # captures these slugs at once, no prompt
#
# Run once per theme (Einstellungen → Erscheinungsbild → Hell/Dunkel). The script
# prompts for each view; navigate the app, then press Enter to capture. Output lands
# in build/screenshots/<theme>/ as full-resolution PNGs — cropping, webp conversion
# and the docs wiring happen afterwards.
#
# Uses screencapture -l <windowid>, so only the app window is captured: no desktop,
# no menu bar, no cursor, and no window shadow (-o).

set -euo pipefail

THEME="${1:-}"
if [[ "$THEME" != "light" && "$THEME" != "dark" ]]; then
  echo "Usage: $0 light|dark" >&2
  exit 1
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO/build/screenshots/$THEME"
mkdir -p "$OUT"

find_window_id() {
  # INFO: Swift, not python3 + Quartz — macOS 27's system Python no longer ships PyObjC.
  swift - <<'SWIFT'
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
// Layer 0 skips Flutter's helper windows; the largest one is the main window (the menu-bar strips are 30 px high).
let main = windows
  .filter { $0["kCGWindowOwnerName"] as? String == "FinanzGecko" && $0["kCGWindowLayer"] as? Int == 0 }
  .max { a, b in
    func area(_ w: [String: Any]) -> Double {
      let r = w["kCGWindowBounds"] as? [String: Double] ?? [:]
      return (r["Width"] ?? 0) * (r["Height"] ?? 0)
    }
    return area(a) < area(b)
  }
guard let id = main?["kCGWindowNumber"] as? Int else {
  FileHandle.standardError.write("FinanzGecko window not found — is the app running and unminimised?\n".data(using: .utf8)!)
  exit(1)
}
print(id)
SWIFT
}

# name|what to put on screen before pressing Enter
SHOTS=(
  "finanzgecko-gesamtvermoegen-verlauf-prognose|Dashboard, oben — Gesamtvermögen + Verlauf/Prognose sichtbar"
  "finanzgecko-verteilung-nach-kontotyp-kennzahlen|Dashboard, gescrollt — Kartenreihe Verteilung / Fixposten / Vermögenswerte"
  "finanzgecko-vermoegen-zusammensetzung-ueber-zeit|Dashboard, gescrollt — Zusammensetzung über Zeit (gestapelt)"
  "finanzgecko-kontostaende-monatlich-erfassen|Einträge — Kontostände des Monats"
  "finanzgecko-fixposten-einnahmen-ausgaben|Fixposten — Einnahmen und Ausgaben"
  "finanzgecko-vermoegenswerte-sachwerte|Vermögenswerte — Sachwerte"
  "finanzgecko-konten-uebersicht|Konten — Übersicht aller Konten"
)

echo "Theme: $THEME  →  $OUT"
echo "Stelle sicher, dass die Demodaten geladen sind und das Fenster die gewohnte Breite hat."
echo

ONLY=("${@:2}")

for entry in "${SHOTS[@]}"; do
  name="${entry%%|*}"
  hint="${entry#*|}"

  if (( ${#ONLY[@]} )); then
    [[ " ${ONLY[*]} " == *" $name "* ]] || continue
    printf '  %s\n' "$name"
  else
    printf '  %s\n    %s\n    [Enter] zum Aufnehmen, [s] zum Überspringen: ' "$name" "$hint"
    read -r answer </dev/tty
    [[ "$answer" == "s" ]] && { echo "    übersprungen"; continue; }
  fi

  id="$(find_window_id)"
  # -o: kein Fensterschatten, -x: kein Kamera-Sound, -t png: verlustfrei
  screencapture -o -x -t png -l "$id" "$OUT/$name.png"
  printf '    ✓ %s\n\n' "$(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/ {printf "%s ", $2}')"
done

echo "Fertig. $(ls -1 "$OUT" | wc -l | tr -d ' ') Aufnahmen in $OUT"
