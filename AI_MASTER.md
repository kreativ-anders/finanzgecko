# FinanzGecko — AI Master Spec

**Zweck dieses Dokuments:** Dies ist die zentrale Referenz, damit eine KI (dieses oder ein anderes Modell) die App
**FinanzGecko nahezu identisch nachbauen oder konsistent weiterentwickeln kann** — ohne den bisherigen Chatverlauf zu
kennen. Zusammen mit den fachlichen Spezifikationen in [`gherkin/`](gherkin/) ist dies die "Source of Truth" für
Architektur, Konventionen, Domänensprache und Verhalten der App.

> **Pflicht für jede KI, die an diesem Repo arbeitet:** siehe Abschnitt ["Regeln für KI-Agenten"](#regeln-für-ki-agenten-pflichtlektüre)
> ganz unten — insbesondere die Pflicht, dieses Dokument und `gherkin/` bei jeder Änderung synchron zu halten.

**AI_MASTER.md ist der Koordinator für mehrere Werkzeug-spezifische Anweisungsdateien**, nicht die einzige. Jedes
gängige KI-Coding-Tool sucht an einem eigenen, festen Pfad nach Repo-Instruktionen; damit jedes Werkzeug austauschbar
bleibt, gibt es pro Tool eine schlanke Pointer-Datei, die nur die nicht verhandelbaren Regeln wiederholt und für
alles andere hierher sowie auf `gherkin/` verweist — Details und die vollständige Liste in
[Abschnitt 3](#3-ordnerstruktur). Ändert sich eine dieser Regeln, müssen **alle** Pointer-Dateien im selben Schritt
nachgezogen werden (siehe "Regeln für KI-Agenten" #1).

---

## 1. Elevator Pitch

FinanzGecko ist ein **nativer Desktop-Vermögenstracker** (Flutter, Linux/macOS/Windows). Kein Server, keine Cloud,
kein Account. Nutzer:innen legen Konten (Girokonto, Depot, Krypto, …) und Vermögenswerte (Sachwerte) an, erfassen
monatlich Kontostände, pflegen wiederkehrende Ein-/Ausgaben ("Fixposten") und bekommen dafür ein Dashboard mit
Vermögensverlauf, Prognose, Verteilung nach Kontotyp und Kennzahlen. Alle Daten liegen AES-256-GCM-verschlüsselt in
einer einzigen JSON-Datei im OS-Datenverzeichnis; der Schlüssel liegt im OS-Credential-Speicher.

Die komplette UI ist **auf Deutsch** — das ist ein Kernmerkmal, kein Zufall, und muss bei jeder Regenerierung/
Erweiterung erhalten bleiben (siehe [Glossar](#7-domänen-glossar-verbindlich)).

**Lizenz:** Quellcode öffentlich auf GitHub (`kreativ-anders/finanzgecko`), lizenziert unter **GPL-3.0 mit
"Commons Clause"-Zusatz** (siehe [`LICENSE`](LICENSE)): Copyleft wie bei GPL — Quellcode frei einsehbar, veränderbar
und weitergebbar, Ableitungen müssen unter denselben Bedingungen bleiben — aber die Commons Clause untersagt
zusätzlich jede **kommerzielle** Nutzung (Verkauf der Software oder eines Produkts/Service, dessen Wert überwiegend
aus ihrer Funktionalität stammt). Das ist bewusst **kein** OSI-approved "Open Source" im engeren Sinn (die Open
Source Definition verbietet Einschränkungen nach Verwendungszweck) — auf der Website (`docs/index.html`) daher
als "quelloffen" plus einer eigenen FAQ-Antwort mit Lizenzdetails kommuniziert, nicht unkommentiert als "Open
Source" behauptet. Die App selbst bleibt für Endnutzer:innen kostenlos (GitHub Releases); finanziert wird die
Weiterentwicklung stattdessen über eine freiwillige "Pay what you want"-Unterstützung via Stripe auf der Website
(Abschnitt "Entwicklung unterstützen").

## 2. Tech-Stack

| Bereich | Wahl | Version (siehe `pubspec.yaml`) |
|---|---|---|
| Framework | Flutter (Desktop-Targets only: Linux/macOS/Windows, kein Mobile/Web) | SDK ^3.12.2 |
| State Management | `provider` (`ChangeNotifier` + `ChangeNotifierProvider`) | ^6.1.5 |
| Persistenz | eigene JSON-Datei, kein SQLite/Hive/Isar (bewusste Entscheidung, siehe [dev/architecture.md](dev/architecture.md)) | — |
| Verschlüsselung | `cryptography` (AES-256-GCM) + `flutter_secure_storage` (Schlüssel im OS-Keychain) | ^2.7.0 / ^10.3.1 |
| Charts | `fl_chart` (Linie, Donut, gestapelte Fläche — eigene Wrapper in `lib/ui/widgets/`) | ^1.2.0 |
| Wechselkurse | `http` gegen die freie Frankfurter.app-API (EZB-Referenzkurse) | ^1.6.0 |
| OS-Benachrichtigungen | `local_notifier` (native Desktop-Notifications Linux/macOS/Windows) | ^0.1.6 |
| App-Metadaten | `package_info_plus` (liest Version/Build-Nummer zur Laufzeit aus der Installation, für Einstellungen → "Hilfe") | ^10.2.1 |
| Fenster | `window_manager` (Größe/Maximiert-Status merken) | ^0.5.2 |
| Dateidialoge | `file_selector` (native Save/Open, kein Browser-Download) | ^1.1.0 |
| Links | `url_launcher` (externe URLs, mailto:, Datei-Explorer öffnen) | ^6.3.2 |
| Formatierung | `intl` (`NumberFormat`, deutsches Zahlenformat `de_DE`) | ^0.20.3 |
| Lint | `flutter_lints` | ^6.0.0 |

Es gibt **keine** Backend-Services, keine REST-API dieser App selbst, keine Datenbank-Engine, kein Auth-System.
Die App baut **von sich aus gar keine** Netzwerkverbindung auf; es gibt genau zwei **Anlässe**, und beide setzen
eine ausdrückliche Nutzerentscheidung voraus. Bewusst "Anlässe" statt "Aufrufe": hinter dem zweiten stecken seit
dem geprüften Download mehrere HTTP-Aufrufe (Releases-API, Asset, `SHA256SUMS`) — die Zahl der Anlässe ist die
Aussage, die stimmen muss, nicht die Zahl der Requests.
1. `api.frankfurter.dev` für Wechselkurse — **Opt-in** (`RateFetchConsent`, Standard `unset` = nicht erlaubt).
   Gefragt wird einmalig im Moment des ersten echten Kursbedarfs, nie beim Öffnen einer Ansicht; die Sperre sitzt
   in `CurrencyService.getExchangeRate` selbst, nicht nur an den Aufrufstellen. Ohne Zustimmung bleiben der lokale
   Cache und der manuelle Kurs-Dialog, die App ist voll nutzbar. Umkehrbar unter Einstellungen → Wechselkurse.
2. GitHub über "Nach Updates suchen" (Einstellungen → Hilfe) auf Klick (`UpdateService`, Abschnitt 6) — kein
   Hintergrund-Check, kein Start-Check. Das sind zwei Stufen: erst die Releases-API (`api.github.com`) für den
   neuesten Tag; und **nur wenn man danach im Dialog "Herunterladen" wählt**, das Release-Asset selbst plus die
   Datei `SHA256SUMS`. Letzteres läuft über GitHubs Download-URLs, die auf deren Asset-Server umleiten
   (`objects.githubusercontent.com`) — beim Aufzählen der kontaktierten Hosts nicht vergessen, `api.github.com`
   allein ist seitdem unvollständig.

Auch die Erreichbarkeitsanzeige der Kurs-API in Einstellungen → Hilfe pingt nichts beim Aufbau der Ansicht: sie
zeigt den gespeicherten Zustand und prüft erst auf Klick auf "Jetzt prüfen". Ein Zustimmungsdialog beim bloßen
Öffnen der Einstellungen wäre für Nutzer nicht nachvollziehbar — deshalb wird dort **nie** gefragt.

## 3. Ordnerstruktur

```
finanzgecko/
├── AI_MASTER.md                  # ← dieses Dokument; Koordinator der KI-Anweisungsdateien unten (Details: Absatz nach der Kopfzeile)
├── CLAUDE.md                     # Ausführliche Alltags-Arbeitsanleitung (Navigation im Repo, Feature-Regenerierung,
│                                 #   Website-Fallstricke) — trotz des Namens werkzeugneutral, importiert AI_MASTER.md
│                                 #   am Ende (`@AI_MASTER.md`, Claude-Code-spezifische Syntax). Gelesen von Claude Code.
├── AGENTS.md                     # Schlanke Pointer-Datei (agents.md-Konvention): wiederholt nur die nicht verhandel-
│                                 #   baren Regeln aus CLAUDE.md und verweist für alles andere hierher + auf CLAUDE.md/
│                                 #   gherkin/. Gelesen von OpenAI Codex CLI u. a. Tools, die diese Konvention unterstützen.
├── GEMINI.md                     # Dieselbe Pointer-Datei für Gemini CLI (Google).
├── .github/copilot-instructions.md # Dieselbe Pointer-Datei für GitHub Copilot (Pfad von Copilot vorgegeben, daher
│                                 #   unter .github/ statt im Root — siehe Eintrag bei .github/workflows/ unten).
│                                 #   **Alle vier Dateien oben halten identische "Non-negotiable rules"-Abschnitte** —
│                                 #   ändert sich eine Kernregel (z. B. eine neue Architekturentscheidung mit
│                                 #   Diskussionspflicht), müssen alle im selben Schritt nachgezogen werden (siehe
│                                 #   "Regeln für KI-Agenten" #1). Neues Tool mit eigener Konvention? Gleiche
│                                 #   Pointer-Datei ergänzen, hier eintragen, CLAUDE.md-Absatz "Other AI tools" pflegen.
├── CORPORATE_DESIGN.md           # Farbpalette, Markenfarben-Regeln, Typografie, App-Icon — bewusst kompakt und
│                                 #   ohne Code-Bezug für Design/Marketing/externe Gestaltung; die technische
│                                 #   Umsetzung (Getter, Kontrast-Fallbacks) steht stattdessen in §5 "Farbtoken —
│                                 #   technische Umsetzung". Bei jeder Änderung an lib/ui/theme.dart/constants.dart-
│                                 #   Designtokens beide Stellen mitziehen (siehe "Regeln für KI-Agenten" #1/#4)
├── CHANGELOG.md                  # generiert vom release-Job in release.yml (Commits seit letztem Tag, oben angehängt) — nicht von Hand pflegen
├── ROADMAP.md                    # Kurze, öffentliche Checkbox-Liste (Englisch): was als Nächstes kommt. Bewusst ohne Details —
│                                 #   Begründungen/Entscheidungen gehören hierher (AI_MASTER), Verhalten nach gherkin/
├── LICENSE                       # GPL-3.0 + "Commons Clause"-Zusatz (Copyleft, aber keine kommerzielle Nutzung) — siehe "Lizenz" unten
├── gherkin/                      # ← fachliche Spezifikation als Gherkin-Features (deklarativ)
│   └── executable/               # ← ausführbare Features (@executable), laufen via test/support/gherkin_runner.dart
├── templates/                    # ← Import-Vorlage (import-template.json) + Feld-Doku für die Datenmigration aus Fremdtools
├── README.md                     # Schlanker Einstieg (Englisch, wie der Code — siehe Hinweis unten): Pitch, Lizenz, Quick Start, Architektur-Tabelle, Links weiter
├── CONTRIBUTING.md               # Workflow für Beiträge (Englisch), verlinkt dev/
├── dev/                          # Entwickler-Referenz (Englisch), ausgelagert aus README (Details statt Prosa in der Kurzdoku)
│   ├── setup.md                  #   Plattform-Toolchain-Setup (Linux/macOS/Windows)
│   ├── building.md               #   Dev-Run, Release-Builds, Packaging, CI/Release-Prozess, Icon-Pipeline
│   ├── architecture.md           #   Architektur-Entscheidungen: keine DB-Engine, Verschlüsselung, Fenster/Menü
│   └── troubleshooting.md        #   Troubleshooting, bekannte Einschränkungen, Migration von Altversionen
├── pubspec.yaml                  # Package-Name, Version, Dependencies, flutter_launcher_icons-Konfig
├── analysis_options.yaml         # Lint-Regeln (flutter_lints)
├── lib/
│   ├── main.dart                 # Entry Point: window_manager-Setup, Store-Init, runApp()
│   ├── constants.dart            # Domänen-Konstanten: Tags/Kontotypen, Farben, Banken-Liste, Währungen, Schwellwerte
│   ├── data/
│   │   ├── app_store.dart        # Persistenzschicht: Verschlüsselung, atomare Writes, Write-Queue, Export/Import
│   │   ├── app_schema.dart       # In-Memory-Schema der JSON-Datei (Klasse AppSchema: schemaVersion, Listen, meta, window)
│   │   ├── secure_key_store.dart # AES-Schlüssel im OS-Keychain (flutter_secure_storage)
│   │   └── backup_crypto.dart    # Passwortgeschützte Backups (PBKDF2 → AES-GCM) — eigenes Format, gerätunabhängig,
│   │                             #   Passwort optional; ohne Passwort bleibt es beim bisherigen Klartext-JSON
│   ├── models/                   # Datenklassen mit fromJson/toJson: Account, Balance, Asset, Subscription
│   ├── services/
│   │   ├── currency_service.dart # Frankfurter.app-Anbindung inkl. Cache-Fallback
│   │   ├── notification_service.dart # Dünner `local_notifier`-Wrapper für native OS-Benachrichtigungen
│   │   └── update_service.dart   # Manueller Update-Check gg. die GitHub-Releases-API (kein Auto-Updater)
│   ├── state/
│   │   └── app_state.dart        # Zentraler ChangeNotifier: CRUD-Fassade + berechnete Werte (Reminder, Summen) für die UI
│   ├── utils/
│   │   ├── analysis.dart         # Reine, UI-freie Berechnungen (Trend, Prognose, Anomalie-Check, Kennzahlen, Zeitraum-Filter) — unit-testbar
│   │   ├── csv_export.dart       # Reiner CSV-Builder für den Kontostände-Export (verlustbehaftet, kein Re-Import)
│   │   ├── formatting.dart       # Geld-/Prozent-/Datumsformatierung, Zahlen-Parsing, Perioden-Helper, Hex→Color
│   │   └── update_assets.dart    # Reine Update-Logik: Release-Asset je Plattform wählen, SHA256SUMS parsen,
│   │                             #   Digests vergleichen — netz- und dateisystemfrei, daher ausführbar spezifiziert
│   └── ui/
│       ├── navigation_shell.dart # Navigation-Shell: Top-Nav, In-App-"Datei"-Menü, Tastenkürzel-Wiring (→ backup_actions)
│       ├── backup_actions.dart   # Backup-Fluss: Export-/Import-/CSV-Datei-Dialoge, Sicherheitsabfrage, Snackbars
│       ├── app_view.dart         # enum AppView (die 6 Ansichten) + deutsche Labels
│       ├── splash_screen.dart    # Splash beim Start
│       ├── theme.dart            # Farb-Konstanten (Hell/Dunkel/System via `ThemeScope`), ThemeData, `noSelect()`-Helper
│       ├── views/                # Eine Datei pro Hauptansicht (siehe Tabelle unten)
│       └── widgets/               # Wiederverwendbare Bausteine (Charts, Dialoge, Banner, Formularelemente)
│                                  #   rate_consent_dialog.dart: Opt-in-Dialog + `resolveRate()` — der EINE Kursweg
│                                  #   für Einträge und Fixposten (Zustimmung → Abruf/Cache → manueller Kurs)
├── test/                         # Dart-Unit-/Widget-Tests, gespiegelt zu den Gherkin-Szenarien (siehe Abschnitt 8)
│   ├── support/gherkin_runner.dart # winziger, abhängigkeitsfreier Gherkin-Runner (führt @executable-Features aus)
│   └── bdd/                        # BDD-Testdateien: rufen runFeature(...) + registrieren Step-Defs gegen lib/

├── tool/generate_icons.dart       # Icon-Pipeline (ein Master-PNG → alle Plattform-Icon-Formate)
├── tool/generate_demo_data.dart   # buildDemoBackup() → demo/finanzgecko-demo.json (an "heute" verankert); auch von flutter test aufgerufen
├── tool/capture_screenshots.sh    # macOS-Helfer: nimmt die 7 Website-Screenshots je Theme in nativer Retina-Auflösung
│                                  #   auf (`screencapture -l <windowid>`, nur das App-Fenster) → build/screenshots/<theme>/
├── tool/generate_corporate_design_pdf.sh # CORPORATE_DESIGN.md → CORPORATE_DESIGN.pdf (pandoc → HTML → headless Chrome
│                                  #   Druck; nicht LaTeX, das verschluckt 🦎/→). Ausgabe ist Artefakt (.gitignore), nicht committen.
│                                  #   Stylesheet in tool/corporate_design_pdf.css.
├── demo/finanzgecko-demo.json     # importierbare Demodaten für Screenshots (generiert, .gitignore) — via "Backup importieren…"
├── packaging/linux/               # .desktop-Datei + install.sh fürs Linux-Startmenü, build_appimage.sh → FinanzGecko-<Version>-x86_64.AppImage
├── packaging/windows/             # finanzgecko.iss (Inno Setup) → FinanzGecko-<Version>-Setup.exe
├── packaging/macos/               # build_dmg.sh: signieren (Developer ID, Hardened Runtime) + notarisieren + DMG bauen
│                                  #   → FinanzGecko-<Version>-mac.dmg; ohne Zugangsdaten unsigniert statt Abbruch
│                                  # build_appstore.sh: sandboxed App-Store-Build (--dart-define=FINANZGECKO_MAS=true,
│                                  #   AppStore.entitlements, 3rd-Party-Mac-Developer-Zertifikate) → .pkg für
│                                  #   App Store Connect; bricht bei fehlender Signatur HART ab, anders als build_dmg.sh
├── linux/ macos/ windows/         # Native Flutter-Desktop-Runner (Boilerplate, i.d.R. nicht manuell editieren)
├── docs/                          # Statische Website (GitHub Pages, kein Build-Schritt, reines HTML/CSS)
│   ├── CNAME                      # Custom Domain: finanzgecko.app — **alle** absoluten URLs (canonical, og:url,
│   │                               #   og:image, twitter:image, sitemap.xml, robots.txt, llms.txt, README.md sowie
│   │                               #   `_downloadPageUrl` in lib/ui/views/settings_view.dart) zeigen auf diese Domain,
│   │                               #   nicht mehr auf kreativ-anders.github.io/finanzgecko
│   ├── index.html                 # Startseite: Hero, Testimonial, Screenshots, Features, Trust-Strip, Download/Unterstützen, FAQ
│   ├── download.html              # Download-Seite: ein Direktlink pro OS (Windows/macOS/Linux), s. u.,
│   │                               #   darunter die Sektion `.download-info` mit erklärendem Fließtext
│   │                               #   (Plattformwahl, Datenhaltung, Updates) — SEO-Mindestumfang, keine
│   │                               #   Installationsanweisungen (die bleiben allein in `#faq-install`)
│   ├── documentation.html         # Kurzanleitung für Endnutzer (kein Bezug zu AI_MASTER/gherkin)
│   ├── datenschutz.html           # Datenschutzerklärung (Pirsch, GitHub Pages, Stripe, GitHub-API, App-Netzwerkpfade),
│   │                               #   im Footer aller Seiten verlinkt — bei jeder neuen Drittanbieter-Einbindung nachziehen
│   ├── danke.html                 # Bestätigungsseite nach Stripe-Checkout ("Entwicklung unterstützen"), `noindex`,
│   │                               #   als "After payment"-Redirect im Stripe Payment Link zu hinterlegen —
│   │                               #   exakt https://finanzgecko.app/danke.html (die Redirect-URL lebt in Stripe,
│   │                               #   nicht im Repo, und wird von keinem Test erfasst: bei Domain-/Pfadwechsel
│   │                               #   dort **manuell** nachziehen)
│   ├── 404.html                    # GitHub Pages liefert diese Seite für jeden unbekannten Pfad aus, `noindex`.
│   │                               #   Nutzt als einzige Seite **root-absolute** Pfade (`/assets/…`, `/index.html`),
│   │                               #   da sie unter beliebig tiefen URLs gerendert wird — relative Pfade brächen dort.
│   │                               #   Meldet den angefragten Pfad per `window.pirschNotFound()` an Pirsch
│   └── assets/                    # style.css (teilt Farbtokens mit lib/ui/theme.dart; Hell/Dunkel via
│                                   #   prefers-color-scheme, Dunkel bleibt der Default), Icons, Screenshots
│       └── screenshots/           # je Ansicht vier Dateien: `{light,dark}-<name>.{png,webp}`. Die Seiten liefern
│                                   #   beide Themes per `<picture>` + `media="(prefers-color-scheme: light)"` aus;
│                                   #   Dunkel ist Default und `<img>`-Fallback. Neu aufnehmen: tool/capture_screenshots.sh
└── .github/
    ├── copilot-instructions.md    # ← die GitHub-Copilot-Pointer-Datei aus der Liste oben, hier weil der Pfad von
    │                               #   Copilot selbst vorgegeben ist, nicht frei wählbar
    └── workflows/
        └── release.yml         # einziger Workflow. Tag-Push (v*.*.*) ODER manuell (workflow_dispatch): erst
                                   #   `gate`-Job (analyze + test + Icon-Pipeline), dann 3 native Build-Jobs
                                   #   (ubuntu/macos/windows, `needs: gate`) → Release-Assets, danach `release`-Job
                                   #   (aktualisiert zusätzlich CHANGELOG.md, s. u.). Kein separater
                                   #   Push/PR-CI-Workflow — `flutter analyze`/`flutter test`/`dart format` laufen
                                   #   lokal vor dem Commit, nicht automatisiert bei jedem Push.
```

**Sprache der Doku:** Code, Kommentare, `README.md`, `CONTRIBUTING.md` und `dev/` sind auf Englisch.
`AI_MASTER.md` und `gherkin/` bleiben bewusst Deutsch (sie beschreiben eine deutschsprachige UI und nutzen die
verbindlichen Domänenbegriffe aus §7) — diese Begriffe (Konto, Fixposten, Vermögenswerte, …) werden **auch in
englischem Fließtext nicht übersetzt**, siehe §7 und "Regeln für KI-Agenten" #3.

### Die sechs Ansichten (`lib/ui/views/`)

| Datei | AppView | Deutsches Label | Kernzweck |
|---|---|---|---|
| `dashboard_view.dart` | `dashboard` | Dashboard | Übersicht: Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung über Zeit, Kennzahlen, Fixposten-/Vermögenswerte-Summary, Konto-Karten — alles über den Zeitraum-Filter gesteuert |
| `entries_view.dart` | `entries` | Einträge | Monatsbezogene Erfassung/Korrektur von Kontoständen für alle Konten auf einmal |
| `accounts_view.dart` | `accounts` | Konten | Konten anlegen/bearbeiten/archivieren/wiederherstellen |
| `subscriptions_view.dart` | `subscriptions` | Fixposten | Wiederkehrende Ein-/Ausgaben anlegen/bearbeiten/löschen |
| `assets_view.dart` | `assets` | Vermögenswerte | Sachwerte (kein Zeitverlauf) anlegen/inline bearbeiten/löschen |
| `settings_view.dart` | `settings` | Einstellungen | Basiswährung, Sicherheits-Info, Backup-Export/Import, CSV-Export, Hilfe (Version/System-Info/Support), Reset |

Navigation ist **kein Router**, sondern ein einfacher `enum`-Switch in `navigation_shell.dart` (`_content()`), gesteuert über
`ValueChanged<AppView> onNavigate`, das jede View nach oben durchreicht (z. B. für "Jetzt erfassen"-Buttons in
Bannern, die zu einer anderen View springen).

`onNavigate` trägt bewusst **keine Nutzlast**. Für den einen Sprung, der ein Ziel *innerhalb* der Zielansicht
braucht — Klick auf eine Dashboard-Konto-Karte → "Einträge", positioniert auf genau diesem Konto — gibt es deshalb
einen zweiten, schmalen Callback `onOpenAccountEntry` (`ValueChanged<int>`, nur `DashboardView`), der in der Shell
`_focusAccountId` setzt; `EntriesView` nimmt das als optionales `focusAccountId` entgegen (Autofokus auf dieser Zeile
statt auf der ersten, plus `Scrollable.ensureVisible`). Jede gewöhnliche Navigation über `_navigate` löscht
`_focusAccountId` wieder, damit eine spätere Rückkehr über die Navigationsleiste nicht erneut fokussiert. Diese
Aufteilung ist Absicht: `ValueChanged<AppView>` um einen optionalen Parameter zu erweitern, würde alle sechs Views
und `backup_actions.dart` anfassen, für genau einen Aufrufer.

## 4. Architektur & Datenfluss

```
AppStore (Persistenz, Verschlüsselung, Write-Queue)
   │  liest/schreibt
   ▼
AppSchema (In-Memory-Schema, JSON-Serialisierung)
   │  wird gekapselt von
   ▼
AppState extends ChangeNotifier (CRUD-Fassade + berechnete Werte)
   │  via provider (ChangeNotifierProvider.value)
   ▼
UI (Views/Widgets) — context.watch<AppState>() / context.read<AppState>()
```

Prinzip: **Jede mutierende Aktion in `AppState` ruft `store.xyz()` auf, lädt danach per `_reload()` alles neu ein und
ruft `notifyListeners()`** — kein manuelles Re-Fetch pro Route wie in einer klassischen SPA. Alle Views reagieren
automatisch über `Provider`.

### 4.1 Persistenz (`lib/data/app_store.dart`)

- **Eine Datei pro Installation**, kein DB-Server: `finanzgecko-data.json` im OS-Datenverzeichnis (`AppStore.resolveDataDirectory()`).
  - Linux: `~/.local/share/de.finanzgecko.app/` (oder `$XDG_DATA_HOME`)
  - macOS: `~/Library/Containers/de.finanzgecko.app/Data/Library/Application Support/FinanzGecko/`
    (Sandbox-Container ab v1.8; davor `~/Library/Application Support/de.finanzgecko.app/` — die Migration in
    §4.1 kopiert einmalig herüber). **Der Ordner heißt unter macOS bewusst `FinanzGecko`, nicht wie die
    Application-ID**: ein auf `.app` endender Ordnername gilt dem Finder als Programmbündel (generisches Icon,
    Art "Programm", Doppelklick meldet "beschädigt oder unvollständig"). Linux und Windows behalten
    `de.finanzgecko.app`, dort ist die Endung bedeutungslos und Reverse-DNS üblich.
  - Windows: `%APPDATA%\de.finanzgecko.app\`
- **Der Speicherort ist bewusst NICHT wählbar.** Ein Ordnerdialog wurde entworfen, gebaut und wieder entfernt: der
  einzige Grund, ihn zu wollen, ist "dann liegt meine Datei in einem Ordner, den die Cloud sichert" — und genau das
  leistet er nicht. Der Schlüssel liegt gerätegebunden im OS-Keychain; nach einem Plattenschaden oder auf einem
  neuen Rechner ist auch die schönste Cloud-Kopie nicht mehr zu öffnen (Ausnahme: vollständige Systemwiederher-
  stellung, die den Keychain mitbringt). Ein solcher Dialog würde also eine Sicherheit versprechen, die es nicht
  gibt. Wiederherstellbare Sicherungen laufen ausschließlich über den **Export** (s. u.). Die Begründung steht
  zusätzlich als Doc-Kommentar an `resolveDataDirectory()` und in Alltagssprache in Einstellungen → Sicherheit.
- **Verschlüsselung:** AES-256-GCM-"Envelope" (`{v, keyId, nonce, cipherText, mac}`, `_envelopeVersion = 1`).
  Schlüssel kommt aus `SecureKeyStore` (OS-Keychain), wird beim ersten Start pro Installation erzeugt.
- **`keyId` erkennt fremde Dateien** (8 Byte SHA-256 des Schlüssels, Klartext, `AppStore.keyFingerprint`). Ohne
  dieses Feld ist "Datei gehört zu einem anderen Rechner" nicht von "Datei ist kaputt" zu unterscheiden — beides
  scheitert beim Entschlüsseln — und die intakte fremde Datei liefe in Quarantäne + Leerstart. Passt `keyId` nicht,
  wirft der Store `ForeignKeyDataException`; die **muss** am `catch (_)` in `ensureInitialized()` vorbei
  (`on ForeignKeyDataException { rethrow; }`), sonst greift genau das Auffangnetz, das hier fatal wäre. `main()`
  zeigt dann `_ForeignDataApp` — es wird nichts verschoben und **nichts geschrieben**.
  **`v` bleibt bei 1**: `keyId` ist additiv, `_isEnvelope` prüft nur die vier bekannten Felder, ältere App-Versionen
  lesen neue Dateien also weiter. Ein Versionsbump hätte das gebrochen. Dateien ohne `keyId` (vor dem Feature
  geschrieben) nehmen unverändert den bisherigen Weg.
- **Der Export ist der einzige gerätunabhängige Weg** und bewusst vom Envelope der Datendatei getrennt
  (`lib/data/backup_crypto.dart`): sein Schlüssel wird per PBKDF2-HMAC-SHA256 aus einem **Passwort** abgeleitet,
  nicht aus dem OS-Keychain — deshalb lässt er sich auf jedem Rechner wieder einlesen. Das Passwort ist
  **optional**: ohne Passwort schreibt der Export weiterhin exakt das bisherige Klartext-JSON, damit bereits
  vorhandene Backups gültig bleiben. Der Import unterscheidet beide Formen an der Struktur (`isEncryptedBackup`),
  nicht an Endung oder Dateiname, und fragt nur bei geschützten Dateien nach. Die KDF-Parameter (Verfahren, Salt,
  Iterationen) stehen **in der Datei**, damit sie sich später anheben lassen, ohne alte Backups zu brechen.
  Im Export-Dialog ist "ohne Passwort" ein eigener Knopf statt "Feld leer lassen" — ein weggeklickter Dialog darf
  keinen ungeschützten Export erzeugen (`null` = abgebrochen vs. `''` = bewusst ohne).
- **Wechselkurs-Cache liegt bewusst NICHT in der verschlüsselten Datei**, sondern in einer eigenen Klartextdatei
  `finanzgecko-rates.json` daneben — öffentliche EZB-Referenzkurse sind kein Geheimnis, und so löst ein neu gecachter
  Kurs kein volles Re-Encrypt der ganzen DB aus. Migration: alte Stores mit `ratesCache` in der DB werden beim ersten
  Laden automatisch in die Standalone-Datei übernommen.
- **Atomare Writes:** immer temp-Datei schreiben → alte Datei löschen → temp-Datei umbenennen (gemeinsamer Helper
  `_atomicWrite`, genutzt von `_persistNow` und `_persistRatesNow`). Verhindert eine halb geschriebene Datei bei einem
  Crash mitten im Schreibvorgang.
- **Rollback bei fehlgeschlagenem Schreibvorgang:** Jede mutierende `AppStore`-Methode hält vor der Mutation den
  vorherigen Wert fest und stellt ihn wieder her, falls `_persist()`/`_persistRates()` wirft — Speicher und Disk
  laufen so nie unbemerkt auseinander. `resetAll()` und `importAllData()` legen zusätzlich **vorher** eine
  verschlüsselte Sicherung des alten Stands an (`pre-reset-backup-<Zeitstempel>.json` bzw.
  `pre-import-backup-<Zeitstempel>.json`, gemeinsamer Helper `_writeSnapshotBackup`) — die beiden einzigen
  Ein-Weg-Aktionen der App (siehe `gherkin/settings.feature` "Zurücksetzen" und `gherkin/backup_restore.feature`
  "Import").
- **Fehler aus `AppStore` tragen keinen deutschen UI-Text:** schlanke Exception-Typen (`RecordNotFoundException`,
  `UnsupportedBackupVersionException`, `AccountImportRejectedException`) transportieren nur Strukturdaten: welcher
  Datensatz fehlt, welche Schema-Version importiert wurde, welche Bank unbekannt war. Die deutsche
  Nutzertext-Formulierung passiert ausschließlich in `describeError()` (`ui/widgets/app_snackbar.dart`) — hält die
  Persistenzschicht sprachneutral, ohne dass sich die tatsächlich angezeigten Meldungen ändern.
- **Start-Absicherung:** Scheitert die Initialisierung in `main()` (z. B. kein OS-Keychain/Secret-Service verfügbar),
  zeigt die App statt eines stillen Crashs vor dem ersten Frame einen minimalen Fehlerbildschirm
  (`_StartupErrorApp`), der bewusst ohne `AppState`/`AppStore` auskommt — genau das, was gerade gescheitert sein
  könnte.
- **Serialisierte Write-Queue** (`_writeQueue`/`_enqueueWrite`): verhindert, dass zwei parallele Speicherungen sich
  auf derselben temporären Datei überschneiden. Ein fehlgeschlagener Write vergiftet nicht die Queue für später.
- **Unlesbare/fremde Dateien werden nie stillschweigend überschrieben** — sie werden zuerst unter
  `*.unreadable-<timestamp>` gesichert (`_quarantineFile(file, 'unreadable')`), erst danach startet die App mit
  Standardwerten.
- **Schema-Versionsschutz auf dem Ladepfad (nicht nur beim Import):** Beim Start prüft `ensureInitialized()` die
  `schemaVersion` der entschlüsselten Datendatei gegen `currentSchemaVersion`:
  - *Neuer als dieser Build* (Downgrade) → die Datei wird NICHT fehlertolerant eingelesen (das würde unbekannte
    Felder verwerfen und danach die einzige Kopie der Nutzerdaten lossy überschreiben), sondern unverändert unter
    `*.newer-version-<timestamp>` bewahrt (`_quarantineFile(file, 'newer-version')`); die App startet mit
    Standardwerten. Ein App-Update macht die Daten wieder lesbar. Spiegelt die Import-Prüfung
    (`UnsupportedBackupVersionException`) für den Alltags-Ladepfad, der bisher gar keinen Versions-Guard hatte.
  - *Älter als dieser Build* (Vorwärts-Migration) → zuerst eine byte-genaue Kopie der (bereits verschlüsselten) Datei
    als `pre-migrate-backup-<timestamp>.json` (`_writePreMigrationBackup`), dann wird das In-Memory-Schema auf
    `currentSchemaVersion` gestempelt und sofort neu geschrieben, damit Datei und Backup über Neustarts nicht
    auseinanderlaufen. Eine botchte Migration bleibt so wiederherstellbar.
- **Import erzwingt die Bank→Farbe-Regel:** In `importAllData` wird `account.color` über
  `resolveAccountColor(bank, tag)` (`constants.dart`) neu gesetzt — bekannte Bank → Markenfarbe, leere Bank
  (Bargeld/Krypto) → Kontotyp-Farbe. Eine unbekannte, nicht-leere Bank **bricht den gesamten Import ab** (kein
  stilles Einschleusen einer willkürlichen Farbe). Das spiegelt exakt die Regel des Konto-Formulars
  (`bankColorHex(bank) ?? tagColorHex(tag)` + Known-Bank-Validator).
- **`kBanks` ist eine von Hand gepflegte Liste** (`constants.dart`), gegliedert in Filialbanken (Sparkassen,
  Volks-/Raiffeisenbanken, Großbanken, Förderbanken), Direktbanken & Neobanken, Autobanken, Broker & Krypto,
  Kreditkarten-/Nischenbanken sowie die international gebräuchlichen Zahlungsdienste PayPal, Wise und Revolut —
  **keine** automatisch generierte oder vollständige Liste (Stand: ~43 Einträge, auch auf der Website unter
  `docs/index.html` FAQ "Welche Banken werden unterstützt?" dokumentiert — dort **manuell** in Sync zu halten, da
  die statische Seite `kBanks` nicht zur Build-Zeit einliest). Jede `colorHex` ist die **offizielle Markenfarbe**
  der Bank (aus Logo/Corporate Design/Brand-Kit), von Hand recherchiert, nicht algorithmisch abgeleitet — für
  Banken ohne verifizierbare offizielle Quelle bewusst **kein** Eintrag statt eines geratenen Hex-Werts. Fehlt eine
  Bank, wird sie über die im Konto-Formular verlinkten Kanäle vorgeschlagen (GitHub-Issue oder E-Mail, siehe
  `gherkin/accounts.feature`) und danach manuell als weiterer `Bank(name, colorHex)`-Eintrag ergänzt (dabei auch
  die FAQ-Liste auf der Website nachziehen).
- **Dateirechte als Defense-in-Depth:** `chmod 700`/`600` (Linux/macOS), `icacls` current-user-only (Windows) —
  zusätzlich zur Verschlüsselung, nicht als Ersatz dafür.
- **macOS-Spezifika (wichtig, nicht versehentlich rückgängig machen):**

  Seit der App-Store-Vorbereitung gibt es **zwei macOS-Auslieferungsformen**, unterschieden durch die
  Compile-Zeit-Konstante `kIsMacAppStore` (`lib/constants.dart`, `bool.fromEnvironment('FINANZGECKO_MAS')`,
  **Default `false`**). Alles Folgende gilt für den Standardfall — den DMG-Build, den jeder bestehende Nutzer
  installiert hat. Die Abweichungen des App-Store-Builds stehen jeweils darunter und sind **nur** über
  `packaging/macos/build_appstore.sh` erreichbar.

  - `SecureKeyStore` nutzt `MacOsOptions(usesDataProtectionKeychain: kIsMacAppStore)`.
    - **DMG-Build (`false`):** die klassische Keychain. Die Data-Protection-Variante bindet den Key an eine
      Team-ID-abgeleitete Access Group und verlangt ein `keychain-access-groups`-Entitlement; ein Build ohne
      dieses — inklusive jedes lokal ad-hoc-signierten `.app` — scheitert mit `-34018`. Dass inzwischen eine
      Developer ID existiert, ändert daran **nichts**: ein Umstellen würde den Key an anderer Stelle suchen und
      die Datendatei jedes bestehenden Nutzers unlesbar machen. Nicht umstellen.
    - **App-Store-Build (`true`):** die Data-Protection-Variante ist Pflicht, weil eine sandboxed App auf die
      klassische Keychain keinen Zugriff hat. Funktioniert dort, weil `AppStore.entitlements` die passende
      Access Group mitbringt; die Nutzer sind Neuinstallationen ohne Alt-Key.
  - **App-Sandbox ist seit v1.8 in ALLEN macOS-Builds aktiv** (`com.apple.security.app-sandbox = true` in
    `Release.entitlements`, `DebugProfile.entitlements` und `AppStore.entitlements`). Das ist eine **bewusste
    Umkehr** der bis v1.7 dokumentierten Entscheidung; die alte Begründung ("sonst virtualisiert macOS `$HOME`
    und `resolveDataDirectory()` schreibt am dokumentierten Pfad vorbei") war richtig, wird aber jetzt durch die
    einmalige Migration aufgelöst statt durch Vermeiden. Ziel ist genau **ein** macOS-Verhalten statt zweier.
    - `resolveDataDirectory()` braucht **keine** Fallunterscheidung: unter der Sandbox zeigt `$HOME` bereits auf
      `~/Library/Containers/de.finanzgecko.app/Data`, derselbe relative Pfad entsteht dort erneut. Der
      dokumentierte Pfad ist ab v1.8 der Container-Pfad.
    - **`lib/data/sandbox_migration.dart` ist der Preis dieser Umkehr.** Beim ersten Start eines sandboxed Builds
      liegt die Datendatei einer Bestandsinstallation noch unter dem echten Home. Die Migration **kopiert** sie
      in den Container — sie verschiebt nicht und löscht nichts. Zwei Regeln, die nicht verhandelbar sind:
      niemals überschreiben (Container gewinnt immer) und niemals das Original löschen (die einzige Rückfalloption,
      falls die Kopie subtil falsch war). Läuft in `ensureInitialized()` **vor** dem ersten Lesen der Datei.
    - Der Lesezugriff auf den alten Pfad kommt vom Entitlement
      `com.apple.security.temporary-exception.files.home-relative-path.read-write`, eng auf
      `/Library/Application Support/de.finanzgecko.app/` begrenzt. Es ist **übergangsweise**: sobald der alte Pfad
      nicht mehr gelesen wird, fliegt es raus (ROADMAP). Im App-Store-Build steht es bewusst nicht.
    - Die `chmod`-Härtung entfällt im App-Store-Build (`_chmod` steigt bei `kIsMacAppStore` sofort aus).
    - **Keychain-Frage: am 2026-08-13 empirisch geklärt — ja, es funktioniert.** Ein sandboxed, mit der Developer
      ID signierter Build liest den bestehenden Legacy-Keychain-Eintrag unverändert. Keychain-ACLs hängen an der
      Code-Signing-Identität, und die ändert die Sandbox nicht (gleiche Developer ID, gleiche Bundle ID). Deshalb
      migriert `SandboxMigration` bewusst **nur Dateien, keinen Schlüssel**.
      Getestet mit einer echten Bestandsinstallation: Datei-Hash im Container identisch zum alten Pfad, App zeigte
      alle Daten ohne Import. **Nicht in CI prüfbar** — bei einem Wechsel der Signatur-Identität (z. B. dem
      App-Store-Build, den Apple neu signiert) gilt das Ergebnis ausdrücklich **nicht** und ist neu zu prüfen.
  - Der In-App-Update-Weg (`UpdateService`, *Nach Updates suchen*) fehlt im App-Store-Build vollständig:
    App-Review-Richtlinie 2.4.5 verbietet den zweiten Update-Kanal, und der App Store aktualisiert selbst. Weil
    `kIsMacAppStore` `const` ist, entfernt der Tree-Shaker den Pfad aus dem Binary. Der Datenschutz-Absatz im
    Hilfe-Bereich verliert dort entsprechend seinen Satz zur GitHub-Releases-API (siehe
    `gherkin/settings.feature`).

### 4.2 Schema (`lib/data/app_schema.dart`)

`AppSchema` ist das komplette In-Memory-Abbild der JSON-Datei: `schemaVersion`, `baseCurrency`, Listen (`accounts`,
`balances`, `assets`, `subscriptions`), `ratesCache` (Legacy-Migrationspfad, s.o.), Auto-Increment-IDs
(`nextAccountId` etc.), `lastExportAt`, `window` (`WindowPrefs`), sowie das Reminder-Notification-Tracking
`notificationsEnabled`, `backupOverdueNotified`, `assetOverdueNotifiedIds` (episodenbasiert, siehe §4.4 und
`gherkin/notifications.feature`), sowie `themeMode` (`AppThemeMode`, Standard `system`, siehe §5
"Erscheinungsbild") und `rateFetchConsent` (`RateFetchConsent`, Standard `unset`, siehe §2 und
`gherkin/currency_exchange.feature`) — alles additive `meta`-Felder, kein `schemaVersion`-Bump nötig.
Bei `rateFetchConsent` ist das ausdrücklich beabsichtigt: ein fehlender Schlüssel (jede vor dem Feature
geschriebene Datei) ergibt `unset`, also **keine** angenommene Zustimmung — bestehende Installationen werden
einmalig gefragt statt stillschweigend übernommen. `fromDynamic()` ist **fehlertolerant pro Eintrag**:
eine kaputte Zeile in einer Liste wird übersprungen statt die ganze Datei unlesbar zu machen. `toExportJson()` ist
bewusst schlanker als `toJson()` (kein `ratesCache`/`meta`/`window` — internes Implementierungsdetail, nicht Teil
eines Backups) **und ohne `account.color`** (`Account.toExportJson`): die Farbe ist aus der Bank ableitbar und wird
beim Import über `resolveAccountColor` neu gesetzt — kleinere Backups, gehärteter Import.

`currentSchemaVersion = 1` — bei jeder inkompatiblen Schemaänderung hochzählen. Betroffen sind dann **zwei** Pfade:
(1) die Import-Prüfung in `AppStore.importAllData()` (lehnt Backups aus einer *neueren* Version ab, mit klarer
Fehlermeldung) und (2) der Start-Ladepfad in `ensureInitialized()` (Downgrade-Guard + automatische
`pre-migrate-backup`-Sicherung, s. §4.1). **Beim Hochzählen NICHT** die eingefrorene Golden-File-Fixture
`test/fixtures/backup_v1.json` ändern — stattdessen eine neue `backup_v<n>.json` + Test ergänzen, damit „eine neuere
App kann alte Daten nicht mehr lesen" in der CI auffällt, bevor es ausgeliefert wird.

### 4.3 Datenmodelle (`lib/models/`)

| Modell | Felder | Bemerkung |
|---|---|---|
| `Account` | `id, name, bank, tag, currency, color, archived, createdAt` | `tag` = Kontotyp (siehe `kTags`); `color` ist Hex-String (kein `Color`-Objekt, verlustfreier Round-Trip); Archivierung ist Soft-Delete |
| `Balance` | `id, accountId, period ("YYYY-MM"), amountOriginal, currencyOriginal, rate, amountBase, note, enteredAt` | Ein Eintrag pro Konto+Monat (upsert); `amountBase` = in Basiswährung umgerechnet, `rate` zum Zeitpunkt der Erfassung eingefroren |
| `Asset` | `id, name, value, createdAt, lastEvaluatedAt` | Sachwerte ohne Zeitreihe; `lastEvaluatedAt` wird bei jeder Wertänderung auf "jetzt" gesetzt (treibt die 6-Monats-Reminder-Logik) |
| `Subscription` | `id, name, interval, amountOriginal, currencyOriginal, rate, amountBase, createdAt` | Fixposten; Vorzeichen von `amountOriginal`/`amountBase` codiert Einnahme(+)/Ausgabe(−); `interval` ∈ `kSubscriptionIntervals` |
| `WindowPrefs` | `width, height, maximized` | Nur Größe + Maximiert-Status, bewusst **keine Bildschirmposition** (sonst Fenster nach Monitorwechsel außerhalb des sichtbaren Bereichs) |

### 4.4 `AppState` (`lib/state/app_state.dart`)

Zentrale Fassade für die UI. Zwei Kategorien von Methoden:
1. **CRUD** (`addAccount`, `upsertBalance`, `addAsset`, `addSubscription`, …) — delegieren an `store`, reloaden, notifyen.
2. **Berechnete Werte für die UI**, die aus Rohdaten abgeleitet werden (nicht persistiert):
   - `getBackupReminder()` — nie überfällig, solange die App komplett leer ist (keine Konten/Kontostände/
     Vermögenswerte/Fixposten — nichts erfasst heißt nichts zu sichern). Danach: wenn nie exportiert, überfällig
     `kBackupReminderFirstDays` (182, ~6 Monate) nach der frühesten erfassten Aktivität; nach dem ersten Export
     überfällig `kBackupReminderRepeatDays` (90, ~3 Monate) seit `lastExportAt`
   - `getAssetReminder()` — Liste überfälliger Vermögenswerte (> `kAssetReevaluationDays` = 182 Tage seit `lastEvaluatedAt`)
   - `getUpdateReminder()` — Nudge, wenn der neueste erfasste Monat älter als der aktuelle ist
   - `computeSubscriptionTotals()` — Einnahmen/Ausgaben/Netto, alle Fixposten auf Monatsäquivalent normiert
   - `previousBalance()` / `latestBalanceForAccount()` / `allPeriodsSorted()` / `balancesInPeriod()`

Zusätzlich prüft `_checkReminderNotifications()` (aufgerufen nach `init()` und nach jeder Mutation via
`_reloadAndNotify()`) den Backup- und den Vermögenswerte-Reminder und löst bei Bedarf eine native OS-Benachrichtigung
über `NotificationService` aus — **episodenbasiert** (einmal pro neu eintretender Überfälligkeit, nicht bei jedem
Check erneut), siehe §5 "Desktop-Benachrichtigungen" und `gherkin/notifications.feature`. Bewusst kein
`Timer.periodic`-Fallback für eine tagelang ununterbrochen offene, unbenutzte App-Sitzung — das wäre spekulatives
Verhalten für einen Randfall, den niemand angefragt hat, und ein nie gecancelter periodischer Timer verletzt
`flutter_test`s "kein Timer darf den Test überleben"-Invariante in Widget-Tests. Die Prüfung läuft stattdessen bei
jeder ohnehin stattfindenden Mutation/Reload sowie beim nächsten App-Start.

### 4.5 Reine Analyse-Funktionen (`lib/utils/analysis.dart`)

Bewusst **UI-frei und deterministisch** gehalten, damit sie ohne Flutter-Binding unit-testbar sind (`test/analysis_test.dart`):
- `monthsBetweenPeriods`, `monthsToYearEnd`, `addMonthsToPeriod` — Perioden-Arithmetik auf `"YYYY-MM"`-Strings
- `olsTrend` — allgemeiner OLS-Fit (Steigung + Achsenabschnitt) über beliebige (x, y)-Paare, x muss nicht lückenlos
  sein (eine Lücke zählt einfach als größerer Schritt) — z. B. von `AppLineChart` genutzt, dessen x-Achse Lücken
  (fehlende Monate) als echte Lücken statt komprimiert behandelt. `trendSlopePerMonth` ist der Spezialfall mit
  x = 0..n-1.
- `trendSlopePerMonth` — OLS-Steigung einer Zeitreihe (der statistische Trend fürs Dashboard)
- `projectionRate` — mischt Trend (primär) mit Fixposten-Netto als Prior, dessen Gewicht mit wachsender Historie
  (`trendPoints`) gegen 0 geht (`priorStrength = 3`). **Nicht** additiv — beide sind Schätzer derselben monatlichen Rate.
- `contributionMarketSplit` — zerlegt eine Vermögensänderung in "eingezahlt" (Fixposten-Netto × Monatsabstand) vs. "Markt/Sonstiges"
- `isBalanceAnomaly` — flags einen 10×-Sprung (typisches Tippfehler-Muster: Ziffer zu viel/zu wenig)
- `computeNetWorthStats` — Bester/schwächster Monat, Ø-Veränderung, Monate im Plus, Höchststand, Gesamtveränderung
  seit Start
- `periodsForRange` / `availableRanges` / `defaultRange` — der Dashboard-weite **Zeitraum-Filter** als reine Logik
  (`enum HistoryRange { ytd, twelveMonths, lastYear, all }`, `now` injizierbar für Tests). `availableRanges` blendet ein
  Preset aus, solange es dieselbe Menge wie "Alle" ergäbe (Dedup); `defaultRange` = "Dieses Jahr", sonst "Alle".

Reiner CSV-Export lebt in `lib/utils/csv_export.dart` (`buildBalancesCsv`): eine Zeile pro Konto+Monat, `;`-getrennt,
Dezimalkomma, RFC-4180-Quoting — bewusst verlustbehaftet und **ohne Re-Import** (der JSON-Backup-Pfad ist der einzige
verlustfreie Round-Trip). Getestet in `test/csv_export_test.dart`.

Bei jeder Änderung an diesen Formeln: `test/analysis_test.dart` **und** das zugehörige Gherkin-Feature aktualisieren.

## 5. UI-Konventionen

**Farbpalette, Markenfarben-Regeln, Typografie, App-Icon — designer-lesbar:** siehe
[`CORPORATE_DESIGN.md`](CORPORATE_DESIGN.md), bewusst kompakt und ohne Code-Bezug gehalten (Zielgruppe: Design,
Marketing, externe Gestaltung). Die technische Umsetzung dieser Tokens (Getter-Mechanik, Kontrast-Fallbacks,
Sync-Pflichten mit `theme.dart`/`constants.dart`) steht stattdessen hier im nächsten Unterabschnitt. Der Rest von
Abschnitt 5 deckt Interaktionsmuster und Verhalten ab (Navigation, Dialoge, Formate, Benachrichtigungen, Charts,
Splash).

### Farbtoken — technische Umsetzung

- **Nur vier Tokens sind pro Theme unterschiedlich:** `kBackground`, `kSurface`, `kBorder`, `kMuted` sowie
  `kTextPrimary` (volltoniger Lesetext auf `kBackground`/`kSurface`, z. B. Splash-Screen, Chart-Tooltips,
  Monatsauswahl — ersetzt die früheren fest verdrahteten `Colors.white`-Stellen), alle in `lib/ui/theme.dart`. Alle
  anderen Farben — `kPrimary` (`#00C878`), `kDanger` (`#FF6B6B`), `kWarning` (`#E0A030`),
  `kTrendUp/Down/Neutral` — sind **bewusst in beiden Themes identisch** (Markenfarben, keine Neuinterpretation).
  Diese vier dynamischen Tokens (plus `kTextPrimary`) sind top-level **Getter** (kein `const` mehr), die den
  zuletzt von `ThemeScope` aufgelösten `Brightness`-Wert lesen — `ThemeScope` sitzt in `main.dart` oberhalb von
  `MaterialApp` (innerhalb eines `Consumer<AppState>`, das bei jedem `setThemeMode()` neu baut) und löst
  `AppThemeMode.system` gegen `MediaQuery.platformBrightnessOf(context)` auf. Jede Stelle, die einen dieser Tokens
  referenziert, darf deshalb **nicht** `const` sein (der Dart-Compiler bricht mit "Invalid constant value" ab,
  falls doch — verlässlicher Marker beim Reviewen). Diese Hex-Werte sind mit `kPrimaryHex`/`kDangerHex` in
  `constants.dart` synchron zu halten (String-Form fürs on-disk Kontofarben-Feld vs. `Color`-Form fürs Theme).
  **Noch offen:** eigene Hell/Dunkel-Varianten fürs Taskleisten-/Dock-Icon (aktuell ein einziges Icon für beide
  Themes, siehe Icon-Pipeline in §6).
- **`kPrimaryText`/`kDangerText`/`kWarningText`** (`lib/ui/theme.dart`, gleiches Getter-Muster wie oben): WCAG-2.1-AA-
  sichere Varianten von `kPrimary`/`kDanger`/`kWarning` für den Einsatz als **Text-/Icon-Farbe** (statt als Fläche/
  Chart-Linie/Button-Hintergrund). `kPrimary` & Co. bleiben als Marken-/Füllfarbe bewusst themenidentisch (s. o.) —
  als Textfarbe auf dem hellen Theme unterschreiten sie aber alle drei die 4,5:1-Mindestkontrastvorgabe (~2,0–2,8:1
  gegen `kBackground`/`kSurface` hell). Die `*Text`-Getter geben im Dark Theme exakt die Original-Konstante zurück
  (dort bereits ≥6,9:1) und nur im Light Theme eine dunklere, farbtongleiche Variante (`#00814D`/`#BA4E4E`/`#936920`,
  alle ≥4,5:1 gegen `#F4F7F5`/`#FFFFFF`). Regel: **jede Stelle, an der eine der drei Markenfarben eine Textzeile,
  ein alleinstehendes Icon-Glyph oder einen Fokus-/Rahmenindikator (`InputDecorationTheme.focusedBorder`) färbt,
  nutzt die `*Text`-Variante** — Flächen/Fills (Button-/Chip-Hintergrund, `AppLineChart`-Linienfarbe, farbige
  Badges mit dunklem Text obendrauf) bleiben bei der Original-Konstante. Ausnahme: der Marken-Schriftzug
  "🦎 FinanzGecko" im Kopfbereich (`navigation_shell.dart`) bleibt `kPrimary`, da Logos/Markennamen laut WCAG 1.4.3
  von der Kontrastvorgabe ausgenommen sind. **Dieselbe Regel gilt für `docs/assets/style.css`**, das die Tokens der
  App spiegelt: dort trat der Fehler bereits einmal auf — die per JS hervorgehobene Download-Karte
  (`.download-card-primary`) bekam `border-color: var(--primary)` und war auf dem hellen Theme mit 2,2:1 gegen
  `--surface` unsichtbar, während das Badge darüber (`--primary-text`, 4,9:1) korrekt erschien. Zweiter Fall,
  gefunden im Qualitäts-Audit (§9): `.card.warn` färbte seinen linken Rahmenindikator mit `--danger` (2,6:1 gegen
  `--bg` hell). Deshalb gibt es in `style.css` jetzt — analog zur App — auch ein `--danger-text` (`#FF6B6B` dunkel /
  `#BA4E4E` hell, spiegelt `kDangerText`); `--danger` bleibt als Markenfarbe stehen, ist aktuell aber nirgends mehr
  referenziert. **Dritter Fall, gleiche Ursache, August 2026:** die neue `.download-note` (Backup-Empfehlung auf
  `download.html`) bekam ihren linken Rahmenindikator zunächst mit `--primary` — 2,2:1 gegen `--surface` hell,
  während `.card.note` direkt darunter in derselben Datei längst `--primary-text` verwendet. Dass die Regel hier
  dreimal gleich verletzt wurde, obwohl sie dokumentiert ist, ist der eigentliche Befund: **beim Anlegen eines
  neuen Rahmen-/Fokusindikators zuerst nach einem bestehenden `border-left: 3px solid var(--*-text)` greifen**
  statt zur Markenfarbe. Flächen und Fills bleiben unverändert bei `--primary`/`--danger`.
- **Bankfarben sind Logofarben, keine Textfarben.** `kBanks` enthält u. a. `#000000` (Trade Republic, C24,
  Mercedes-Benz Bank) und `#ffe600` (comdirect) — als Fläche oder 10px-Punkt unproblematisch, als Beschriftung auf
  `kSurface` unlesbar (bis herunter zu 1,06:1). Wo eine Kontofarbe **Text** einfärbt (aktuell der Kontotyp-Chip auf
  den Dashboard-Konto-Karten), läuft sie deshalb durch `readableOn(hex, kSurfaceHex)` aus `constants.dart`: eine
  reine Hex-zu-Hex-Funktion, die in 2%-Schritten Richtung Weiß bzw. Schwarz mischt, bis 4,5:1 erreicht sind, und
  sonst unverändert durchreicht. Die Chip-**Fläche** behält bewusst die ungefilterte Markenfarbe (15% Deckkraft) —
  Hintergründe haben keine Kontrastvorgabe, und sie ist es, die den Chip nach der Bank aussehen lässt. 51 der 96
  Kombinationen (48 Farben × 2 Themes) brauchen die Korrektur; dass **alle** konvergieren, sichert ein Szenario in
  `gherkin/executable/account_color.feature` ab.

- **Kein natives Menü** unter Linux/Windows (Flutters `PlatformMenuBar` nur macOS) → In-App-"Datei"-Bereich im
  Fensterkopf, plattformübergreifend identisch, plus globale Tastenkürzel (`Strg`/`⌘`+E/I/Q) via `CallbackShortcuts`.
- **Geld-/Zahlenformat:** immer über `fmtMoney`/`fmtPercent`/`fmtInputNumber`/`parseInputNumber` aus `formatting.dart`
  — deutsches Format (`de_DE`, Komma als Dezimaltrennzeichen), akzeptiert beim Parsen aber auch die alte
  Punkt-Notation rückwärtskompatibel.
- **`noSelect()`-Helper** (`theme.dart`) schließt Button-Labels/Nav-Chrome von der App-weiten `SelectionArea` aus
  (in `main.dart`) — nur Inhaltstext soll markierbar/kopierbar sein. **Das ist zugleich Voraussetzung für den
  richtigen Mauszeiger:** die `SelectionArea` legt über jeden selektierbaren `Text` einen Text-Cursor, und der sitzt
  *tiefer* im Baum als der Klick-Cursor des umschließenden `InkWell`/`TextButton` — bei Gleichstand gewinnt der
  tiefere, der Zeiger wird also nie zur Hand. Regel: **jedes anklickbare Element, dessen Label ein `Text` ist, wickelt
  dieses Label in `noSelect(...)`** (Buttons, Nav-Einträge, klickbare Karten, `ListTile`-Vorschläge). Ein explizites
  `mouseCursor` ist dann nicht nötig — Material-Buttons und `InkWell` fordern den Klick-Cursor bereits selbst an.
  Elemente ohne Textkind (`IconButton`, `Switch`) sind davon nie betroffen; Eingabefelder behalten korrekt den
  Text-Cursor, und die Hover-Charts (`line_chart.dart`, `stacked_area_chart.dart`) bleiben bewusst beim
  Standard-Zeiger, da sie nichts auslösen, sondern nur einen Tooltip zeigen.
- **Bestätigungsdialoge:** einfache Ja/Nein (`AlertDialog`) für reversible-ish Aktionen (Archivieren, Löschen); für
  die **einzige echte "Point of no return"-Aktion** (App zurücksetzen) eine **getippte Bestätigungsphrase**
  (`ZURÜCKSETZEN`, `reset_confirm_dialog.dart`) statt eines simplen Klicks.
- **Inline-Edit mit Debounce** (600 ms, `Timer`) bei Vermögenswerten und Fixposten — kein explizites "Speichern"
  nötig, speichert automatisch beim Tippstopp/Fokusverlust/Enter.
- **Reminder/Banner-Reihenfolge im Dashboard** (`dashboard_view.dart`): Update-Reminder → Overspend-Banner (nur wenn
  Fixposten-Netto negativ) → Backup-Reminder → Asset-Reminder. Diese Reihenfolge ist bewusst (Dringlichkeit).
- **Desktop-Benachrichtigungen** (Einstellungen → "Benachrichtigungen", standardmäßig aktiv): spiegeln Backup- und
  Asset-Reminder zusätzlich als native OS-Notification, damit man sie auch sieht, wenn das Dashboard gerade nicht
  offen ist. Feuert **episodenbasiert genau einmal** pro neu eintretender Überfälligkeit (nicht bei jedem App-Start
  erneut) und **nur, während die App läuft** — kein Hintergrunddienst, siehe §6 und `gherkin/notifications.feature`.
- **Maus-Hover auf allen drei Dashboard-Charts** (`AppLineChart`, `AppDonutChart`, `AppStackedAreaChart`, alle in
  `lib/ui/widgets/`): Verlauf und Zusammensetzung über Zeit zeigen eine senkrechte Hilfslinie + Tooltip (Periode, je
  Serie Farbpunkt/Name/Betrag, bei der Zusammensetzung zusätzlich der Anteil in %), von Hand gebaut über
  `MouseRegion`/`setState` statt über fl_charts eigenes Touch-System — letzteres verlor bei kontinuierlicher
  x-Position (Zeitreihen) nachweislich unvorhersehbar den Hover-Zustand zwischen benachbarten Positionen. Die
  Verteilungs-Donut nutzt dagegen bewusst fl_charts eigenes `PieTouchData`: dort ist die Touch-Auflösung ein
  diskreter "welches Segment"-Treffertest ohne die Positions-Interpolation, die beim Liniendiagramm das Problem war;
  gehovertes Segment wächst leicht, Kontotyp + Anteil erscheinen im leeren Innenkreis. Tooltip-Zeilen mit
  unterschiedlich langen Labels bekommen für Betrag/Anteil je eine **feste, rechtsbündige Spaltenbreite** statt
  eines bloßen Texts nach einem `Expanded`-Label — Letzteres erzeugt einen von Zeile zu Zeile unterschiedlich
  breiten (optisch unruhigen) Abstand vor der Zahl.
- **Lesbare Zeilenbreite:** Fließtext in einer Dashboard-Karte (z. B. der Fremdwährungs-Rundungshinweis) wird auf
  eine feste `maxWidth` begrenzt (`ConstrainedBox`), statt über die volle, auf breiten Fenstern sehr lange
  Karten-/Dashboard-Breite (bis zu 1100px, siehe `navigation_shell.dart`) zu laufen.
- **Splash-Dauer (1100ms Standzeit + 400ms Überblendung, `splash_screen.dart`)** ist eine bewusste Marken-, keine
  Lade-Entscheidung: `main()` ruft `windowManager.show()` **vor** `runApp()`, das Fenster ist also bereits (leer, in
  `kBackground`) sichtbar, bevor der Splash überhaupt erscheint — beide Werte kommen zu dieser Init-Zeit hinzu, der
  Start wirkt insgesamt ~1,5s lang gebrandet. Eine Verkürzung würde den Start spürbar reaktionsschneller machen;
  genau das wurde geprüft (Issue #11) und verworfen. Werte daher nicht ohne Rücksprache ändern.

## 6. Plattform-Besonderheiten (siehe auch [dev/setup.md](dev/setup.md) und [dev/building.md](dev/building.md) für Details)

- Cross-Platform-Builds sind **nicht möglich** — jede Plattform muss auf ihrem eigenen OS gebaut werden; alle drei
  gleichzeitig nur über GitHub Actions (`.github/workflows/release.yml`, per Tag-Push `v*.*.*` oder manuell über
  `workflow_dispatch`). Vor den Build-Jobs läuft ein `gate`-Job (analyze + test + Icon-Pipeline); schlägt er fehl,
  wird kein Bundle gebaut/released. Es gibt bewusst keinen separaten Push/PR-CI-Workflow — `flutter analyze`,
  `flutter test` und `dart format` laufen lokal vor jedem Commit (siehe CLAUDE.md "Always verify"), release.yml ist
  der einzige GitHub-Workflow im Repo.
  **Die `if:`-Bedingungen der Build-Jobs müssen mit `!cancelled() &&` beginnen** — nicht kosmetisch: `bump-version`
  wird bei einem Tag-Push und bei "bump: none" bewusst übersprungen, und GitHub überspringt per Default alles, was
  via `needs` an einem übersprungenen Job hängt. Diese Vererbung schaltet sich erst ab, sobald die Bedingung eine
  Status-Check-Funktion enthält; das ebenfalls vorhandene `needs.bump-version.result == 'skipped'` genügt **nicht**,
  obwohl es sich richtig liest. Ohne `!cancelled()` liefen weder Ad-hoc-Testbuilds noch Tag-Push-Releases (Weg A),
  sondern nur der Weg über den Bump-Knopf (Weg B) — der Lauf wurde dabei komplett grün gemeldet, nur ohne einen
  einzigen gebauten Job. Nicht "aufräumen".
- **Splash-Logo je Theme** (`assets/logo/`): zwei Dateien mit identischem Zuschnitt (je 512×333, aus
  `kreativ-anders/static-assets` übernommen). **Die Namen bezeichnen die Bildfarbe, nicht das Theme** —
  `kreativ-anders-light-512.png` ist das *helle* Logo (weiße Schrift) und gehört auf den **dunklen** Grund,
  `kreativ-anders-dark-512.png` das *dunkle* (schwarze Schrift) auf den **hellen**. `splash_screen.dart` wählt über
  `kIsDarkTheme` (`theme.dart`). Vorher lief das helle Logo in beiden Themes und erreichte auf Hell nur 1,3:1 —
  praktisch unsichtbar; jetzt 13,7:1 bzw. 6,4:1. Die Zuordnung sieht auf den ersten Blick vertauscht aus, ist es
  aber nicht: nicht "geradeziehen".
- Icon-Pipeline: ein einziger 1024×1024-Master (`assets/icon/icon.png`) speist alle Plattform-Formate über
  `dart run tool/generate_icons.dart` — `flutter_launcher_icons` nur noch für macOS (`pubspec.yaml`,
  `windows.generate: false`); Windows-`.ico` und Linux-Hicolor-Icons baut `tool/generate_icons.dart` selbst
  (`generateWindowsIcon`/`generateLinuxIcons`, beide reine Funktionen, auch von `flutter test` ausgeführt). Grund:
  `flutter_launcher_icons`' eigener Windows-Generator schreibt nur eine einzige 256px-Größe ins `.ico`
  (`icon_size`-Konfig), was Explorer/Taskleiste/Startmenü nach der Installation ohne Icon lässt statt
  herunterzuskalieren — `generateWindowsIcon` erzeugt stattdessen ein echtes Multi-Size-`.ico` (16–256px).
- Release-Artefakte sind **fertige Pakete statt roher Bundle-Ordner** (die Testnutzer verwirrten und beim Löschen
  einzelner Dateien den Start brachen): Windows → Inno-Setup-Installer `FinanzGecko-<Version>-Setup.exe`
  (`packaging/windows/finanzgecko.iss`, gebaut mit `iscc` im `windows`-Job), Linux → einzelnes ausführbares AppImage
  `FinanzGecko-<Version>-x86_64.AppImage` (`packaging/linux/build_appimage.sh` via `appimagetool`), macOS → Disk-Image
  `FinanzGecko-<Version>-mac.dmg` (`hdiutil`-Schritt im `macos`-Job, Image = `FinanzGecko.app` + Symlink auf
  `/Applications`). Die Version wird in jedem
  Build-Job aus `pubspec.yaml` gelesen (nicht aus dem Git-Tag), damit auch ungetaggte Ad-hoc-Testbuilds
  (`workflow_dispatch`, `bump: none`) einen versionierten Dateinamen bekommen. `packaging/linux/install.sh` bleibt als
  Alternative fürs Linux-Startmenü aus einem entpackten Bundle bestehen.
- **macOS: DMG statt gezipptem `.app`-Bundle** (seit August 2026). Zwei Gründe, der zweite ist der eigentliche:
  Erstens ist "Image öffnen, App auf `Programme` ziehen" der auf macOS gewohnte Ablauf — beim ZIP landete das
  Bundle im Download-Ordner und wurde oft von dort gestartet. Zweitens kann ein DMG das Notarisierungs-Ticket
  tragen (`xcrun stapler staple`), ein ZIP nicht: dessen Ticket müsste Gatekeeper beim ersten Start online bei
  Apple nachschlagen. Die Umstellung ist deshalb Voraussetzung für die geplante Signierung/Notarisierung (siehe
  [ROADMAP.md](ROADMAP.md)) und wurde bewusst *vorher* gemacht, damit der Dateiname sich nicht zweimal ändert.
  `hdiutil` statt `create-dmg`: auf jedem macOS-Runner vorhanden, keine zusätzliche Abhängigkeit.
- **Signieren/Notarisieren läuft über `packaging/macos/build_dmg.sh`** — ein Skript für lokal *und* CI (wie
  `packaging/linux/build_appimage.sh`), damit der von Hand getestete Build und der CI-Build nicht auseinanderlaufen.
  Es signiert inside-out (erst eingebettete `.dylib`s, dann jedes Framework, zuletzt das Bundle; bewusst **kein**
  `--deep`, das ist von Apple nicht für Distribution vorgesehen), mit Hardened Runtime (`--options runtime`, Pflicht
  für die Notarisierung) und `--timestamp`. Entitlements bekommt nur das äußere Bundle.
  **Notarisiert wird zweimal**: einmal ein ZIP der App, um das Ticket per `stapler` *in die App* zu heften, und
  einmal das fertige DMG. Nur das DMG zu stapeln genügt nicht — die herausgezogene App trüge dann selbst kein
  Ticket und Gatekeeper müsste beim ersten Start online nachfragen, was der DMG-Weg ja gerade vermeiden soll.
  Fehlen Identität oder Zugangsdaten, baut das Skript ein **unsigniertes** DMG und warnt, statt abzubrechen:
  Forks und Ad-hoc-Testbuilds haben keine Secrets, und ein harter Fehler würde dort die atomare Release-Kette
  blockieren. `SIGN_IDENTITY` ist absichtlich nur der Teilstring `Developer ID Application` (codesign löst das auf,
  solange genau eine Identität passt) — kein Name und keine Team-ID im Repo.
  Jeder `codesign`-Aufruf läuft über eine `retry`-Funktion (5 Versuche, wachsende Pause). Das ist **kein**
  vorsorglicher Zierrat: `--timestamp` ist pro Signatur ein Netzaufruf an Apples Zeitstempel-Dienst, der
  gelegentlich nicht antwortet; codesign meldet das als `errSecInternalComponent` und bricht ab, derselbe Aufruf
  läuft Sekunden später unverändert durch (genau so beim ersten lokalen Signaturlauf passiert). Nicht entfernen.
- **Prüfsummen:** der `release`-Job legt zusätzlich ein `SHA256SUMS` über die drei Plattform-Pakete als
  Release-Asset ab und schreibt dieselben Hashes in den Release-Text (`body_path`). Das ist die eine erlaubte
  Ausnahme zur Regel unten — kein Binär-Duplikat, sondern eine Textdatei im Standardformat von `sha256sum -c`.
  `sha256sum FinanzGecko-*` statt `sha256sum *`: die Shell legt die Zieldatei durch die Umleitung an, *bevor* der
  Befehl läuft, ein `*` würde also die noch leere `SHA256SUMS` mit sich selbst hashen. Für
  `docs/download.html` ist die Datei unkritisch: die Asset-Auflösung matcht per `data-asset-suffix`, und
  `SHA256SUMS` trägt keines davon.
- **Keine unversionierten Alias-Assets:** jedes Release trägt pro Plattform genau **eine** Binärdatei (den
  versionierten Namen). Ein früherer Ansatz lud zusätzlich eine byte-identische unversionierte Kopie hoch
  (`cp`/`Copy-Item` vor dem jeweiligen `upload-artifact`-Schritt), damit `docs/download.html` fest auf
  `.../releases/latest/download/<fester Name>` verlinken konnte — das verdoppelte aber Upload und Asset-Liste pro
  Release für reine Duplikate. Bleibt abgeschafft.
- **`docs/download.html` löst das konkrete Asset clientseitig auf** (Progressive Enhancement, seit August 2026).
  Ausgeliefert werden drei gleichwertige Karten, deren `href` statisch auf `.../releases/latest` zeigt — genau der
  Stand, der ohne JavaScript, ohne Netz und bei API-Rate-Limit stehen bleibt. Ein Skript am Seitenende ergänzt
  darauf zwei unabhängige Verbesserungen:
  1. **OS-Erkennung** (`navigator.userAgentData.platform`, Fallback `navigator.platform`/User-Agent): die passende
     Karte rückt per `grid.insertBefore` nach vorn und bekommt `.download-card-primary` + ein „Für dein System
     erkannt“-Badge. Die anderen beiden bleiben **gleich groß und sichtbar** — eine Fehlerkennung darf niemanden
     vom richtigen Download abschneiden. Deshalb bewusst *kein* einzelner großer Button. Mobile UAs (iOS/Android)
     werden absichtlich nicht erkannt: es gibt keine mobile Version, dort bleiben alle drei Karten gleichwertig.
  2. **Asset-Auflösung** über `api.github.com/repos/.../releases/latest`: pro Karte wird das Asset per
     `data-asset-suffix` (`-Setup.exe`, `-mac.dmg`, `-x86_64.AppImage`) gematcht, der Button auf dessen
     `browser_download_url` gesetzt und Version + Dateigröße in `.download-meta` eingeblendet. Findet sich kein
     passendes Asset (etwa weil ein Plattform-Build im Release fehlgeschlagen ist), bleibt für **diese** Karte der
     Fallback-Link stehen.

  Grund für die Kehrtwende gegenüber der früheren „keine JS-/GitHub-API-Aufrufe auf der statischen Seite“-Regel:
  alle drei Buttons endeten auf derselben Release-Seite, wo Nutzer:innen aus fünf Assets (drei Binaries + zwei
  Source-Archive) das richtige heraussuchen mussten — für die Zielgruppe die größte Hürde der ganzen Seite. Die
  Regel war ohnehin schon durchbrochen, weil `docs/index.html` dieselbe API für den Sterne-Zähler abfragt.
  **Die Suffixe sind an die Artefaktnamen aus `release.yml` gekoppelt** — ändert sich dort ein Dateiname, müssen
  die `data-asset-suffix`-Attribute mitgezogen werden, sonst fällt die Seite still auf die Release-Seite zurück
  (kein sichtbarer Fehler, deshalb leicht zu übersehen). Jeder neue Netzwerkaufruf der Website gehört zusätzlich
  in `docs/datenschutz.html`.
- **Website unter eigener Domain `finanzgecko.app`** (GitHub Pages + `docs/CNAME`). Absolute URLs gehören konsequent
  auf diese Domain — `kreativ-anders.github.io/finanzgecko` darf nirgends mehr auftauchen (GitHub redirectet zwar,
  aber ein `canonical`/`og:url` auf den alten Host spaltet SEO- und Analytics-Signale auf zwei Hostnames).
- **Reichweitenmessung mit Pirsch Analytics** (`<script defer src="https://api.pirsch.io/pa.js" id="pianjs"
  data-code="…">` im `<head>` **jeder** Seite unter `docs/`, neue Seiten nicht vergessen). Bewusst gewählt, weil
  cookiefrei, ohne IP-Speicherung und in Deutschland gehostet: damit kein Cookie-Banner und keine Einwilligung nach
  § 25 TDDDG nötig, was zum Datenschutz-Versprechen des Produkts passt. Das gilt **nur für die Website** — die App
  selbst sendet weiterhin **keine** Telemetrie; diese Trennung in `docs/index.html`, `docs/llms.txt` und
  `docs/datenschutz.html` sauber halten. Jede weitere Drittanbieter-Einbindung muss in `docs/datenschutz.html`
  ergänzt werden.
- **Kein automatischer/silenter Auto-Updater — aber ein geprüfter Download auf Klick** (geändert im August 2026;
  die frühere Fassung schloss auch den Download aus, Begründung war das fehlende Signaturzertifikat. Das gilt für
  macOS nicht mehr, für Windows schon — siehe [ROADMAP.md](ROADMAP.md)). Unverändert bleibt das Entscheidende:
  **jeder** Netzaufruf passiert, weil geklickt wurde. Kein Start-Check, kein periodischer Check, kein
  Hintergrund-Download. Ablauf über `UpdateService` (`lib/services/update_service.dart`):
  1. Einstellungen → Hilfe → "Nach Updates suchen" holt den neuesten Release-Tag
     (`api.github.com/repos/kreativ-anders/finanzgecko/releases/latest`) und vergleicht ihn gegen `PackageInfo`.
     **bereits aktuell** und **fehlgeschlagen** (offline, GitHub down, Rate-Limit) bleiben Snackbars, Letztere mit
     generischem "bitte später erneut versuchen" statt eines Fehlerdialogs. **Neue Version verfügbar** ist bewusst
     ein `AlertDialog` (handlungsrelevant, darf nicht von selbst verschwinden), mit "Später" und "Herunterladen".
  2. Erst auf "Herunterladen": Speicherort-Dialog (`getSaveLocation`) — **kein** stilles Ablegen in `~/Downloads`,
     das löst unter macOS eine eigene TCC-Abfrage "Zugriff auf den Ordner Downloads" aus, die bei dieser App
     besonders unpassend wirkt. Vorgeschlagen wird das Asset zur laufenden Plattform
     (`selectAssetName`, `lib/utils/update_assets.dart`).
  3. Download, dann Vergleich gegen `SHA256SUMS` aus demselben Release. **Geschrieben wird erst nach bestandener
     Prüfung** — eine ungeprüfte Datei darf nie im Zielordner liegen und installierbar aussehen.
  4. Danach ein Dialog mit dem plattformabhängigen nächsten Schritt und "Im Ordner zeigen".
     Die App **führt die Datei nicht aus** und ersetzt sich nicht selbst: unter Windows hieße "Installer starten",
     eine frisch heruntergeladene ausführbare Datei zu starten. Der Hinweis, FinanzGecko vorher zu **beenden**,
     steht einmal für alle Plattformen im Dialog (vorher je Plattform formuliert — und unter Linux prompt
     vergessen), gespiegelt im Update-FAQ auf `docs/index.html` inklusive dessen JSON-LD-Kopie.
  Was die Prüfsumme belegt und was nicht: `SHA256SUMS` kommt über HTTPS, ist aber **nicht signiert**. Ein Treffer
  zeigt, dass die Datei unverändert ankam und zu diesem Release gehört — er ist **kein** Echtheitsnachweis. Der
  kommt unter macOS aus der Notarisierung, die das Betriebssystem beim Start ohnehin prüft. UI-Texte entsprechend
  "geprüft" formulieren, nicht "verifiziert/echt". Fehlt dem Release die Datei für diese Plattform oder die
  `SHA256SUMS` (ältere Releases), wird **nichts geraten**, sondern `docs/download.html` geöffnet.
- **`CHANGELOG.md`** wird ausschließlich vom `release`-Job in `release.yml` gepflegt: bei jedem tatsächlichen Release
  (Tag-Push oder Version-Bump-Dispatch, nicht bei einem reinen Testbuild mit `bump: none`) wird ein Abschnitt mit den
  Commit-Messages seit dem vorherigen Tag oben angehängt und direkt nach `main` gepusht. Bewusst **kein** eigener
  Push/PR-Workflow dafür — das würde die obige "ein einziger Workflow"-Entscheidung aufweichen.

## 7. Domänen-Glossar (verbindlich)

Diese deutschen Begriffe sind **Teil der Spezifikation**, nicht nur UI-Text — bei Regenerierung/Erweiterung exakt so
verwenden (auch in Variablennamen wo sinnvoll, siehe z. B. `kTags`, "Fixposten" im Code-Kommentar):

| Deutscher Begriff | Bedeutung im Code |
|---|---|
| Konto / Konten | `Account` |
| Kontotyp | `Account.tag` (Girokonto, Tagesgeld, Depot, Bargeld, Krypto — `kTags`) |
| Kontostand | `Balance` (ein Eintrag pro Konto+Monat) |
| Einträge (Ansicht) | Erfassen/Korrigieren von Kontoständen für einen Monat, alle Konten auf einmal |
| Vermögenswerte / Sachwerte | `Asset` (Elektronik, Möbel, Fahrzeuge — kein Zeitverlauf) |
| Fixposten | `Subscription` (wiederkehrende Ein-/Ausgabe: Gehalt, Miete, Abos, Dividenden) |
| Basiswährung | `AppState.baseCurrency` — Zielwährung aller Dashboard-Summen |
| Gesamtvermögen | Summe aller Kontostände (optional inkl. Vermögenswerte) im aktuellsten erfassten Monat |
| Verlauf | Zeitreihen-Chart des Gesamtvermögens über die Zeit, inkl. Prognose |
| Zusammensetzung über Zeit | Gestapeltes Flächendiagramm: Vermögen nach Kontotyp über alle Monate |
| Verteilung nach Kontotyp | Donut-Chart für einen einzelnen Monat |
| Kennzahlen | Gesamtveränderung, bester/schwächster Monat, Ø-Veränderung, Monate im Plus, Höchststand |
| Zeitraum(-Filter) | Dashboard-weiter Zeitfenster-Filter ("Dieses Jahr" / "12 Monate" / "Letztes Jahr" / "Alle"), steuert alle zeitbasierten Karten |
| Backup exportieren/importieren | Klartext-JSON-Export/Import über native Dateidialoge (verlustfreier Round-Trip) |
| CSV-Export | Verlustbehafteter Tabellen-Export der Kontostände (kein Re-Import) |

## 8. Tests ↔ Gherkin-Zuordnung

### Feature-Übersicht (Navigations-Index)

Alle Verhaltensspezifikationen auf einen Blick — Einstieg für eine KI, um vom Verhalten zur Quelle zu springen
(jede Feature-Datei nennt ihre `# Quelle:`). `test/gherkin_sync_test.dart` erzwingt, dass jede Datei hier auftaucht.

| Feature | Kurz | Status |
|---|---|---|
| `gherkin/dashboard.feature` | Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung, Kennzahlen, Banner, Konto-Karten, Zeitraum-Filter | Unit (`analysis_test`, `app_state_test`) |
| `gherkin/balances_entries.feature` | Monatsweise Kontostand-Erfassung/Korrektur, verwaiste Balances | Unit (`entries_view_orphan_test`, `app_state_test`) |
| `gherkin/accounts.feature` | Konten anlegen/bearbeiten/archivieren; Bank→Farbe | Unit (`account_color_test`, `app_store_ops_test`) |
| `gherkin/subscriptions.feature` | Fixposten CRUD, Monatsäquivalent | Unit (`app_state_test`, `app_store_ops_test`) |
| `gherkin/assets.feature` | Vermögenswerte CRUD, 6-Monats-Reminder | Unit (`app_store_ops_test`) |
| `gherkin/settings.feature` | Basiswährung, Sicherheit, Backup-Export/Import, CSV-Export, Hilfe (Version/System-Info/Support), Reset | Unit (`csv_export_test`) |
| `gherkin/notifications.feature` | OS-Benachrichtigungen für Backup-/Asset-Reminder, episodenbasiert, Ein-/Ausschalten | Unit (`app_state_test`, `app_store_ops_test`) |
| `gherkin/backup_restore.feature` | Export/Import (JSON), Schemaprüfung, Bank→Farbe-Import, Fehlertoleranz | Unit (`app_store_ops_test`, `backup_hardening_test`) |
| `gherkin/data_security.feature` | AES-256-GCM, OS-Keychain, Quarantäne, Schema-Parsing | Unit (`app_schema_test`, `app_store_encryption_test`) |
| `gherkin/currency_exchange.feature` | Opt-in zum Kursabruf (`RateFetchConsent`), Wechselkurse (frankfurter.dev), Cache, Offline-Fallback, manueller Kurs | `test/rate_consent_test.dart` (nur das Gate + Cache-Pfad, ohne Netz); der HTTP-Aufruf selbst bleibt UI/Integration |
| `gherkin/window.feature` | Fenstergröße/Maximiert-Status, Standard-/Mindestgröße, Splash | nur UI/Integration (kein Unit-Test) |
| `gherkin/navigation.feature` | Top-Navigation (6 Ansichten), Banner-Sprünge, In-App-Datei-Menü, Tastenkürzel, Textauswahl | nur UI/Integration (kein Unit-Test) |
| `gherkin/executable/account_color.feature` | resolveAccountColor-Regeln | **ausführbar** (`test/bdd/account_color_bdd_test.dart`) |
| `gherkin/executable/net_worth_projection.feature` | Trend/Prognose/Kennzahlen/Anomalie | **ausführbar** (`test/bdd/analysis_bdd_test.dart`) |
| `gherkin/executable/update_assets.feature` | Release-Asset je Plattform, SHA256SUMS parsen, Digest-Vergleich | **ausführbar** (`test/bdd/update_assets_bdd_test.dart`) |

### Regenerierung eines Features (1 Feature → 1 Primär-Datei)

Jede Feature-Datei nennt im Kopf zwei Pfad-Header:
- **`# Implementierung:`** — die **eine** Datei, die das Feature primär umsetzt und das **Regenerierungsziel** ist
  (die `*_view.dart` einer Ansicht, das Fassaden-File bei Infrastruktur-Features, oder das reine Modul bei
  ausführbaren Features).
- **`# Quelle:`** — **alle** berührten Dateien: die Primär-Datei **plus** geteilte Infrastruktur.

**Rezept „Feature X neu erzeugen":** die `# Implementierung:`-Datei löschen/neu schreiben; Vertrag sind die
Szenarien der Feature-Datei **und** ihr Test (via Tabelle unten bzw. `grep "// Gherkin: <feature>"`). Die übrigen
`# Quelle:`-Dateien sind **fixer, geteilter Kontext** — lesen und höchstens um den Feature-Slice erweitern, nicht als
Ganzes neu erzeugen.

**Warum nicht strikt 1:1 für alles:** Die Fassaden `app_state.dart` (State) und `app_store.dart` (Persistenz) werden
bewusst von je ~6 Features geteilt (Schichtenarchitektur, Abschnitt 4 — eine einzige verschlüsselte JSON-Datei, keine
Pro-Feature-Duplizierung); sie sind nie das alleinige Ausgabe-File eines Features. **Echtes 1:1** gibt es bei den
**ausführbaren** Features (`analysis.dart`, `resolveAccountColor` in `constants.dart`): dort ist das Verhalten durch
Feature + Step-Defs vollständig festgezurrt — die Primär-Datei lässt sich löschen und allein aus Spec + BDD-Tests neu
erzeugen. Neues rein-fachliches Verhalten deshalb bevorzugt dort ansiedeln.

Wo zwei Features sonst dieselbe Primär-Datei beanspruchen würden, wird bewusst getrennt: der reine Backup-Fluss
(Datei-Dialoge, Sicherheitsabfrage, Snackbars) liegt in `backup_actions.dart` (Primär von `backup_restore`), während
`navigation_shell.dart` nur noch Navigations-Shell ist (Primär von `navigation`) und die Kürzel/Menü-Einträge lediglich an
`backup_actions` weiterreicht. Die eigentliche Persistenz/Schemaprüfung bleibt in `app_store.dart` (geteilter
`# Quelle:`-Kontext, siehe oben).

`test/gherkin_sync_test.dart` (Invariante 5) erzwingt: jede Feature-Datei hat eine `# Implementierung:`, die existiert
und in `# Quelle:` gelistet ist.

### Testdateien

| Testdatei | Deckt ab | Zugehöriges Feature |
|---|---|---|
| `test/analysis_test.dart` | Reine Berechnungen (Trend, Prognose, Anomalie, Kennzahlen) | `gherkin/dashboard.feature` |
| `test/app_schema_test.dart` | Schema-Parsing, Fehlertoleranz, Export-Shape | `gherkin/data_security.feature` |
| `test/app_state_test.dart` | AppState-CRUD & abgeleitete Werte (Reminder, Summen) | mehrere Features |
| `test/app_store_encryption_test.dart` | Envelope-Verschlüsselung, Quarantäne unlesbarer Dateien | `gherkin/data_security.feature` |
| `test/app_store_ops_test.dart` | Store-CRUD, Export/Import, Schema-Versionsprüfung, Import-Bank→Farbe-Regel | `gherkin/backup_restore.feature` |
| `test/account_color_test.dart` | `resolveAccountColor` (bekannte Bank → Markenfarbe, leer → Kontotyp, unbekannt → Fehler) | `gherkin/accounts.feature`, `gherkin/backup_restore.feature` |
| `test/backup_hardening_test.dart` | Backup-Export→Import-Round-Trip & Fehlertoleranz (AppSchema-Ebene) | `gherkin/backup_restore.feature` |
| `test/csv_export_test.dart` | CSV-Export (Trennzeichen, Dezimalkomma, Sortierung, Quoting) | `gherkin/settings.feature` |
| `test/update_service_test.dart` | Manueller Update-Check gg. gemockte GitHub-Releases-API: neuere/gleiche/ältere Version, HTTP-Fehler, Netzwerkfehler, unerwartete Antwortform — nie eine Exception nach außen | `gherkin/settings.feature` |
| `test/tooling_test.dart` | **Regeneriert beim Testlauf** die Demodaten (`buildDemoBackup` → `demo/…json`) und die Linux-Hicolor-Icons (`generateLinuxIcons`) und validiert sie (Schema, Referenzen, Domänenwerte, Icon-Größen) | Dev-Tooling (kein Feature) |
| `test/entries_view_orphan_test.dart` | Verwaiste Balances archivierter Konten | `gherkin/balances_entries.feature` |
| `test/formatting_test.dart` | Zahlen-/Geldformatierung, Parsing | quer über alle Features (nicht-funktional) |
| `test/gherkin_sync_test.dart` | **Verdrahtet Gherkin ↔ Code/Tests** (s. u.): `# Quelle:`-Pfade existieren, `// Gherkin:`-Marker zeigen auf echte Features, Coverage-Allow-List | alle `gherkin/**/*.feature` (Meta) |
| `test/bdd/account_color_bdd_test.dart` | **Führt** `gherkin/executable/account_color.feature` aus (Runner) gegen `resolveAccountColor` | `gherkin/executable/account_color.feature` |
| `test/bdd/analysis_bdd_test.dart` | **Führt** `gherkin/executable/net_worth_projection.feature` aus gegen `analysis.dart` | `gherkin/executable/net_worth_projection.feature` |
| `test/bdd/update_assets_bdd_test.dart` | **Führt** `gherkin/executable/update_assets.feature` aus gegen `update_assets.dart` | `gherkin/executable/update_assets.feature` |

**Regel:** Wird ein Gherkin-Szenario ergänzt, das ein neues Verhalten beschreibt, sollte nach Möglichkeit ein
korrespondierender Dart-Test entstehen (oder zumindest ein TODO-Kommentar mit Verweis auf das Szenario), damit
Spezifikation und automatisierte Prüfung nicht auseinanderlaufen.

**Verdrahtung Gherkin ↔ Tests (erzwungen, nicht nur Konvention):** `test/gherkin_sync_test.dart` läuft im normalen
`flutter test` (und damit im `gate`-Job von release.yml) und lässt die Pipeline **fehlschlagen**, sobald Spec, Code und
Tests auseinanderlaufen:
1. Jede `gherkin/*.feature` braucht einen `# Quelle:`-Header, dessen Quellcode-Pfade alle existieren.
2. Ein Test verlinkt das/die Feature(s), das/die er abdeckt, mit einer Kopfzeile `// Gherkin: gherkin/<x>.feature`
   (mehrere kommagetrennt). Jeder Marker muss auf eine existierende Feature-Datei zeigen.
3. Genau die im Test hinterlegte Allow-List (`featuresWithoutUnitTest`, aktuell `window` + `navigation`)
   darf ohne Unit-Test sein — jede Abweichung (neues ungetestetes Feature, oder ein jetzt
   getestetes Feature) bricht den Testlauf ab und erzwingt entweder einen Test-Marker oder eine bewusste Anpassung
   der Allow-List. So bleibt `gherkin/` kein isoliertes Doku-Silo, sondern hängt am Testlauf.
4. Jede Feature-Datei ist in AI_MASTER.md indexiert (Feature-Übersicht).
5. Jede Feature-Datei hat eine `# Implementierung:` (Regenerierungsziel), die existiert und in `# Quelle:` steht
   (siehe „Regenerierung eines Features" oben).

### Zwei Sorten Features — deklarativ vs. ausführbar

- **Deklarative Features** (`gherkin/*.feature`): beschreiben UI-/Integrationsverhalten in Prosa. Sie werden durch
  gewöhnliche Dart-Tests + den Sync-Guard oben abgesichert, aber nicht Zeile für Zeile ausgeführt.
- **Ausführbare Features** (`gherkin/executable/*.feature`, Tag `@executable`): werden **tatsächlich Schritt für
  Schritt ausgeführt** von einem winzigen, abhängigkeitsfreien Runner (`test/support/gherkin_runner.dart`). Jedes
  ausführbare Feature hat eine BDD-Testdatei in `test/bdd/`, die `runFeature(pfad, (s) { s.step(regex, body); … })`
  aufruft; die Step-Bodies rufen echten `lib/`-Code auf. Dadurch ist die Kette **Szenario → Step-Def → Quellfunktion**
  greifbar und greppbar (jede BDD-Datei nennt ihre `// Quelle:`).

**So fügt man ein ausführbares Szenario hinzu** (bewusst knapp, damit eine KI zielgenau editiert): (1) Szenario in
`gherkin/executable/<x>.feature` ergänzen; (2) fehlt ein Schritt, in `test/bdd/<x>_bdd_test.dart` ein `s.step(regex,
body)` mit dünnem Aufruf der `lib/`-Funktion registrieren. Runner unterstützt bewusst nur Feature/Background/Rule/
Scenario + Given/When/Then/And/But (keine Scenario Outline / Tabellen) — Fälle als einzelne Scenarios ausschreiben.

**Bewusste Entscheidung — kein `flutter_gherkin`:** Der Runner ist absichtlich ein eigener ~90-Zeilen-Parser statt
des Pakets `flutter_gherkin`. Begründung: null Zusatz-Abhängigkeit, läuft nativ im normalen `flutter test` (und damit
im Release-Gate), leicht von einer KI les-/erweiterbar. `flutter_gherkin` ist auf UI-/e2e-Integrationstests
(`integration_test`) ausgelegt und wäre für reine Domänenlogik Overhead. **Nicht ohne Rücksprache durch das Paket
ersetzen** (vgl. Regel 5 unten).

## 9. Qualitäts-Audit (wiederkehrende Aufgabe)

Es gibt bewusst **keinen** automatisierten CI-Schritt dafür (kein Push/PR-Workflow, siehe Abschnitt 6) — dieses
Audit ist eine **manuell/auf Zuruf ausgelöste** Aufgabe für eine KI, sinnvoll etwa vor einem größeren Release oder
wenn länger nicht mehr durchgeführt. Ziel ist ein **Befund-Report**, keine automatischen Breaking Changes — Umsetzung
konkreter Fixes ist ein eigener, danach mit dem Menschen abgestimmter Schritt.

Drei Teilbereiche, jeweils mit klarem Scope:

1. **Usability & Accessibility der UI** — sowohl der Flutter-Desktop-App (`lib/ui/views/`, `lib/ui/widgets/`,
   `lib/ui/theme.dart`) als auch der Landingpage (`docs/index.html`, `docs/download.html`,
   `docs/documentation.html`, `docs/danke.html`, `docs/assets/style.css`). Prüfpunkte u. a.: Kontraste (siehe
   `kPrimaryText`/`kDangerText`/`kWarningText`-Regel in §5 "Farbtoken — technische Umsetzung" — WCAG 2.1 AA, 4,5:1), Tastaturbedienbarkeit,
   Fokus-Reihenfolge/-sichtbarkeit, Screenreader-Semantik (`Semantics`-Widgets, `alt`-Texte, Landmark-Tags/`aria-*`
   auf der statischen Seite), Lesbarkeit (Zeilenbreite, Schriftgrößen), Konsistenz der Interaktionsmuster
   (Bestätigungsdialoge, Inline-Edit-Debounce, Hover/Tooltip-Verhalten, siehe Abschnitt 5).
2. **SEO-Analyse der Website** (`docs/`) — Meta-Tags/Title/Description, strukturierte Daten, `docs/sitemap.xml` +
   `docs/robots.txt` + `docs/llms.txt` (vorhanden, auf Aktualität/Vollständigkeit prüfen), Open-Graph-/Twitter-Card-
   Tags (`docs/assets/og-image.png`), Heading-Hierarchie, interne Verlinkung, Ladezeit-relevante Faktoren (Asset-
   Größen unter `docs/assets/`, Blocking Resources), sowie Marketing-/Conversion-Aspekte der statischen Seite:
   Call-to-Actions (Download, "Entwicklung unterstützen"), Trust-Signale, Above-the-fold-Klarheit des Pitches.
3. **Code-Optimierung ohne Breaking Changes** — schlanke Muster, Performance, Stabilität/Robustheit in `lib/`:
   unnötige Rebuilds/`setState`, fehlende `const`-Konstruktoren (Ausnahme: die vier dynamischen Theme-Token, siehe
   `CORPORATE_DESIGN.md`), Duplikation, ungenutzter Code, potenzielle Nullpointer-/Edge-Cases in `lib/utils/analysis.dart` und
   den Persistenzpfaden (Abschnitt 4.1), fehlende Fehlerbehandlung an System-Boundaries (Datei-I/O, Netzwerk). Jeder
   vorgeschlagene Fix muss die bestehenden Tests (`flutter analyze` + `flutter test`, inkl. `gherkin_sync_test.dart`)
   weiter grün halten und darf **keine** der in Regel 5 gelisteten Architekturentscheidungen antasten.

**Output — kein separates Report-Artefakt, direkt beheben statt nur auflisten:** Befunde werden **nicht** in eine
separate Report-Datei/ein Artefakt geschrieben, sondern kompakt im Chat zusammengefasst. Für jeden Befund gilt:
- **Kein UI-/UX-Verhaltenswechsel, keine Breaking Changes, kein neuer/fehlender Inhalt nötig** (Tippfehler, tote
  Links, fehlende Meta-Tags, Farb-/Kontrast-Bugs die einen bereits etablierten Fix nur konsequent nachziehen,
  reine Performance-/Duplikations-Refactorings ohne Verhaltensänderung, additive A11y-Semantik ohne visuelle
  Änderung) → **direkt beheben**, ohne Rückfrage. Danach `flutter analyze` + `flutter test` grün halten (Pflicht).
- **Ändert sichtbares Verhalten, Interaktionsmuster, Copy/Design-Entscheidung oder braucht Inhalte/Credentials, die
  nur der Mensch hat** (z. B. eine echte Stripe-Payment-Link-URL, ein neues Testimonial, eine neue Light-Theme-
  Variante der Website, ein neuer visueller Sättigungs-/Lade-Indikator) → **nicht selbst entscheiden**, sondern im
  Chat kurz als offenen Punkt benennen und dem Menschen zur Entscheidung vorlegen.
- Am Ende **kurze Zusammenfassung im Chat**: was direkt behoben wurde (mit Datei:Zeile), was offen bleibt und warum.
  Kein Artefakt, keine neue Datei nur für den Report — dieses Dokument (§9) ist die einzige dauerhafte Spur des
  Audit-Prozesses, nicht seiner Einzelbefunde.

Ergibt der Audit einen Bedarf an Doku-/Gherkin-Änderungen (z. B. ein neues A11y-Kriterium), gilt dafür regulär
Regel 1 unten.

---

## Regeln für KI-Agenten (PFLICHTLEKTÜRE)

Diese Regeln gelten für **jede KI**, die an diesem Repository arbeitet — egal ob zur Weiterentwicklung der
bestehenden App oder zur Regenerierung einer neuen Instanz aus diesen Dokumenten heraus.

1. **Dieses Dokument, `CORPORATE_DESIGN.md` und `gherkin/` sind Pflichtteil jeder Änderung, nicht optional.**
   Ändert sich durch einen Task die Ordnerstruktur, die Architektur, ein Datenmodell, eine Konstante mit fachlicher
   Bedeutung (z. B. `kBackupReminderFirstDays`) oder das Verhalten einer View → **im selben Arbeitsschritt**:
   - Abschnitt 3 (Ordnerstruktur) aktualisieren, falls Dateien/Ordner hinzukamen/wegfielen.
   - Abschnitt 4/5 (Architektur/UI-Konventionen) aktualisieren, falls sich Datenfluss, Schema oder Konventionen ändern.
   - `CORPORATE_DESIGN.md` aktualisieren, falls sich eine Farbe, ein Farb-Token oder die Typografie ändern.
   - Das passende `.feature`-File in `gherkin/` um das neue/geänderte Szenario ergänzen oder korrigieren.
   - Bei neuem deutschen Fachbegriff: Abschnitt 7 (Glossar) ergänzen.
   - Ändert sich eine der **nicht verhandelbaren Regeln** (aktuell: deutsche Domänensprache, Architekturentscheidungen
     nicht ohne Rücksprache rückgängig machen, Doku-Sync-Pflicht, `flutter analyze`/`flutter test` nach jeder
     Änderung) → denselben Abschnitt "Non-negotiable rules" in **allen** KI-Pointer-Dateien nachziehen (aktuell
     `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md` — Liste siehe Abschnitt 3). Neues Tool mit eigener
     Konvention dazugekommen? Gleiche Pointer-Datei ergänzen und dort in Abschnitt 3 eintragen.
   Eine Änderung an Produktionscode **ohne** begleitendes Doku-Update gilt als unvollständig.

2. **Kein stillschweigendes Verwerfen von Anforderungen.** Wird eine bestehende Gherkin-Regel durch eine Änderung
   ungültig, das Szenario explizit anpassen/entfernen und begründen (z. B. im Commit/PR) — nicht einfach
   liegen lassen, während der Code schon etwas anderes tut.

3. **Deutsche Domänensprache ist verbindlich**, nicht kosmetisch (siehe Glossar). Ein regenerierendes Modell darf
   Begriffe wie "Fixposten", "Kontotyp" oder "Vermögenswerte" **nicht** durch naheliegende englische oder
   allgemeinere deutsche Alternativen ersetzen — das würde die "nahezu identische" Regenerierung brechen, die der
   Zweck dieses Dokuments ist.

4. **Designtokens (Farben, Abstände, Schwellwerte) exakt übernehmen**, nicht neu interpretieren — sie stehen in
   `constants.dart`/`theme.dart` und sind in `CORPORATE_DESIGN.md` (Farben) bzw. hier in Abschnitt 5/7 (übrige
   Tokens) dokumentiert. Beispiel: `kConcentrationRiskThreshold = 0.65`, `kAssetReevaluationDays = 182`,
   `kBackupReminderFirstDays = 182`, `kBackupReminderRepeatDays = 90` sind fachliche Entscheidungen, keine
   beliebigen Defaults.

5. **Architekturentscheidungen mit dokumentierter Begründung nicht ohne Rücksprache rückgängig machen**, u. a.:
   - Wechselkurs-Cache in eigener unverschlüsselter Datei (nicht in der DB) — Abschnitt 4.1.
   - `usesDataProtectionKeychain: false` auf macOS — Abschnitt 4.1.
   - App-Sandbox deaktiviert auf macOS — Abschnitt 4.1.
   - Fensterposition wird bewusst nicht gespeichert — Abschnitt 4.3.
   - Splash-Dauer 1100ms + 400ms Überblendung — Abschnitt 5.
   - **Kein wählbarer Speicherort für die Datendatei** — Abschnitt 4.1. Wurde einmal gebaut und bewusst wieder
     entfernt; wer ihn erneut vorschlägt, sollte zuerst dort nachlesen, warum er den Anwendungsfall nicht löst.
   - Export-Passwort ist optional, ohne Passwort bleibt es beim bisherigen Klartext-JSON — Abschnitt 4.1.
   - **Kein automatisches Backup.** Wurde durchgerechnet und verworfen: es bräuchte eine Ableitung des Schlüssels
     pro Sitzung, ein gespeichertes Passwort, eine Versionshaltung, eine Gesundheitsüberwachung *und* einen Umbau
     der bestehenden Reminder-Rangfolge — und seine typische Fehlerart (still gescheitert) merkt man erst, wenn man
     das Backup braucht. Stattdessen führt die vorhandene Backup-Erinnerung zum manuellen Export und erklärt dabei
     die zwei Dinge, auf die es ankommt: außerhalb dieses Rechners aufbewahren, und nur das Backup ist übertragbar
     (`AppState.getBackupReminder`).
   - Keine DB-Engine, eine einzige JSON-Datei — Abschnitt 2.
   - Schema-Versionsschutz auf dem Start-Ladepfad (Downgrade-Guard + `pre-migrate-backup` + Golden-File-Fixture) —
     Abschnitt 4.1/4.2. Die Datendatei ist die einzige Quelle der Wahrheit; kein neuer Build darf bestehende Daten
     unlesbar machen oder verlustbehaftet überschreiben.
   - Eigener Gherkin-Runner statt `flutter_gherkin` — Abschnitt 8.
   Diese Punkte tauchen typischerweise auch als Kommentar im Code auf; wer den Kommentar entfernt, muss auch hier
   den entsprechenden Absatz anpassen (oder umgekehrt).

6. **Neue fachliche Anforderungen zuerst als Gherkin-Szenario formulieren**, dann implementieren (Spec-first), wo
   praktikabel — mindestens aber **spätestens im selben Schritt wie die Implementierung**, nie danach "irgendwann".

7. **Reihenfolge für eine komplette Neu-Generierung** (z. B. mit einem anderen KI-Modell von Null): Datenmodelle
   (`lib/models/`) → `AppSchema`/`AppStore` (Persistenz+Verschlüsselung) → `CurrencyService` → `AppState` →
   `theme.dart`/`constants.dart` → Widgets (`lib/ui/widgets/`) → Views (`lib/ui/views/`) → `navigation_shell.dart` →
   `main.dart`. Jede Stufe gegen das jeweilige `gherkin/*.feature` verifizieren, bevor die nächste beginnt.

8. **Nicht-funktionale Anforderungen nie vergessen**, auch wenn sie in keinem einzelnen Gherkin-Szenario explizit
   auftauchen: rein lokal (kein automatisches Netzwerk außer Wechselkurs-API; die GitHub-Releases-Abfrage für
   "Nach Updates suchen" ist die einzige Ausnahme und läuft ausschließlich auf explizite Nutzeraktion), Verschlüsselung
   ruht auf OS-Keychain, atomare Schreibvorgänge, Offline-Fallback für Kurse, keine stillschweigende Datenvernichtung
   bei kaputten/fremden Dateien (immer quarantänen statt überschreiben).

9. **Bei Unklarheit zwischen Code und Doku gilt: nachfragen bzw. beides angleichen, nicht raten.** Weicht der
   aktuelle Code von diesem Dokument ab, ist das ein Zeichen, dass die Doku beim letzten Change vergessen wurde —
   nicht, dass der Code automatisch recht hat.
