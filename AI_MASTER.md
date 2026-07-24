# FinanzGecko — AI Master Spec

**Zweck dieses Dokuments:** Dies ist die zentrale Referenz, damit eine KI (dieses oder ein anderes Modell) die App
**FinanzGecko nahezu identisch nachbauen oder konsistent weiterentwickeln kann** — ohne den bisherigen Chatverlauf zu
kennen. Zusammen mit den fachlichen Spezifikationen in [`gherkin/`](gherkin/) ist dies die "Source of Truth" für
Architektur, Konventionen, Domänensprache und Verhalten der App.

> **Pflicht für jede KI, die an diesem Repo arbeitet:** siehe Abschnitt ["Regeln für KI-Agenten"](#regeln-für-ki-agenten-pflichtlektüre)
> ganz unten — insbesondere die Pflicht, dieses Dokument und `gherkin/` bei jeder Änderung synchron zu halten.

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
Einzige *automatische* externe Netzwerkabhängigkeit: `api.frankfurter.dev` für Wechselkurse (mit Cache-Fallback, App
bleibt offline nutzbar). Zusätzlich fragt "Nach Updates suchen" (Einstellungen → Hilfe) auf explizite Nutzeraktion
hin die öffentliche GitHub-Releases-API ab (`UpdateService`, Abschnitt 6) — kein Hintergrund-Check, kein Auto-Update.

## 3. Ordnerstruktur

```
finanzgecko/
├── AI_MASTER.md                  # ← dieses Dokument
├── CHANGELOG.md                  # generiert vom release-Job in release.yml (Commits seit letztem Tag, oben angehängt) — nicht von Hand pflegen
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
│   │   └── secure_key_store.dart # AES-Schlüssel im OS-Keychain (flutter_secure_storage)
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
│   │   └── formatting.dart       # Geld-/Prozent-/Datumsformatierung, Zahlen-Parsing, Perioden-Helper, Hex→Color
│   └── ui/
│       ├── navigation_shell.dart # Navigation-Shell: Top-Nav, In-App-"Datei"-Menü, Tastenkürzel-Wiring (→ backup_actions)
│       ├── backup_actions.dart   # Backup-Fluss: Export-/Import-/CSV-Datei-Dialoge, Sicherheitsabfrage, Snackbars
│       ├── app_view.dart         # enum AppView (die 6 Ansichten) + deutsche Labels
│       ├── splash_screen.dart    # Splash beim Start
│       ├── theme.dart            # Farb-Konstanten (Hell/Dunkel/System via `ThemeScope`), ThemeData, `noSelect()`-Helper
│       ├── views/                # Eine Datei pro Hauptansicht (siehe Tabelle unten)
│       └── widgets/               # Wiederverwendbare Bausteine (Charts, Dialoge, Banner, Formularelemente)
├── test/                         # Dart-Unit-/Widget-Tests, gespiegelt zu den Gherkin-Szenarien (siehe Abschnitt 8)
│   ├── support/gherkin_runner.dart # winziger, abhängigkeitsfreier Gherkin-Runner (führt @executable-Features aus)
│   └── bdd/                        # BDD-Testdateien: rufen runFeature(...) + registrieren Step-Defs gegen lib/

├── tool/generate_icons.dart       # Icon-Pipeline (ein Master-PNG → alle Plattform-Icon-Formate)
├── tool/generate_demo_data.dart   # buildDemoBackup() → demo/finanzgecko-demo.json (an "heute" verankert); auch von flutter test aufgerufen
├── demo/finanzgecko-demo.json     # importierbare Demodaten für Screenshots (generiert, .gitignore) — via "Backup importieren…"
├── packaging/linux/               # .desktop-Datei + install.sh fürs Linux-Startmenü, build_appimage.sh → FinanzGecko-<Version>-x86_64.AppImage
├── packaging/windows/             # finanzgecko.iss (Inno Setup) → FinanzGecko-<Version>-Setup.exe
├── linux/ macos/ windows/         # Native Flutter-Desktop-Runner (Boilerplate, i.d.R. nicht manuell editieren)
├── docs/                          # Statische Website (GitHub Pages, kein Build-Schritt, reines HTML/CSS)
│   ├── index.html                 # Startseite: Hero, Screenshots, Features, Download/Unterstützen, Trust-Strip, FAQ
│   ├── download.html              # Download-Seite: ein Direktlink pro OS (Windows/macOS/Linux), s. u.
│   ├── documentation.html         # Kurzanleitung für Endnutzer (kein Bezug zu AI_MASTER/gherkin)
│   ├── danke.html                 # Bestätigungsseite nach Stripe-Checkout ("Entwicklung unterstützen"), `noindex`,
│   │                               #   als "After payment"-Redirect im Stripe Payment Link zu hinterlegen
│   └── assets/                    # style.css (teilt Farbtokens mit lib/ui/theme.dart), Icons, Screenshots
└── .github/workflows/
    └── release.yml                # einziger Workflow. Tag-Push (v*.*.*) ODER manuell (workflow_dispatch): erst
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
  - macOS: `~/Library/Application Support/de.finanzgecko.app/`
  - Windows: `%APPDATA%\de.finanzgecko.app\`
- **Verschlüsselung:** AES-256-GCM-"Envelope" (`{v, nonce, cipherText, mac}`, `_envelopeVersion = 1`). Schlüssel kommt
  aus `SecureKeyStore` (OS-Keychain), wird beim ersten Start pro Installation erzeugt.
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
  - `SecureKeyStore` nutzt `MacOsOptions(usesDataProtectionKeychain: false)` — die Data-Protection-Keychain-Variante
    bindet den Key an die Team-ID der Code-Signatur; bei einem unsignierten/ad-hoc-signierten Build (kein Apple
    Developer Team) schlägt das mit `-34018` fehl.
  - App-Sandbox ist **bewusst deaktiviert** (`com.apple.security.app-sandbox = false` in beiden `.entitlements`) —
    sonst virtualisiert macOS `$HOME` auf einen Container-Pfad und `resolveDataDirectory()` würde am dokumentierten
    Pfad vorbeischreiben.

### 4.2 Schema (`lib/data/app_schema.dart`)

`AppSchema` ist das komplette In-Memory-Abbild der JSON-Datei: `schemaVersion`, `baseCurrency`, Listen (`accounts`,
`balances`, `assets`, `subscriptions`), `ratesCache` (Legacy-Migrationspfad, s.o.), Auto-Increment-IDs
(`nextAccountId` etc.), `lastExportAt`, `window` (`WindowPrefs`), sowie das Reminder-Notification-Tracking
`notificationsEnabled`, `backupOverdueNotified`, `assetOverdueNotifiedIds` (episodenbasiert, siehe §4.4 und
`gherkin/notifications.feature`), sowie `themeMode` (`AppThemeMode`, Standard `system`, siehe §5
"Erscheinungsbild") — alles additive `meta`-Felder, kein `schemaVersion`-Bump nötig. `fromDynamic()` ist **fehlertolerant pro Eintrag**:
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

- **Dark Theme als Standard, Hell/Dunkel/System wählbar** (Einstellungen → "Erscheinungsbild", `AppThemeMode` in
  `constants.dart`, persistiert in `AppSchema.themeMode`/`AppStore.themeMode`, Standard: `system`). Nur vier Tokens
  in `lib/ui/theme.dart` sind pro Theme unterschiedlich: `kBackground`, `kSurface`, `kBorder`, `kMuted` sowie
  `kTextPrimary` (volltoniger Lesetext auf `kBackground`/`kSurface`, z. B. Splash-Screen, Chart-Tooltips,
  Monatsauswahl — ersetzt die früheren fest verdrahteten `Colors.white`-Stellen). Alle anderen Farben —
  `kPrimary` (`#00C878`, Markenfarbe), `kDanger` (`#FF6B6B`), `kWarning` (`#E0A030`, Amber für unkritische
  Warnungen wie den Erfassungsstand-Hinweis — abgegrenzt von `kDanger`, das einen echten Fehler/Verlust
  signalisiert), `kTrendUp/Down/Neutral` (Prognose-Linie, bewusst blasser als Primary/Danger) — sind **bewusst in
  beiden Themes identisch** (Markenfarben, keine Neuinterpretation). Diese vier dynamischen Tokens sind
  top-level **Getter** (kein `const` mehr), die den zuletzt von `ThemeScope` aufgelösten `Brightness`-Wert lesen —
  `ThemeScope` sitzt in `main.dart` oberhalb von `MaterialApp` (innerhalb eines `Consumer<AppState>`, das bei jedem
  `setThemeMode()` neu baut) und löst `AppThemeMode.system` gegen `MediaQuery.platformBrightnessOf(context)` auf.
  Jede Stelle, die einen dieser vier Tokens (oder `kTextPrimary`) referenziert, darf deshalb **nicht** `const` sein
  (der Dart-Compiler bricht mit "Invalid constant value" ab, falls doch — verlässlicher Marker beim Reviewen).
  Diese Hex-Werte sind mit `kPrimaryHex`/`kDangerHex` in `constants.dart` synchron zu halten (String-Form fürs
  on-disk Kontofarben-Feld vs. `Color`-Form fürs Theme). **Noch offen:** eigene Hell/Dunkel-Varianten fürs
  Taskleisten-/Dock-Icon (aktuell ein einziges Icon für beide Themes, siehe Icon-Pipeline in Abschnitt 6).
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
  von der Kontrastvorgabe ausgenommen sind.
- **Kein natives Menü** unter Linux/Windows (Flutters `PlatformMenuBar` nur macOS) → In-App-"Datei"-Bereich im
  Fensterkopf, plattformübergreifend identisch, plus globale Tastenkürzel (`Strg`/`⌘`+E/I/Q) via `CallbackShortcuts`.
- **Geld-/Zahlenformat:** immer über `fmtMoney`/`fmtPercent`/`fmtInputNumber`/`parseInputNumber` aus `formatting.dart`
  — deutsches Format (`de_DE`, Komma als Dezimaltrennzeichen), akzeptiert beim Parsen aber auch die alte
  Punkt-Notation rückwärtskompatibel.
- **`noSelect()`-Helper** (`theme.dart`) schließt Button-Labels/Nav-Chrome von der App-weiten `SelectionArea` aus
  (in `main.dart`) — nur Inhaltstext soll markierbar/kopierbar sein.
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

## 6. Plattform-Besonderheiten (siehe auch [dev/setup.md](dev/setup.md) und [dev/building.md](dev/building.md) für Details)

- Cross-Platform-Builds sind **nicht möglich** — jede Plattform muss auf ihrem eigenen OS gebaut werden; alle drei
  gleichzeitig nur über GitHub Actions (`.github/workflows/release.yml`, per Tag-Push `v*.*.*` oder manuell über
  `workflow_dispatch`). Vor den Build-Jobs läuft ein `gate`-Job (analyze + test + Icon-Pipeline); schlägt er fehl,
  wird kein Bundle gebaut/released. Es gibt bewusst keinen separaten Push/PR-CI-Workflow — `flutter analyze`,
  `flutter test` und `dart format` laufen lokal vor jedem Commit (siehe CLAUDE.md "Always verify"), release.yml ist
  der einzige GitHub-Workflow im Repo.
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
  `FinanzGecko-<Version>-x86_64.AppImage` (`packaging/linux/build_appimage.sh` via `appimagetool`), macOS → gezipptes
  `FinanzGecko-<Version>-mac.app.zip` (behandelt der Finder ohnehin als eine Einheit). Die Version wird in jedem
  Build-Job aus `pubspec.yaml` gelesen (nicht aus dem Git-Tag), damit auch ungetaggte Ad-hoc-Testbuilds
  (`workflow_dispatch`, `bump: none`) einen versionierten Dateinamen bekommen. `packaging/linux/install.sh` bleibt als
  Alternative fürs Linux-Startmenü aus einem entpackten Bundle bestehen.
- **Keine unversionierten Alias-Assets mehr:** jedes Release trägt pro Plattform genau **eine** Binärdatei (den
  versionierten Namen). Ein früherer Ansatz lud zusätzlich eine byte-identische unversionierte Kopie hoch
  (`cp`/`Copy-Item` vor dem jeweiligen `upload-artifact`-Schritt), damit `docs/download.html` fest auf
  `.../releases/latest/download/<fester Name>` verlinken konnte — das verdoppelte aber Upload/Storage pro Release
  für reine Duplikate. `docs/download.html` verlinkt die drei OS-Buttons deshalb stattdessen auf
  `.../releases/latest` (GitHubs stabiler Redirect auf die neueste Release-Seite); Nutzer:innen wählen dort die
  passende Datei. Bewusst weiterhin kein clientseitiger JS-/GitHub-API-Aufruf auf der sonst komplett statischen
  Seite, um die exakte Asset-URL clientseitig zusammenzubauen.
- **Kein automatischer/silenter In-App-Auto-Updater** — mangels Apple-Developer- bzw. Microsoft-Signaturzertifikat
  gäbe es keine vertrauenswürdige Grundlage, um ein heruntergeladenes Binary ohne Rückfrage zu installieren; ein
  In-Place-Austausch würde Gatekeeper/SmartScreen-Warnungen ohnehin nicht vermeiden. Stattdessen ein **manueller
  Check**: Einstellungen → Hilfe → "Nach Updates suchen" fragt nur bei diesem Klick (kein Hintergrund-/Start-Check)
  über `UpdateService` (`lib/services/update_service.dart`) den neuesten Release-Tag der öffentlichen
  GitHub-Releases-API (`api.github.com/repos/kreativ-anders/finanzgecko/releases/latest`) ab und vergleicht ihn
  gegen die laufende Version (`PackageInfo`). Drei Ergebnisse: **neue Version verfügbar** — bewusst ein `AlertDialog`
  statt einer Snackbar (handlungsrelevant, soll nicht von selbst wieder verschwinden), mit Buttons "Später" und
  "Herunterladen" → öffnet `docs/download.html` (die Website-Downloadseite mit einem Button je Betriebssystem,
  **nicht** die rohe GitHub-Release-Seite, die die Plattform-Dateiwahl dem Menschen überließe); **bereits aktuell**
  und **fehlgeschlagen** (offline, Repo (noch) privat, GitHub down, Rate-Limit) bleiben einfache Snackbars, Letztere
  mit generischem "bitte später erneut versuchen"-Hinweis statt eines Fehlerdialogs. Die App lädt/installiert dabei
  nie selbst etwas. Update selbst bleibt weiterhin: neues Release-Artefakt laden (Installer erneut ausführen bzw.
  AppImage/.app ersetzen).
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
| `gherkin/currency_exchange.feature` | Wechselkurse (frankfurter.dev), Cache, Offline-Fallback, manueller Kurs | nur UI/Integration (kein Unit-Test) |
| `gherkin/window.feature` | Fenstergröße/Maximiert-Status, Standard-/Mindestgröße, Splash | nur UI/Integration (kein Unit-Test) |
| `gherkin/navigation.feature` | Top-Navigation (6 Ansichten), Banner-Sprünge, In-App-Datei-Menü, Tastenkürzel, Textauswahl | nur UI/Integration (kein Unit-Test) |
| `gherkin/executable/account_color.feature` | resolveAccountColor-Regeln | **ausführbar** (`test/bdd/account_color_bdd_test.dart`) |
| `gherkin/executable/net_worth_projection.feature` | Trend/Prognose/Kennzahlen/Anomalie | **ausführbar** (`test/bdd/analysis_bdd_test.dart`) |

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

**Regel:** Wird ein Gherkin-Szenario ergänzt, das ein neues Verhalten beschreibt, sollte nach Möglichkeit ein
korrespondierender Dart-Test entstehen (oder zumindest ein TODO-Kommentar mit Verweis auf das Szenario), damit
Spezifikation und automatisierte Prüfung nicht auseinanderlaufen.

**Verdrahtung Gherkin ↔ Tests (erzwungen, nicht nur Konvention):** `test/gherkin_sync_test.dart` läuft im normalen
`flutter test` (und damit im `gate`-Job von release.yml) und lässt die Pipeline **fehlschlagen**, sobald Spec, Code und
Tests auseinanderlaufen:
1. Jede `gherkin/*.feature` braucht einen `# Quelle:`-Header, dessen Quellcode-Pfade alle existieren.
2. Ein Test verlinkt das/die Feature(s), das/die er abdeckt, mit einer Kopfzeile `// Gherkin: gherkin/<x>.feature`
   (mehrere kommagetrennt). Jeder Marker muss auf eine existierende Feature-Datei zeigen.
3. Genau die im Test hinterlegte Allow-List (`featuresWithoutUnitTest`, aktuell `currency_exchange`, `window` +
   `navigation`) darf ohne Unit-Test sein — jede Abweichung (neues ungetestetes Feature, oder ein jetzt
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

---

## Regeln für KI-Agenten (PFLICHTLEKTÜRE)

Diese Regeln gelten für **jede KI**, die an diesem Repository arbeitet — egal ob zur Weiterentwicklung der
bestehenden App oder zur Regenerierung einer neuen Instanz aus diesen Dokumenten heraus.

1. **Dieses Dokument und `gherkin/` sind Pflichtteil jeder Änderung, nicht optional.**
   Ändert sich durch einen Task die Ordnerstruktur, die Architektur, ein Datenmodell, eine Konstante mit fachlicher
   Bedeutung (z. B. `kBackupReminderFirstDays`) oder das Verhalten einer View → **im selben Arbeitsschritt**:
   - Abschnitt 3 (Ordnerstruktur) aktualisieren, falls Dateien/Ordner hinzukamen/wegfielen.
   - Abschnitt 4/5 (Architektur/UI-Konventionen) aktualisieren, falls sich Datenfluss, Schema oder Konventionen ändern.
   - Das passende `.feature`-File in `gherkin/` um das neue/geänderte Szenario ergänzen oder korrigieren.
   - Bei neuem deutschen Fachbegriff: Abschnitt 7 (Glossar) ergänzen.
   Eine Änderung an Produktionscode **ohne** begleitendes Doku-Update gilt als unvollständig.

2. **Kein stillschweigendes Verwerfen von Anforderungen.** Wird eine bestehende Gherkin-Regel durch eine Änderung
   ungültig, das Szenario explizit anpassen/entfernen und begründen (z. B. im Commit/PR) — nicht einfach
   liegen lassen, während der Code schon etwas anderes tut.

3. **Deutsche Domänensprache ist verbindlich**, nicht kosmetisch (siehe Glossar). Ein regenerierendes Modell darf
   Begriffe wie "Fixposten", "Kontotyp" oder "Vermögenswerte" **nicht** durch naheliegende englische oder
   allgemeinere deutsche Alternativen ersetzen — das würde die "nahezu identische" Regenerierung brechen, die der
   Zweck dieses Dokuments ist.

4. **Designtokens (Farben, Abstände, Schwellwerte) exakt übernehmen**, nicht neu interpretieren — sie stehen in
   `constants.dart`/`theme.dart` und sind hier in Abschnitt 5/7 dokumentiert. Beispiel: `kConcentrationRiskThreshold
   = 0.65`, `kAssetReevaluationDays = 182`, `kBackupReminderFirstDays = 182`, `kBackupReminderRepeatDays = 90` sind
   fachliche Entscheidungen, keine beliebigen Defaults.

5. **Architekturentscheidungen mit dokumentierter Begründung nicht ohne Rücksprache rückgängig machen**, u. a.:
   - Wechselkurs-Cache in eigener unverschlüsselter Datei (nicht in der DB) — Abschnitt 4.1.
   - `usesDataProtectionKeychain: false` auf macOS — Abschnitt 4.1.
   - App-Sandbox deaktiviert auf macOS — Abschnitt 4.1.
   - Fensterposition wird bewusst nicht gespeichert — Abschnitt 4.3.
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
