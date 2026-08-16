#!/usr/bin/env bash
# Füllt die winget-Manifest-Vorlagen neben diesem Skript mit Version,
# Prüfsumme und Datum und legt sie im Layout ab, das winget-pkgs erwartet.
#
# Nur für die ERSTE Einreichung nötig. Danach übernimmt der Job "winget" in
# .github/workflows/release.yml die Aktualisierung automatisch.
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

RELEASE_DATE="$(date -u +%Y-%m-%d)"
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
