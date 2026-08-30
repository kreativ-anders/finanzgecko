#!/usr/bin/env bash
# Packt FinanzGecko.app in ein DMG und signiert/notarisiert es, soweit die
# nötigen Zugangsdaten vorhanden sind. Ein einziges Skript für lokal und CI
# (siehe .github/workflows/release.yml, Job "macos") — damit der Build, den
# man von Hand testet, exakt derselbe ist, den die CI später ausführt.
#
# Aufruf:
#   ./packaging/macos/build_dmg.sh                 # nutzt build/macos/...
#   ./packaging/macos/build_dmg.sh /pfad/zur.app   # oder ein fertiges Bundle
#
# Umgebungsvariablen (alle optional):
#   OUT_FILE             Zieldatei (Default: FinanzGecko-mac.dmg im Repo-Root);
#                        die CI setzt hier FinanzGecko-<Version>-mac.dmg.
#   SIGN_IDENTITY        Signatur-Identität, Default "Developer ID Application"
#                        — codesign löst Teilstrings auf, solange genau eine
#                        passende Identität im Schlüsselbund liegt. Deshalb
#                        steht hier bewusst KEIN Name und keine Team-ID.
#   ENTITLEMENTS         Default macos/Runner/Release.entitlements
#   NOTARY_PROFILE       Name eines via `xcrun notarytool store-credentials`
#                        hinterlegten Profils (der lokale Weg).
#   APPLE_API_KEY_PATH   .p8-Datei  ┐ der CI-Weg (App-Store-Connect-API-Key);
#   APPLE_API_KEY_ID     Key ID     ├ wird nur benutzt, wenn NOTARY_PROFILE
#   APPLE_API_ISSUER_ID  Issuer ID  ┘ nicht gesetzt ist.
#   SKIP_NOTARIZE=1      Nur signieren, nicht notarisieren (schneller Testlauf).
#
# Das Skript signiert eine KOPIE der App und lässt build/ unangetastet — siehe
# den Block "Auf einer Kopie arbeiten" unten. Wer das signierte Bundle selbst
# braucht, holt es aus dem fertigen DMG.
#
# **Fehlt die Signatur-Identität oder fehlen die Notarisierungs-Daten, bricht
# das Skript NICHT ab, sondern baut ein unsigniertes DMG und sagt das laut.**
# Das ist Absicht: Forks und Ad-hoc-Testbuilds haben keine Secrets, und ein
# harter Fehler würde dort die gesamte (atomare) Release-Kette blockieren.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP="${1:-$REPO_ROOT/build/macos/Build/Products/Release/FinanzGecko.app}"
OUT_FILE="${OUT_FILE:-$REPO_ROOT/FinanzGecko-mac.dmg}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
ENTITLEMENTS="${ENTITLEMENTS:-$REPO_ROOT/macos/Runner/Release.entitlements}"

if [ ! -d "$APP" ]; then
  echo "Fehler: $APP nicht gefunden." >&2
  echo "Erst 'flutter build macos --release' ausfuehren, oder den Pfad zu" >&2
  echo "einem fertigen .app-Bundle als Argument uebergeben." >&2
  exit 1
fi

# ------------------------------------------------- Auf einer Kopie arbeiten --
#
# NICHT wegoptimieren: das Skript signiert bewusst eine Kopie und fasst das
# Original in build/ nicht an.
#
# Grund ist der App-Management-Schutz von macOS (ab Sonoma): ein *signiertes*
# App-Bundle darf von anderen Prozessen nicht mehr verändert werden. Signierte
# man direkt in build/macos/.../FinanzGecko.app, dann scheiterte der NÄCHSTE
# `flutter build macos` daran, seine Plugin-Bundles in genau dieses Bundle zu
# kopieren — mit einer Fehlerwand aus
#   "You don't have permission to save the file ... in the folder Resources"
# und anschließend "xattr: [Errno 1] Operation not permitted" für jede Datei.
# Die Meldung deutet auf ein Rechteproblem am Repo hin und schickt einen in die
# völlig falsche Richtung; die Ursache ist allein die Signatur von vorhin.
#
# Mit der Kopie bleibt das Build-Verzeichnis unsigniert und unverändert, der
# nächste Build läuft ohne `rm -rf build/macos` durch, und ein versehentlich
# zweimal ausgeführtes Skript signiert nie ein bereits signiertes Bundle.
WORK="$(mktemp -d)"
STAGING=""
cleanup() { rm -rf "$WORK" ${STAGING:+"$STAGING"}; }
trap cleanup EXIT

ditto "$APP" "$WORK/FinanzGecko.app"
APP="$WORK/FinanzGecko.app"

# ---------------------------------------------------------------- Signieren --

CAN_SIGN=0
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
  CAN_SIGN=1
else
  echo "WARNUNG: keine Identität '$SIGN_IDENTITY' im Schlüsselbund —" >&2
  echo "         das DMG bleibt UNSIGNIERT (Gatekeeper warnt beim Start)." >&2
fi

# Wiederholt einen Befehl mit wachsender Pause.
#
# Grund (nicht wegoptimieren): `--timestamp` ist pro Signatur ein Netzaufruf
# an Apples Zeitstempel-Dienst, und der antwortet gelegentlich nicht. codesign
# meldet das als nichtssagendes "errSecInternalComponent" und bricht ab —
# derselbe Aufruf läuft Sekunden später unverändert durch. Weil hier mehrere
# Signaturen direkt hintereinander angefordert werden, trifft es typischerweise
# die erste. Ohne diesen Retry wäre das in der CI ein fehlgeschlagenes Release
# mit einer Fehlermeldung, die auf nichts hindeutet.
retry() {
  local attempt=1
  local max=5
  while true; do
    if "$@"; then
      return 0
    fi
    if [ "$attempt" -ge "$max" ]; then
      echo "Fehler: '$1' nach $max Versuchen fehlgeschlagen." >&2
      return 1
    fi
    echo "Versuch $attempt fehlgeschlagen, neuer Versuch in $((attempt * 5))s ..." >&2
    sleep $((attempt * 5))
    attempt=$((attempt + 1))
  done
}

sign_one() {
  # --options runtime = Hardened Runtime, Pflicht für die Notarisierung.
  # --timestamp = signierter Zeitstempel von Apple, damit die Signatur das
  # Ablaufdatum des Zertifikats überlebt.
  retry codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"
}

if [ "$CAN_SIGN" = 1 ]; then
  # Extended Attributes (u. a. com.apple.quarantine, Finder-Metadaten) lassen
  # codesign sonst mit "resource fork, Finder information, or similar detritus
  # not allowed" scheitern.
  xattr -cr "$APP"

  # Inside-out signieren: erst jede eingebettete Bibliothek, dann jedes
  # Framework als Ganzes, zuletzt das App-Bundle. Bewusst NICHT `--deep` —
  # das ist von Apple ausdrücklich nicht für Distribution vorgesehen und
  # würde die Entitlements auf die eingebetteten Teile mit anwenden.
  if [ -d "$APP/Contents/Frameworks" ]; then
    while IFS= read -r -d '' lib; do
      sign_one "$lib"
    done < <(find "$APP/Contents/Frameworks" -type f -name "*.dylib" -print0)

    while IFS= read -r -d '' fw; do
      sign_one "$fw"
    done < <(find "$APP/Contents/Frameworks" -mindepth 1 -maxdepth 1 -print0)
  fi

  # Nur das äußere Bundle bekommt die Entitlements.
  sign_one --entitlements "$ENTITLEMENTS" "$APP"

  codesign --verify --strict --verbose=2 "$APP"
  echo "App signiert: $APP"
fi

# ------------------------------------------------------------ Notarisieren --

NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${APPLE_API_KEY_PATH:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER_ID:-}" ]; then
  NOTARY_ARGS=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
fi

CAN_NOTARIZE=0
if [ "$CAN_SIGN" = 1 ] && [ "${SKIP_NOTARIZE:-0}" != "1" ] && [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
  CAN_NOTARIZE=1
elif [ "$CAN_SIGN" = 1 ] && [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
  echo "WARNUNG: keine Notarisierungs-Zugangsdaten (NOTARY_PROFILE oder" >&2
  echo "         APPLE_API_KEY_*) — signiert, aber NICHT notarisiert." >&2
fi

notarize() {
  # --wait: blockiert bis Apple fertig ist (üblicherweise 1-5 Minuten). Ohne
  # das müsste man die Submission-ID pollen; im CI-Log wäre der Fehlerfall
  # dann nicht mehr dem Build zuzuordnen.
  xcrun notarytool submit "$1" "${NOTARY_ARGS[@]}" --wait
}

# Zweimal notarisieren ist Absicht, nicht doppelt gemoppelt: das Ticket wird
# einmal IN die App und einmal in das DMG geheftet. Nur das DMG zu stapeln
# genügt nicht — sobald die App herausgezogen ist, trägt sie selbst kein
# Ticket mehr und Gatekeeper müsste beim ersten Start online bei Apple
# nachfragen. Genau das soll der DMG-Weg ja vermeiden (siehe dev/ai/platform.md).
if [ "$CAN_NOTARIZE" = 1 ]; then
  ZIP="$(mktemp -d)/FinanzGecko.zip"
  # ditto statt zip: erhält Resource-Forks/Extended-Attributes.
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  xcrun stapler staple "$APP"
  rm -rf "$(dirname "$ZIP")"
  echo "App notarisiert und gestapelt."
fi

# -------------------------------------------------------------- DMG bauen --

STAGING="$(mktemp -d)"  # wird von cleanup() oben mit aufgeräumt

ditto "$APP" "$STAGING/FinanzGecko.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$OUT_FILE"
hdiutil create -volname FinanzGecko -srcfolder "$STAGING" -ov -format UDZO "$OUT_FILE"

if [ "$CAN_SIGN" = 1 ]; then
  # Ohne --options runtime: Hardened Runtime ist eine Eigenschaft des
  # laufenden Programms, das DMG ist nur der Container.
  retry codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUT_FILE"
fi

if [ "$CAN_NOTARIZE" = 1 ]; then
  notarize "$OUT_FILE"
  xcrun stapler staple "$OUT_FILE"

  # Das ist die Prüfung, die zählt: "source=Notarized Developer ID" heißt,
  # dass Gatekeeper das Image ohne Rückfrage akzeptiert.
  spctl -a -t open --context context:primary-signature -vv "$OUT_FILE"
fi

echo "DMG erstellt: $OUT_FILE"
