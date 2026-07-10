# FinanzGecko 🦎

Nativer macOS-Vermögenstracker. Kein Server, keine Cloud, kein Account —
alle Daten liegen in einer einzigen JSON-Datei im eigenen Datenverzeichnis
der App. Basiert auf [Neutralinojs](https://neutralino.js.org/).

## Einmalig einrichten

**Voraussetzung:** Node.js >= 20 (z. B. über [nvm](https://github.com/nvm-sh/nvm))

**Linux (Ubuntu/Debian):**
```bash
# WebKitGTK für Neutralino (Ubuntu 22.04+ / Debian 12+)
sudo apt-get update
sudo apt-get install libwebkit2gtk-4.1-0

# Falls auf älteren Distributionen:
# Ubuntu 20.04: libwebkit2gtk-4.0-37
# Debian 11: libwebkit2gtk-4.0-37
```

**macOS:** Keine zusätzlichen Abhängigkeiten nötig.

**Windows:** Keine zusätzlichen Abhängigkeiten nötig.

```bash
# Neutralino-CLI installieren (global, einmalig)
npm i -g @neutralinojs/neu

# Im Projektordner: Client-Library + Binaries herunterladen
neu update
```

> **Bekannter CLI-Bug (Stand v11.7.2):** Diese Version zieht `uuid@14` (ESM-only),
> obwohl der CLI-Code es per CommonJS `require()` lädt — jeder `neu`-Befehl
> bricht sofort mit `ERR_REQUIRE_ESM` ab. Betrifft alle Plattformen, nicht nur
> Linux. Falls das auftritt: `sudo npm install -g @neutralinojs/neu@11.7.1`
> (letzte Version vor dem kaputten `uuid`-Update).

`neu update` lädt `neutralino.js` sowie die plattformspezifischen Binaries
in `resources/` bzw. `bin/` — diese Dateien sind bewusst in `.gitignore`,
weil sie bei jedem `neu update` neu generiert werden.

**Datenverzeichnis:**
- **Linux:** `~/.local/share/de.finanzgecko.app/`
- **macOS:** `~/Library/Application Support/de.finanzgecko.app/`
- **Windows:** `%APPDATA%\de.finanzgecko.app\`

## Entwickeln

```bash
neu run
```

Startet die App im Entwicklungsmodus mit Live-Reload bei Dateiänderungen.

## Bauen (Release)

```bash
neu build --release
```

Ergebnis liegt in `dist/finanzgecko/` — darunter eine `resources.neu`
(gebündelte Web-Ressourcen) und je eine Binary pro Plattform/Architektur
(`finanzgecko-linux_x64`, `finanzgecko-mac_arm64`, `finanzgecko-win_x64.exe`, …).

Windows-Metadaten (Firmenname, Beschreibung, Copyright, Produktname im
Explorer-Eigenschaften-Dialog) sowie das `.exe`-Icon werden von `neu build`
automatisch aus `author`/`description`/`copyright`/`applicationName` in
`neutralino.config.json` bzw. aus `modes.window.icon` erzeugt — keine
manuelle Nachbearbeitung nötig.

**Erster Start auf einem "fremden" Mac/Windows-Rechner:** Ohne Code-Signierung
zeigen macOS Gatekeeper ("nicht verifizierter Entwickler") und Windows
SmartScreen ("unbekannter Herausgeber") eine Warnung. Auf dem Mac einmalig
per Rechtsklick auf die App → *Öffnen* bestätigen, unter Windows über
"Weitere Informationen" → "Trotzdem ausführen". Betrifft nur den
allerersten Start und erfordert ein kostenpflichtiges Signierzertifikat,
um vollständig zu verschwinden.

`neu build --release` ruft `zip-lib` auf, das Node.js >= 20 voraussetzt
(`npm WARN EBADENGINE`, falls die installierte Node-Version älter ist).
Auf reinen `neu run`-Workflows ohne Release-Build fällt das nicht auf.

### macOS: als richtiges App-Bundle bauen (Dock-Icon, Finder)

`neu build` (auch mit `--macos-bundle`) liefert nur eine rohe Unix-Binary.
Die CLI-eigene `--macos-bundle`-Option hängt dabei lediglich die Endung
`.app` an die Datei an (siehe `neutralinojs-cli/src/modules/bundler.js`) —
ohne `Contents/Info.plist` und `Contents/Resources/icon.icns` erkennt der
Finder das aber nicht als echtes Bundle und zeigt kein eigenes Dock-Icon.

Einmalig/pro Release:

```bash
neu build --release   # falls noch nicht geschehen
./packaging/macos/build-app.sh          # universal (Standard)
./packaging/macos/build-app.sh arm64    # oder gezielt x64 / arm64
```

Baut `dist/finanzgecko/FinanzGecko.app` mit Info.plist, `.icns`
(generiert aus `icons/icon-512.png` per `sips`/`iconutil`) und einer
Ad-hoc-Signatur (`codesign --sign -`, kein Apple-Zertifikat nötig — auf
Apple Silicon startet eine gänzlich unsignierte App sonst nicht). Muss auf
einem Mac ausgeführt werden. Die `.app` danach normal in den
Programme-Ordner ziehen oder direkt aus `dist/finanzgecko/` starten.

### Linux: als Desktop-Anwendung installieren (Taskleisten-Icon)

Direkt gestartete Binaries (`neu run` oder das Release-Binary per Doppelklick)
zeigen in der Taskleiste unter Wayland/X11 ein generisches Icon statt des
App-Icons. Grund: Neutralino setzt keine GTK-Application-ID, wodurch die
Fenster-Identität (`WM_CLASS`/Wayland-`app_id`) vom Binary-Dateinamen abhängt
(z. B. `finanzgecko-linux_x64`) — ohne passende `.desktop`-Datei kann die
Shell (GNOME, KDE, …) kein Icon zuordnen. Die Config-Option
`modes.window.icon` setzt nur das Icon im Fenster selbst, nicht das
Taskleisten-Icon.

Einmalig beheben:

```bash
neu build --release   # falls noch nicht geschehen
./packaging/linux/install.sh
```

Legt einen stabil benannten Symlink (`~/.local/bin/finanzgecko`), einen
Startmenü-Eintrag (`~/.local/share/applications/de.finanzgecko.app.desktop`)
und die Icons im hicolor-Theme an. App danach über das Startmenü starten,
nicht mehr direkt über das Binary.

## Architektur

| Datei | Zweck |
|---|---|
| `neutralino.config.json` | Fenstergröße, `nativeAllowList`, Datenverzeichnis-Konfiguration |
| `resources/index.html` | App-Shell, native Menüleiste kommt separat aus `main.js` |
| `resources/css/theme.css` | Grün-Schwarz-Theme, System-Font-Stack für OS-natives Aussehen |
| `resources/js/store.js` | **Ersetzt IndexedDB.** Eine JSON-Datei im System-Datenverzeichnis (`NL_DATAPATH`), atomar geschrieben (temp-Datei + `move`) |
| `resources/js/currency.js` | Unverändert: Frankfurter.app-Anbindung mit Cache |
| `resources/js/charts.js` | Unverändert: eigener SVG-Linienchart + CSS-Donut |
| `resources/js/main.js` | Views, Routing, native Menüleiste (`Neutralino.window.setMainMenu`), Auto-Updater-Check |
| `update-manifest.json` | Manifest für den Auto-Updater (siehe unten) |
| `packaging/linux/` | `.desktop`-Datei + `install.sh` für Taskleisten-Icon unter Wayland/X11 |
| `packaging/macos/build-app.sh` | Baut ein echtes `.app`-Bundle (Info.plist, `.icns`, Ad-hoc-Signatur) aus der rohen Mac-Binary |
| `.github/workflows/release.yml` | CI: baut bei jedem Tag-Push alle Plattform-Binaries + macOS-Bundle und hängt sie ans GitHub-Release |

## Warum keine IndexedDB mehr

Die App schreibt jetzt direkt in eine JSON-Datei im OS-eigenen Datenverzeichnis
(dank `"dataLocation": "system"` in der Config). Das eliminiert das
gesamte Thema Safari-Speicher-Eviction, das für die PWA-Version relevant
war — eine normale Datei auf der Festplatte unterliegt keiner Verfallsregel.

**Dateipfad:**
- **Linux:** `~/.local/share/de.finanzgecko.app/app-data.json`
- **macOS:** `~/Library/Application Support/de.finanzgecko.app/app-data.json`
- **Windows:** `%APPDATA%\de.finanzgecko.app\app-data.json`

Export/Import laufen über native Save/Open-Dialoge
(`Neutralino.os.showSaveDialog` / `showOpenDialog`), nicht mehr über
Browser-Downloads.

## Auto-Updater einrichten

Zeigt bereits auf `github.com/kreativanders/finanzgecko` (in
`update-manifest.json` und `resources/js/main.js`, `UPDATE_MANIFEST_URL`).
Bei einem Fork: beide Stellen auf den eigenen GitHub-Nutzernamen/Repo
anpassen.

1. Bei jedem neuen Release:
   - Version in `neutralino.config.json` (`"version"`) hochzählen
   - `neu build --release`
   - Die entstandene `resources.neu` (in `dist/finanzgecko/`) als Asset an
     ein neues GitHub-Release anhängen (Tag z.B. `v1.1.0`)
   - `update-manifest.json` aktualisieren: `version` und `resourcesURL`
     auf das neue Release-Asset zeigen lassen, committen und pushen
2. Die App prüft beim Start automatisch im Hintergrund (unauffällig, ohne
   Fehlermeldung bei fehlender Verbindung) und zusätzlich manuell über
   *Datei → Nach Updates suchen…*

Kein eigener Server nötig — GitHub Releases + ein rohes JSON-Manifest im
Repo reichen als Update-Infrastruktur.

**CI-Unterstützung:** `.github/workflows/release.yml` baut bei jedem
gepushten Tag (`vX.Y.Z`) automatisch alle Plattform-Binaries plus das
macOS-App-Bundle und hängt sie als Assets ans passende GitHub-Release.
Nimmt aus obiger Liste die manuellen `neu build --release`-/Upload-Schritte
ab — `version` in `neutralino.config.json` und `update-manifest.json`
müssen weiterhin von Hand aktualisiert und committet werden, bevor der Tag
gepusht wird.

## Native Menüleiste

*Datei* → Backup exportieren (⌘E), Backup importieren, Nach Updates
suchen, Beenden (⌘Q) — vollständig nativ über
`Neutralino.window.setMainMenu()`, nicht Teil des HTML/CSS.

## Fenstergröße

Startet maximiert (`"maximize": true`), bleibt aber frei skalierbar
(`"resizable": true`, Mindestgröße 960×640). `"useSavedState": true`
merkt sich Größe/Position zwischen den Starts. Charts rendern sich bei
Fenstergrößenänderung automatisch neu (siehe Resize-Listener in `main.js`).

## Migration von der bisherigen PWA-Version

Falls vorher die PWA-Version genutzt wurde: einmal über deren
Export-Funktion ein Backup ziehen, hier über *Backup importieren…*
einlesen — das Datenformat ist identisch, keine Konvertierung nötig.

## Troubleshooting

**Weißer Bereich / "The URL can't be shown" beim Start (Linux):** Trat mit
`"enableServer": false` (load-dir-res-Modus) auf WebKitGTK auf — die
Custom-URI-Auflösung ohne lokalen HTTP-Server ist auf dieser Kombination
instabil. Die Config steht deshalb auf `"enableServer": true` (lokaler
Server auf `127.0.0.1`, zufälliger Port via `"port": 0`).

**App startet, aber Navigation/Views reagieren nicht:** `main.js` registriert
`Neutralino.events.on("ready", init)`, aber das `ready`-Event feuert nur,
nachdem `Neutralino.init()` explizit aufgerufen wurde (öffnet die
WebSocket-Verbindung zum nativen Prozess). Ohne diesen Aufruf bleibt die App
optisch da, aber komplett unreaktiv — kein Klick-Handler wird je registriert.
Fix steht in `startApp()` in `resources/js/main.js`.

**Nur eine Quelle für App-Dateien:** `index.html`, `css/`, `js/` und `icons/`
liegen ausschließlich unter `resources/` (Ausnahme: `icons/` bleibt zusätzlich
im Projekt-Root, weil `neu build` das native Fenster-Icon relativ zum
Projekt-Root auflöst, nicht relativ zu `resources/`). Es gab früher eine
zweite, identische Kopie von `index.html`/`css`/`js` im Projekt-Root — die
wurde nie ausgeliefert (`documentRoot` zeigt auf `/resources`), Änderungen
daran hatten also nie einen sichtbaren Effekt. Immer nur in `resources/`
editieren.

**`neu version` zeigt "Project: undefined":** `cli.binaryName` hat in
`neutralino.config.json` gefehlt (Build-Output landete dann in
`dist/undefined/` statt `dist/finanzgecko/`).
