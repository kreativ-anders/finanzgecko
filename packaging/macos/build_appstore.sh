#!/usr/bin/env bash
# Baut FinanzGecko für den Mac App Store: sandboxed, signiert mit den
# "3rd Party Mac Developer"-Zertifikaten, verpackt als .pkg zum Upload nach
# App Store Connect.
#
# Das ist bewusst ein ZWEITES Skript neben build_dmg.sh und kein Schalter darin.
# Die beiden Builds unterscheiden sich in Sandbox, Keychain-Variante, Signatur-
# Zertifikat, Verpackung und Update-Weg — praktisch alles außer dem Dart-Code.
# Ein gemeinsames Skript mit fünf `if`-Zweigen wäre schwerer zu lesen als zwei
# kurze, und der DMG-Weg ist der, der nicht kaputtgehen darf.
#
# WICHTIG — die beiden Builds teilen sich keine Daten:
#   Der sandboxed Build sieht $HOME als ~/Library/Containers/de.finanzgecko.app/
#   Data. Wer die DMG-Version benutzt und die App-Store-Version installiert,
#   startet dort mit einer leeren Datenbank. Das ist kein Bug, sondern der Grund,
#   warum die DMG-Version unsandboxed bleibt statt umgestellt zu werden: es gibt
#   keinen Migrationspfad, der ohne Datenverlust auskommt. Der Weg von der einen
#   zur anderen Version führt über "Backup exportieren…" und "Backup
#   importieren…" — siehe AI_MASTER §4.1.
#
# Aufruf:
#   ./packaging/macos/build_appstore.sh              # baut selbst
#   ./packaging/macos/build_appstore.sh /pfad/zur.app
#
# Umgebungsvariablen:
#   TEAM_ID              (Pflicht) die zehnstellige Apple-Team-ID. Wird in die
#                        keychain-access-groups eingesetzt; ohne sie schlägt der
#                        Zugriff auf die Data-Protection-Keychain zur Laufzeit
#                        mit -34018 fehl — und zwar erst beim Nutzer, nicht hier.
#   PROVISION_PROFILE    (Pflicht für den Upload) .provisionprofile aus dem
#                        Developer-Portal, Typ "Mac App Store". Wird als
#                        Contents/embedded.provisionprofile eingebettet.
#   APP_SIGN_IDENTITY    Default "3rd Party Mac Developer Application"
#   PKG_SIGN_IDENTITY    Default "3rd Party Mac Developer Installer"
#   OUT_FILE             Default FinanzGecko-mac-appstore.pkg im Repo-Root
#   SKIP_BUILD=1         Ein bereits gebautes Bundle verwenden.
#
# Anders als build_dmg.sh bricht dieses Skript bei fehlender Signatur HART ab.
# Dort ist ein unsigniertes Ergebnis brauchbar (Forks, Testbuilds); hier wäre
# es das nie — ein .pkg ohne die richtigen Zertifikate lehnt App Store Connect
# im Upload ab, und zwar mit einer Meldung, die auf etwas anderes hindeutet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP="${1:-$REPO_ROOT/build/macos/Build/Products/Release/FinanzGecko.app}"
OUT_FILE="${OUT_FILE:-$REPO_ROOT/FinanzGecko-mac-appstore.pkg}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-3rd Party Mac Developer Application}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-3rd Party Mac Developer Installer}"
ENTITLEMENTS_TEMPLATE="$REPO_ROOT/macos/Runner/AppStore.entitlements"

die() { echo "Fehler: $*" >&2; exit 1; }

[ -n "${TEAM_ID:-}" ] || die "TEAM_ID ist nicht gesetzt (zehnstellige Apple-Team-ID)."

# ----------------------------------------------------------------- Bauen --

# --dart-define setzt kIsMacAppStore (lib/constants.dart). Ohne das baut man
# äußerlich eine App-Store-App, die intern noch die Legacy-Keychain benutzt und
# den Update-Download enthält: startet nicht bzw. fliegt im Review raus.
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  ( cd "$REPO_ROOT" && flutter build macos --release --dart-define=FINANZGECKO_MAS=true )
fi

[ -d "$APP" ] || die "$APP nicht gefunden."

# Auf einer Kopie arbeiten: sonst trägt das Bundle in build/ hinterher eine
# App-Store-Signatur, und der nächste build_dmg.sh-Lauf auf demselben Verzeichnis
# würde ein DMG mit den falschen Zertifikaten erzeugen, ohne es zu merken.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGED_APP="$WORK/FinanzGecko.app"
ditto "$APP" "$STAGED_APP"

# ------------------------------------------------- Provisioning + Rechte --

if [ -n "${PROVISION_PROFILE:-}" ]; then
  [ -f "$PROVISION_PROFILE" ] || die "PROVISION_PROFILE zeigt auf keine Datei: $PROVISION_PROFILE"
  cp "$PROVISION_PROFILE" "$STAGED_APP/Contents/embedded.provisionprofile"
  echo "Provisioning-Profil eingebettet."
else
  echo "WARNUNG: kein PROVISION_PROFILE — das .pkg entsteht, App Store Connect" >&2
  echo "         wird es aber beim Upload ablehnen." >&2
fi

# $(AppIdentifierPrefix) ersetzt sonst nur Xcode. Beim direkten codesign-Aufruf
# landet der Platzhalter wörtlich in der Signatur, die Access Group passt dann zu
# nichts und der Keychain-Zugriff scheitert erst zur Laufzeit beim Nutzer.
ENTITLEMENTS="$WORK/AppStore.resolved.entitlements"
sed "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" "$ENTITLEMENTS_TEMPLATE" > "$ENTITLEMENTS"
grep -q "${TEAM_ID}.de.finanzgecko.app" "$ENTITLEMENTS" \
  || die "Team-ID konnte nicht in die Entitlements eingesetzt werden."

# ------------------------------------------------------------ Signieren --

security find-identity -v -p codesigning | grep -q "$APP_SIGN_IDENTITY" \
  || die "keine Identität '$APP_SIGN_IDENTITY' im Schlüsselbund."
security find-identity -v | grep -q "$PKG_SIGN_IDENTITY" \
  || die "keine Identität '$PKG_SIGN_IDENTITY' im Schlüsselbund."

xattr -cr "$STAGED_APP"

# Inside-out und ohne --deep, aus denselben Gründen wie in build_dmg.sh: nur das
# äußere Bundle bekommt die Entitlements, die eingebetteten Teile nicht.
sign_one() {
  codesign --force --options runtime --timestamp --sign "$APP_SIGN_IDENTITY" "$@"
}

if [ -d "$STAGED_APP/Contents/Frameworks" ]; then
  while IFS= read -r -d '' lib; do
    sign_one "$lib"
  done < <(find "$STAGED_APP/Contents/Frameworks" -type f -name "*.dylib" -print0)

  while IFS= read -r -d '' fw; do
    sign_one "$fw"
  done < <(find "$STAGED_APP/Contents/Frameworks" -mindepth 1 -maxdepth 1 -print0)
fi

sign_one --entitlements "$ENTITLEMENTS" "$STAGED_APP"
codesign --verify --strict --verbose=2 "$STAGED_APP"

# Belegt, dass die Sandbox wirklich aktiv ist. Ohne diese Prüfung ist der
# häufigste Fehlerfall ein Build, der aussieht wie ein App-Store-Build, aber
# ohne Sandbox läuft — das fällt sonst erst im Review auf.
codesign -d --entitlements :- "$STAGED_APP" 2>/dev/null | grep -q "app-sandbox" \
  || die "Die signierte App trägt kein app-sandbox-Entitlement."

echo "App signiert und sandboxed."

# --------------------------------------------------------- .pkg bauen ----

# productbuild, nicht pkgbuild: App Store Connect erwartet ein Distributions-
# Paket, und --component setzt gleich den Installationspfad.
rm -f "$OUT_FILE"
productbuild --component "$STAGED_APP" /Applications --sign "$PKG_SIGN_IDENTITY" "$OUT_FILE"

echo
echo "Fertig: $OUT_FILE"
echo
echo "Naechster Schritt — erst pruefen, dann hochladen:"
echo "  xcrun altool --validate-app -f \"$OUT_FILE\" -t macos \\"
echo "    --apiKey \"\$APPLE_API_KEY_ID\" --apiIssuer \"\$APPLE_API_ISSUER_ID\""
echo "  xcrun altool --upload-package \"$OUT_FILE\" -t macos \\"
echo "    --apiKey \"\$APPLE_API_KEY_ID\" --apiIssuer \"\$APPLE_API_ISSUER_ID\""
echo "(--upload-app ist deprecated, deshalb --upload-package. Alternativ die"
echo " Transporter-App aus dem Mac App Store, wenn es klicken statt tippen sein soll.)"
echo
echo "Nicht vergessen, einmalig in App Store Connect:"
echo "  - Exportbestimmungen: die App verschluesselt lokale Daten mit AES-256"
echo "    (Paket 'cryptography', nicht das OS). Ob das unter die Ausnahme faellt,"
echo "    ist eine rechtliche Einschaetzung — deshalb steht hier bewusst kein"
echo "    ITSAppUsesNonExemptEncryption in der Info.plist."
echo "  - Datenschutzangaben ('Nutzung von Daten'): keine Datenerfassung."
