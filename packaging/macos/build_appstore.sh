#!/usr/bin/env bash
# Baut FinanzGecko für den Mac App Store: sandboxed, signiert mit den
# "3rd Party Mac Developer"-Zertifikaten, verpackt als .pkg zum Upload nach
# App Store Connect.
#
# Das ist bewusst ein ZWEITES Skript neben build_dmg.sh und kein Schalter darin.
# Die beiden Builds unterscheiden sich in Keychain-Variante, Signatur-Zertifikat,
# Verpackung und Update-Weg — praktisch alles außer dem Dart-Code. Ein gemeinsames
# Skript mit fünf `if`-Zweigen wäre schwerer zu lesen als zwei kurze, und der
# DMG-Weg ist der, der nicht kaputtgehen darf.
#
# WICHTIG — beide Builds teilen sich den Container, aber NICHT den Schlüssel:
#   Seit 2026-08-13 ist auch der DMG-Build sandboxed, beide sehen also dasselbe
#   ~/Library/Containers/de.finanzgecko.app/Data. Lesen kann eine Datendatei
#   trotzdem nur einer: der DMG-Build legt seinen Schlüssel in der Login-Keychain
#   ab, der App-Store-Build in der Data-Protection-Keychain
#   (usesDataProtectionKeychain: kIsMacAppStore). Deshalb hat jeder Kanal seine
#   EIGENE Datei im selben Ordner (finanzgecko-data.json bzw.
#   finanzgecko-data-appstore.json) — der Wechsel hin und zurück ist nur noch
#   ein Start der anderen App, es wird nichts umbenannt oder verschoben.
#   Findet der Store-Build beim allerersten Start nur die Datei des anderen
#   Kanals, zeigt er den Erklärungsbildschirm mit "Backup importieren…" und
#   "Ohne Daten starten" — siehe dev/ai/persistence.md "Channel switch".
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

# Bequemlichkeit statt drei exports pro Shell: appstore.env wird eingelesen,
# wenn sie existiert. Sie ist gitignored (Team-ID + Pfad zur Team-Identitaet);
# die Vorlage daneben heisst appstore.env.example.
# Bereits gesetzte Variablen gewinnen, damit ein einmaliges
# `TEAM_ID=… ./build_appstore.sh` die Datei uebersteuert.
ENV_FILE="$SCRIPT_DIR/appstore.env"
if [ -f "$ENV_FILE" ]; then
  _team_id_before="${TEAM_ID:-}"
  _profile_before="${PROVISION_PROFILE:-}"
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  [ -z "$_team_id_before" ] || TEAM_ID="$_team_id_before"
  [ -z "$_profile_before" ] || PROVISION_PROFILE="$_profile_before"
  echo "Konfiguration aus $ENV_FILE gelesen."
fi

[ -n "${TEAM_ID:-}" ] || die "TEAM_ID ist nicht gesetzt — entweder exportieren oder packaging/macos/appstore.env anlegen (Vorlage: appstore.env.example)."

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
# $(TeamIdentifierPrefix) ist dieselbe ID OHNE Punkt — daher zwei getrennte
# Ersetzungen, und die laengere zuerst waere hier egal, weil die Muster sich
# nicht ueberschneiden.
ENTITLEMENTS="$WORK/AppStore.resolved.entitlements"
sed -e "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" \
    -e "s/\$(TeamIdentifierPrefix)/${TEAM_ID}/g" \
    "$ENTITLEMENTS_TEMPLATE" > "$ENTITLEMENTS"
grep -q "${TEAM_ID}.de.finanzgecko.app" "$ENTITLEMENTS" \
  || die "Team-ID konnte nicht in die Entitlements eingesetzt werden."
grep -q "com.apple.application-identifier" "$ENTITLEMENTS" \
  || die "application-identifier fehlt in den Entitlements (TestFlight-Warnung 90886)."

# ------------------------------------------------------------ Signieren --

security find-identity -v -p codesigning | grep -q "$APP_SIGN_IDENTITY" \
  || die "keine Identität '$APP_SIGN_IDENTITY' im Schlüsselbund."
security find-identity -v | grep -q "$PKG_SIGN_IDENTITY" \
  || die "keine Identität '$PKG_SIGN_IDENTITY' im Schlüsselbund."

xattr -cr "$STAGED_APP"

# App Store Connect lehnt ein .pkg ab, dessen Dateien nur root lesen kann:
# "The installer package includes files that are only readable by the root user."
# (409 STATE_ERROR.VALIDATION_ERROR, erlebt am 2026-08-30 mit 1.10.1+22). Der
# Ausloeser war das oben kopierte .provisionprofile: `cp` ohne -p uebernimmt den
# Modus der Quelldatei, und die liegt privat mit 600 — der Rest des Bundles war
# sauber (umask 022, `find build/... ! -perm -0004` leer). productbuild reicht
# die Rechte unveraendert ins .pkg weiter, und der Fehler faellt erst beim Upload
# auf, also nach dem Signieren und nach einer verbrannten Minute.
#
# Trotzdem bewusst pauschal statt nur auf dem Profil: dieselbe Falle stellt jede
# weitere kopierte Quelldatei und jede restriktive umask im Build-Shell.
#
# a+rX ist bewusst additiv: Leserecht fuer alle, Ausfuehrungsrecht nur dort, wo es
# schon gesetzt ist oder wo es ein Verzeichnis braucht. Es nimmt nichts weg.
# Muss VOR dem Signieren laufen — ein chmod danach wuerde die Signatur nicht
# ungueltig machen, aber es gibt keinen Grund, sich darauf zu verlassen.
chmod -R a+rX "$STAGED_APP"

# Beweis statt Vertrauen: findet die Pruefung noch etwas, ist das chmod oben an
# einem Sonderfall vorbeigelaufen, und der Upload wuerde erneut scheitern.
# Bewusst OHNE Pipe nach find — `| grep -q` beendet sich beim ersten Treffer und
# macht `set -o pipefail` aus dem Erfolgsfall einen Fehlschlag (dieselbe Falle
# wie bei `strings` weiter unten). Oktal statt a+rX, weil -perm mit symbolischen
# Modi zwischen BSD und GNU auseinandergeht: 0004 = o+r, 0001 = o+x.
UNREADABLE="$(find "$STAGED_APP" \( ! -perm -0004 -o \( -type d ! -perm -0001 \) \) -print)"
if [ -n "$UNREADABLE" ]; then
  echo "$UNREADABLE" >&2
  die "Diese Eintraege sind nicht fuer alle lesbar — App Store Connect lehnt das .pkg sonst ab."
fi

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

# Ohne application-identifier IN DER SIGNATUR laedt der Build zwar hoch, ist aber
# fuer TestFlight unbrauchbar (Warnung 90886) — und das erfaehrt man erst im
# Delivery-Log, nachdem man eine Build-Nummer verbrannt hat. Xcode setzt den Key
# automatisch, unser manueller codesign-Aufruf nur ueber die Entitlements-Datei.
codesign -d --entitlements :- "$STAGED_APP" 2>/dev/null | grep -q "${TEAM_ID}.de.finanzgecko.app" \
  || die "Die Signatur enthält keinen application-identifier ${TEAM_ID}.de.finanzgecko.app — der Build wäre für TestFlight unbrauchbar (90886)."

# Belegt, dass --dart-define=FINANZGECKO_MAS=true wirklich angekommen ist. Ohne
# diese Pruefung ist der gefaehrlichste Fehlerfall ein Build, der sandboxed und
# von Apple signiert ist, intern aber noch kIsMacAppStore=false hat: er zeigt den
# Update-Eintrag (Guideline 2.4.5) und greift auf die LOGIN-Keychain statt auf
# die Data-Protection-Keychain zu — der einzige Weg, auf dem ein App-Store-Build
# den Schluessel eines DMG-Builds anfassen koennte.
#
# Geprueft wird das AOT-Snapshot selbst, nicht die xcconfig: Flutter schreibt die
# dart-defines dort nicht (mehr) hinein — eine fruehere Version dieser Pruefung
# ist genau daran gescheitert. Weil kIsMacAppStore const ist, faltet der Compiler
# beide Zweige weg, und die zwei Marker unten sind direkt beobachtbar:
#   - der MAS-Satz aus settings_view.dart existiert nur, wenn der define gesetzt war
#   - api.github.com verschwindet, weil AppState.updateService dann null ist und
#     nichts mehr UpdateService referenziert (2.4.5)
# Funktioniert auch mit SKIP_BUILD=1, weil es das uebergebene Bundle prueft.
APP_BINARY="$STAGED_APP/Contents/Frameworks/App.framework/Versions/A/App"
[ -f "$APP_BINARY" ] || die "App.framework-Binary nicht gefunden: $APP_BINARY"

# WARNUNG: erst in eine Datei, dann greppen — NICHT `strings … | grep -q`.
# `grep -q` beendet sich beim ersten Treffer, `strings` bekommt SIGPIPE (141),
# und `set -o pipefail` macht daraus einen Fehlschlag. Der Erfolgsfall saehe
# dann aus wie der Fehlerfall; genau daran ist die erste Fassung gescheitert.
APP_STRINGS="$WORK/app-strings.txt"
strings "$APP_BINARY" > "$APP_STRINGS"

grep -q "den App Store" "$APP_STRINGS" \
  || die "Der MAS-Marker fehlt im Binary — der Build lief ohne --dart-define=FINANZGECKO_MAS=true."

grep -q "api.github.com" "$APP_STRINGS" \
  && die "api.github.com steckt noch im Binary — UpdateService wurde nicht wegoptimiert (Guideline 2.4.5)." \
  || true

echo "kIsMacAppStore ist wirksam: MAS-Marker vorhanden, api.github.com nicht im Binary."

echo "App signiert und sandboxed."

# --------------------------------------------------------- .pkg bauen ----

# productbuild, nicht pkgbuild: App Store Connect erwartet ein Distributions-
# Paket, und --component setzt gleich den Installationspfad.
rm -f "$OUT_FILE"
productbuild --component "$STAGED_APP" /Applications --sign "$PKG_SIGN_IDENTITY" "$OUT_FILE"

echo
echo "Fertig: $OUT_FILE"
echo
echo "Vor dem Upload — der Krypto-Smoketest aus dev/app-store.md 4a:"
echo "  Build starten, in Console.app auf 'FinanzGecko crypto' filtern. Erwartet:"
echo "    AES-256-GCM = OS (cryptography_flutter), PBKDF2-HMAC-SHA256 = OS (CommonCrypto)"
echo "  Steht dort '= Dart', ist der Fallback aktiv und die Exportbestimmungs-"
echo "  Angabe in der Info.plist waere falsch. Dann NICHT hochladen."
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
echo "  - Exportbestimmungen: fragt App Store Connect nicht mehr ab. Die Antwort"
echo "    steht als ITSAppUsesNonExemptEncryption = false in der Info.plist und"
echo "    beruht darauf, dass AES-GCM und PBKDF2 aus dem OS kommen (seit v1.10)."
echo "    Begruendung und Audit: dev/native-libraries.md."
echo "  - Datenschutzangaben ('Nutzung von Daten'): keine Datenerfassung."
