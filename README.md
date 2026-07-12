# FinanzGecko 🦎

Nativer Desktop-Vermögenstracker. Kein Server, keine Cloud, kein Account —
alle Daten liegen in einer einzigen JSON-Datei im eigenen Datenverzeichnis
der App. Gebaut mit [Flutter](https://flutter.dev) (Desktop-Target), lokal
lauffähig auf Linux, macOS und Windows.

> Dieser Branch (`flutter`) ist eine vollständige Neuimplementierung der
> bisherigen [Neutralinojs](https://neutralino.js.org/)-App. Die
> Geschäftslogik (Kontostände, Wechselkurse, Fixposten, Backup/Restore) ist
> 1:1 übernommen, die UI ist nativ in Dart/Flutter statt HTML/CSS/JS gebaut.
> Bestehende `app-data.json`-Dateien der alten Version werden unverändert
> weiterverwendet (siehe unten).

## Einmalig einrichten (Linux, z. B. TUXEDO OS)

TUXEDO OS ist Ubuntu-basiert — die folgenden Schritte funktionieren auf jeder
Ubuntu/Debian-Ableitung.

**1. Linux-Toolchain für Flutter-Desktop-Builds:**

```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

Diese Pakete kompilieren/linken den nativen GTK-Runner — ohne sie bricht
`flutter build linux` / `flutter run -d linux` beim CMake-Schritt ab.

**2. Flutter SDK installieren** (eine der beiden Varianten):

```bash
# Variante A: per snap (einfachste Option auf TUXEDO OS/Ubuntu)
sudo snap install flutter --classic
flutter sdk-path   # zeigt den Installationspfad

# Variante B: manuell, z. B. nach ~/development
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**3. Linux-Desktop-Unterstützung aktivieren und prüfen:**

```bash
flutter config --enable-linux-desktop
flutter doctor
```

`flutter doctor` sollte unter "Linux toolchain" ein ✓ zeigen. Fehlt
`clang++`, wurde Schritt 1 übersprungen oder `libgtk-3-dev` fehlt noch.

**Datenverzeichnis** (unverändert gegenüber der Neutralino-Version):
- **Linux:** `~/.local/share/de.finanzgecko.app/`
- **macOS:** `~/Library/Application Support/de.finanzgecko.app/`
- **Windows:** `%APPDATA%\de.finanzgecko.app\`

## Entwickeln

```bash
flutter pub get
flutter run -d linux
```

Startet die App mit Hot Reload (`r` im Terminal drücken, oder im
IDE-Plugin). `-d linux` wählt explizit das Linux-Desktop-Target — nötig,
sobald mehr als ein Gerät verfügbar ist (z. B. ein angeschlossenes Android-
Handy oder Chrome für Web).

## Bauen (Release)

```bash
flutter build linux --release
```

Ergebnis liegt in `build/linux/x64/release/bundle/` — ein **Ordner**, kein
Single-File-Binary wie bei der alten Neutralino-Version: die ausführbare
Datei `finanzgecko` braucht die mitgelieferten `data/` und `lib/*.so`
daneben, um zu starten. Beim Verteilen immer den kompletten Ordner
zippen/mitgeben, nicht nur die Executable.

Zum Ausprobieren direkt aus dem Bundle heraus:

```bash
./build/linux/x64/release/bundle/finanzgecko
```

### Als Desktop-Anwendung installieren (Startmenü- & Taskleisten-Icon)

Ein direkt gestartetes Bundle zeigt in der Taskleiste unter Wayland/X11 ein
generisches Icon statt des App-Icons und taucht nicht im Startmenü auf —
GTK-Fensteridentität (`WM_CLASS`/Wayland-`app_id`) und Icon-Zuordnung laufen
über eine `.desktop`-Datei, die es für ein lose gestartetes Bundle nicht
gibt.

Einmalig beheben:

```bash
flutter build linux --release   # falls noch nicht geschehen
./packaging/linux/install.sh
```

Kopiert das Bundle nach `~/.local/share/finanzgecko/`, legt einen stabil
benannten Symlink (`~/.local/bin/finanzgecko`), einen Startmenü-Eintrag
(`~/.local/share/applications/de.finanzgecko.app.desktop`) sowie die Icons im
hicolor-Theme an. App danach über das Startmenü starten, nicht mehr direkt
über `build/`.

## macOS / Windows

Flutter-Desktop-Builds sind **nicht cross-kompilierbar** — ein macOS-Build
muss auf einem Mac laufen, ein Windows-Build unter Windows:

```bash
flutter build macos --release     # auf einem Mac
flutter build windows --release   # unter Windows
```

`flutter build macos` erzeugt bereits ein vollständiges `FinanzGecko.app`
mit Info.plist, Icon und Ad-hoc-Signatur — anders als bei Neutralino ist
dafür kein zusätzliches `packaging/macos/build-app.sh` mehr nötig, Flutter
übernimmt das Bundling selbst. `flutter build windows` erzeugt einen Ordner
unter `build/windows/x64/runner/Release/` (Executable + `data/` + DLLs), der
komplett verteilt werden muss — auch hier keine Einzeldatei mehr.

Erster Start auf einem "fremden" Mac/Windows-Rechner zeigt ohne
Code-Signierung weiterhin Gatekeeper-/SmartScreen-Warnungen (siehe
"Bekannte Einschränkungen" unten).

## Architektur

| Datei/Ordner | Zweck |
|---|---|
| `pubspec.yaml` | Paketname, Version, Dependencies (provider, http, file_selector, window_manager, fl_chart, intl, url_launcher) |
| `lib/main.dart` | Einstiegspunkt: Fenster-Setup (`window_manager`), Store-Initialisierung, `runApp()` |
| `lib/data/app_store.dart` | **Ersetzt store.js.** Persistiert die komplette App-Datenbank als JSON-Datei im System-Datenverzeichnis, atomar geschrieben (temp-Datei + rename) |
| `lib/data/app_data.dart` | In-Memory-Schema der JSON-Datei (Accounts, Balances, Assets, Subscriptions, Settings, Rate-Cache) |
| `lib/models/` | Datenklassen (`Account`, `Balance`, `Asset`, `Subscription`) mit `fromJson`/`toJson` |
| `lib/services/currency_service.dart` | Unverändert in der Logik: Frankfurter.app-Anbindung mit Cache |
| `lib/state/app_state.dart` | Zentraler `ChangeNotifier` (Provider) — lädt den Store, exponiert CRUD-Methoden + berechnete Werte (Perioden, Fixposten-Summen, Reminder) an die UI |
| `lib/ui/app_shell.dart` | Navigation, In-App-Menü ("Datei"), Tastenkürzel, Export/Import-Dialoge |
| `lib/ui/views/` | Die sieben Ansichten: Dashboard, Erfassen, Einträge, Konten, Vermögenswerte, Fixposten, Einstellungen |
| `lib/ui/widgets/` | Wiederverwendbare Bausteine: Linienchart/Donut (`fl_chart`), Monatsauswahl, Vorzeichen-Umschalter, Banner |
| `packaging/linux/` | `.desktop`-Datei + `install.sh` für Startmenü-/Taskleisten-Icon unter Wayland/X11 |
| `.github/workflows/release.yml` | CI: baut bei jedem Tag-Push die drei Plattform-Bundles (je ein nativer Runner pro OS) und hängt sie ans GitHub-Release |

## Warum weiterhin keine Datenbank-Engine

Wie schon bei der Neutralino-Version: eine einzige JSON-Datei im
OS-eigenen Datenverzeichnis, keine SQLite/Hive/Isar-Abhängigkeit. Für die
Datenmenge eines persönlichen Vermögenstrackers (ein paar hundert
Kontostände) ist "ganze Datei einlesen/schreiben" völlig ausreichend und
hält den Code einfach.

**Dateipfad:**
- **Linux:** `~/.local/share/de.finanzgecko.app/app-data.json`
- **macOS:** `~/Library/Application Support/de.finanzgecko.app/app-data.json`
- **Windows:** `%APPDATA%\de.finanzgecko.app\app-data.json`

Die Datei ist unverschlüsselt. Vertraulichkeit gegenüber anderen lokalen
OS-Accounts wird über Dateirechte hergestellt (`chmod 0700` fürs
Datenverzeichnis, `0600` für die Datei, unter Linux/macOS) — nicht über
Verschlüsselung. Unter Windows ist das (mangels POSIX-Rechten) nicht
anwendbar; dort schützt allein das Benutzerprofil-ACL des Betriebssystems.

Export/Import laufen über native Save/Open-Dialoge (`file_selector`), nicht
über Browser-Downloads.

## Fensterverhalten

Startet mit der zuletzt verwendeten Größe (Standard 1280×860, Mindestgröße
960×640, `window_manager`). Ob das Fenster beim letzten Beenden maximiert
war, wird ebenfalls gemerkt. Anders als bei Neutralino wird nur Größe +
Maximiert-Status gespeichert, nicht die Bildschirmposition — das vermeidet,
dass das Fenster nach einem Monitor-/Auflösungswechsel außerhalb des
sichtbaren Bereichs landet.

## In-App-Menü statt nativer Menüleiste

Flutters `PlatformMenuBar` unterstützt aktuell nur macOS — unter Linux und
Windows gibt es keine native App-Menüleiste. Statt einer Neutralino-typischen
`Neutralino.window.setMainMenu()`-Leiste hat die App deshalb einen
"Datei"-Menüpunkt direkt im eigenen Fensterkopf (Backup exportieren/
importieren, Beenden), plattformübergreifend identisch. Tastenkürzel
(<kbd>Strg</kbd>+<kbd>E</kbd>/<kbd>I</kbd>/<kbd>Q</kbd>, unter macOS
<kbd>Cmd</kbd>) funktionieren global im Fenster, unabhängig vom Menü.

## Migration von der bisherigen Neutralino-/PWA-Version

Bestehende `app-data.json` wird unverändert eingelesen — das Schema ist
identisch geblieben (gleiche Feldnamen, gleiches Datenverzeichnis). Einfach
diese Version starten, es ist kein manueller Import nötig. Für einen
Rechnerwechsel oder als zusätzliche Sicherheit weiterhin: über
*Einstellungen → Backup exportieren…* ein Backup ziehen und auf dem neuen
Rechner über *Backup importieren…* einlesen.

Eine Inkonsistenz der alten Version wurde dabei behoben: Import stellte
Fixposten und das Standard-Fixposten-Intervall bisher nicht wieder her,
obwohl der Export sie enthielt. Das ist jetzt symmetrisch — ein
Backup-Restore bringt wirklich *alle* exportierten Daten zurück.

## Bekannte Einschränkungen

- **Kein In-App-Auto-Updater.** Ein Update bedeutet: neues Release-Zip aus
  GitHub Releases laden, altes Bundle ersetzen (bzw. `install.sh` erneut
  laufen lassen). Das Datenverzeichnis hängt nur vom Datenpfad ab, nicht vom
  Bundle-Speicherort — bestehende Nutzerdaten bleiben unberührt.
- **Erster Start auf einem "fremden" Mac/Windows-Rechner:** Ohne
  Code-Signierung zeigen macOS Gatekeeper ("nicht verifizierter
  Entwickler") und Windows SmartScreen ("unbekannter Herausgeber") eine
  Warnung. Auf dem Mac einmalig per Rechtsklick → *Öffnen* bestätigen, unter
  Windows über "Weitere Informationen" → "Trotzdem ausführen". Ein
  kostenpflichtiges Signierzertifikat würde das vollständig beheben.
  `flutter build macos` signiert das Bundle bereits ad-hoc (`codesign --sign -`),
  das reicht für den eigenen Rechner, aber nicht für Fremdverteilung ohne
  Warnung.

## Updates veröffentlichen

1. Bei jedem neuen Release:
   - Version in `pubspec.yaml` (`version:`) hochzählen und committen
   - Tag pushen, z. B.: `git tag v1.1.0 && git push origin v1.1.0`
2. `.github/workflows/release.yml` baut auf drei nativen Runnern
   (ubuntu/macos/windows-latest) je ein Plattform-Bundle und hängt es als
   Zip ans GitHub-Release.
3. Nutzer laden das passende Zip herunter, entpacken es und ersetzen die
   alte Ordnerkopie (Linux: `./packaging/linux/install.sh <entpackter-Ordner>`
   erledigt das inkl. Startmenü-Eintrag).

## Troubleshooting

**`flutter doctor` zeigt "Linux toolchain" mit ✗ / `clang++` fehlt:**
`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev`
nachholen (siehe "Einmalig einrichten" oben).

**App startet, zeigt aber kein Icon in der Taskleiste:** Erwartet bei einem
direkt aus `build/` gestarteten Bundle, siehe "Als Desktop-Anwendung
installieren" oben — `./packaging/linux/install.sh` ausführen.

**Wechselkurs-Abfrage schlägt fehl / "offline":** Beim Erfassen eines
Kontostands oder Fixpostens in einer Fremdwährung fragt die App bei
fehlendem Netzwerkzugriff (Frankfurter.app-API nicht erreichbar und kein
gecachter Kurs vorhanden) nach einem manuell eingegebenen Kurs. Das ist kein
Fehler, sondern der bewusste Offline-Fallback.
