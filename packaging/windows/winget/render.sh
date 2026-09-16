#!/usr/bin/env bash
# Füllt die winget-Manifest-Vorlagen neben diesem Skript mit Version,
# Prüfsumme und Datum und legt sie im Layout ab, das winget-pkgs erwartet.
#
# Nur für die ERSTE Einreichung nötig. Danach übernimmt der Job "winget" in
# .github/workflows/release.yml die Aktualisierung automatisch.
#
# TODO: delete this script and the four templates next to it once winget-pkgs PR
# #417767 is merged — from then on `wingetcreate update` in release.yml carries
# the published manifest forward and these templates can only drift from it.
#
# Aufruf:
#   ./packaging/windows/winget/render.sh 1.8.0 [ausgabeverzeichnis]
#
# Die Prüfsumme wird aus der SHA256SUMS-Datei des Releases geholt, nicht neu
# berechnet: damit steht im Manifest genau der Wert, den auch die Website und
# die In-App-Update-Prüfung verwenden — eine Abweichung wäre sonst erst beim
# Nutzer sichtbar.
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Aufruf: $0 <version> [ausgabeverzeichnis]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${2:-$SCRIPT_DIR/out/manifests/k/KreativAnders/FinanzGecko/$VERSION}"
ASSET="FinanzGecko-${VERSION}-Setup.exe"
BASE_URL="https://github.com/kreativ-anders/finanzgecko/releases/download/v${VERSION}"

echo "Hole Prüfsumme für $ASSET ..."
SHA256="$(curl -fsSL "${BASE_URL}/SHA256SUMS" | grep -F "$ASSET" | awk '{print toupper($1)}')"
if [ -z "$SHA256" ]; then
  echo "Fehler: $ASSET steht nicht in SHA256SUMS von v${VERSION}." >&2
  exit 1
fi

# Datum der Veröffentlichung, nicht des Einreichens (README): ein später
# nachgereichtes Manifest trüge sonst ein Datum, an dem nichts erschienen ist.
RELEASE_DATE="$(curl -fsSL "https://api.github.com/repos/kreativ-anders/finanzgecko/releases/tags/v${VERSION}" \
  | sed -nE 's/.*"published_at" *: *"([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' | head -1)"
if [ -z "$RELEASE_DATE" ]; then
  echo "Fehler: Veröffentlichungsdatum von v${VERSION} nicht ermittelbar." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

for template in "$SCRIPT_DIR"/KreativAnders.FinanzGecko*.yaml; do
  name="$(basename "$template")"
  sed -e "s/__VERSION__/$VERSION/g" \
      -e "s/__SHA256__/$SHA256/g" \
      -e "s/__RELEASE_DATE__/$RELEASE_DATE/g" \
      "$template" > "$OUT_DIR/$name"
done

echo "Manifeste geschrieben nach: $OUT_DIR"
echo
echo "Prüfen und einreichen:"
echo "  winget validate --manifest \"$OUT_DIR\""
echo "  winget install --manifest \"$OUT_DIR\"    # lokaler Testlauf"
echo "  wingetcreate submit --token <GitHub-PAT> \"$OUT_DIR\""
