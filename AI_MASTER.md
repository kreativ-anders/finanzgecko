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

## 2. Tech-Stack

| Bereich | Wahl | Version (siehe `pubspec.yaml`) |
|---|---|---|
| Framework | Flutter (Desktop-Targets only: Linux/macOS/Windows, kein Mobile/Web) | SDK ^3.12.2 |
| State Management | `provider` (`ChangeNotifier` + `ChangeNotifierProvider`) | ^6.1.5 |
| Persistenz | eigene JSON-Datei, kein SQLite/Hive/Isar (bewusste Entscheidung, siehe README "Warum weiterhin keine Datenbank-Engine") | — |
| Verschlüsselung | `cryptography` (AES-256-GCM) + `flutter_secure_storage` (Schlüssel im OS-Keychain) | ^2.7.0 / ^10.3.1 |
| Charts | `fl_chart` (Linie, Donut, gestapelte Fläche — eigene Wrapper in `lib/ui/widgets/`) | ^1.2.0 |
| Wechselkurse | `http` gegen die freie Frankfurter.app-API (EZB-Referenzkurse) | ^1.6.0 |
| Fenster | `window_manager` (Größe/Maximiert-Status merken) | ^0.5.2 |
| Dateidialoge | `file_selector` (native Save/Open, kein Browser-Download) | ^1.1.0 |
| Links | `url_launcher` (externe URLs, mailto:, Datei-Explorer öffnen) | ^6.3.2 |
| Formatierung | `intl` (`NumberFormat`, deutsches Zahlenformat `de_DE`) | ^0.20.3 |
| Lint | `flutter_lints` | ^6.0.0 |

Es gibt **keine** Backend-Services, keine REST-API dieser App selbst, keine Datenbank-Engine, kein Auth-System.
Einzige externe Netzwerkabhängigkeit: `api.frankfurter.dev` für Wechselkurse (mit Cache-Fallback, App bleibt offline
nutzbar).

## 3. Ordnerstruktur

```
finanzgecko/
├── AI_MASTER.md                  # ← dieses Dokument
├── gherkin/                      # ← fachliche Spezifikation als Gherkin-Features (siehe gherkin/README.md)
├── templates/                    # ← Import-Vorlage (import-template.json) + Feld-Doku für die Datenmigration aus Fremdtools
├── README.md                     # Entwickler-Doku: Setup, Build, Release, Architektur-Tabelle, Troubleshooting
├── pubspec.yaml                  # Package-Name, Version, Dependencies, flutter_launcher_icons-Konfig
├── analysis_options.yaml         # Lint-Regeln (flutter_lints)
├── lib/
│   ├── main.dart                 # Entry Point: window_manager-Setup, Store-Init, runApp()
│   ├── constants.dart            # Domänen-Konstanten: Tags/Kontotypen, Farben, Banken-Liste, Währungen, Schwellwerte
│   ├── data/
│   │   ├── app_store.dart        # Persistenzschicht: Verschlüsselung, atomare Writes, Write-Queue, Export/Import
│   │   ├── app_data.dart         # In-Memory-Schema der JSON-Datei (schemaVersion, Listen, meta, window)
│   │   └── secure_key_store.dart # AES-Schlüssel im OS-Keychain (flutter_secure_storage)
│   ├── models/                   # Datenklassen mit fromJson/toJson: Account, Balance, Asset, Subscription
│   ├── services/
│   │   └── currency_service.dart # Frankfurter.app-Anbindung inkl. Cache-Fallback
│   ├── state/
│   │   └── app_state.dart        # Zentraler ChangeNotifier: CRUD-Fassade + berechnete Werte (Reminder, Summen) für die UI
│   ├── utils/
│   │   ├── analysis.dart         # Reine, UI-freie Berechnungen (Trend, Prognose, Anomalie-Check, Kennzahlen, Zeitraum-Filter) — unit-testbar
│   │   ├── csv_export.dart       # Reiner CSV-Builder für den Kontostände-Export (verlustbehaftet, kein Re-Import)
│   │   └── formatting.dart       # Geld-/Prozent-/Datumsformatierung, Zahlen-Parsing, Perioden-Helper, Hex→Color
│   └── ui/
│       ├── app_shell.dart        # Navigation, In-App-"Datei"-Menü, Tastenkürzel, Export-/Import-Dialoge
│       ├── app_view.dart         # enum AppView (die 6 Ansichten) + deutsche Labels
│       ├── splash_screen.dart    # Splash beim Start
│       ├── theme.dart            # Farb-Konstanten (dark theme), ThemeData, `noSelect()`-Helper
│       ├── views/                # Eine Datei pro Hauptansicht (siehe Tabelle unten)
│       └── widgets/               # Wiederverwendbare Bausteine (Charts, Dialoge, Banner, Formularelemente)
├── test/                         # Dart-Unit-/Widget-Tests, gespiegelt zu den Gherkin-Szenarien (siehe Abschnitt 8)
├── tool/generate_icons.dart       # Icon-Pipeline (ein Master-PNG → alle Plattform-Icon-Formate)
├── tool/generate_demo_data.dart   # buildDemoBackup() → demo/finanzgecko-demo.json (an "heute" verankert); auch von flutter test aufgerufen
├── demo/finanzgecko-demo.json     # importierbare Demodaten für Screenshots (generiert, .gitignore) — via "Backup importieren…"
├── packaging/linux/               # .desktop-Datei + install.sh fürs Linux-Startmenü
├── linux/ macos/ windows/         # Native Flutter-Desktop-Runner (Boilerplate, i.d.R. nicht manuell editieren)
└── .github/workflows/
    ├── ci.yml                     # Push/PR: dart format-Check + flutter analyze + flutter test (schnelles Dev-Gate)
    └── release.yml                # Tag-Push (v*.*.*) ODER manuell (workflow_dispatch): erst `test`-Gate (analyze + test +
                                   #   Icon-Pipeline), dann 3 native Build-Jobs (ubuntu/macos/windows, `needs: test`) → Release-Assets
```

### Die sechs Ansichten (`lib/ui/views/`)

| Datei | AppView | Deutsches Label | Kernzweck |
|---|---|---|---|
| `dashboard_view.dart` | `dashboard` | Dashboard | Übersicht: Gesamtvermögen, Verlauf+Prognose, Verteilung, Zusammensetzung über Zeit, Kennzahlen, Währungsaufteilung, Fixposten-/Vermögenswerte-Summary, Konto-Karten — alles über den Zeitraum-Filter gesteuert |
| `entries_view.dart` | `entries` | Einträge | Monatsbezogene Erfassung/Korrektur von Kontoständen für alle Konten auf einmal |
| `accounts_view.dart` | `accounts` | Konten | Konten anlegen/bearbeiten/archivieren/wiederherstellen |
| `subscriptions_view.dart` | `subscriptions` | Fixposten | Wiederkehrende Ein-/Ausgaben anlegen/bearbeiten/löschen |
| `assets_view.dart` | `assets` | Vermögenswerte | Sachwerte (kein Zeitverlauf) anlegen/inline bearbeiten/löschen |
| `settings_view.dart` | `settings` | Einstellungen | Basiswährung, Sicherheits-Info, Backup-Export/Import, CSV-Export, Reset |

Navigation ist **kein Router**, sondern ein einfacher `enum`-Switch in `app_shell.dart` (`_content()`), gesteuert über
`ValueChanged<AppView> onNavigate`, das jede View nach oben durchreicht (z. B. für "Jetzt erfassen"-Buttons in
Bannern, die zu einer anderen View springen).

## 4. Architektur & Datenfluss

```
AppStore (Persistenz, Verschlüsselung, Write-Queue)
   │  liest/schreibt
   ▼
AppData (In-Memory-Schema, JSON-Serialisierung)
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
- **Atomare Writes:** immer temp-Datei schreiben → alte Datei löschen → temp-Datei umbenennen (`_persistNow`,
  `_persistRatesNow`). Verhindert eine halb geschriebene Datei bei einem Crash mitten im Schreibvorgang.
- **Serialisierte Write-Queue** (`_writeQueue`/`_enqueueWrite`): verhindert, dass zwei parallele Speicherungen sich
  auf derselben temporären Datei überschneiden. Ein fehlgeschlagener Write vergiftet nicht die Queue für später.
- **Unlesbare/fremde Dateien werden nie stillschweigend überschrieben** — sie werden zuerst unter
  `*.unreadable-<timestamp>` gesichert (`_quarantineUnreadable`), erst danach startet die App mit Standardwerten.
- **Import erzwingt die Bank→Farbe-Regel:** In `importAllData` wird `account.color` über
  `resolveAccountColor(bank, tag)` (`constants.dart`) neu gesetzt — bekannte Bank → Markenfarbe, leere Bank
  (Bargeld/Krypto) → Kontotyp-Farbe. Eine unbekannte, nicht-leere Bank **bricht den gesamten Import ab** (kein
  stilles Einschleusen einer willkürlichen Farbe). Das spiegelt exakt die Regel des Konto-Formulars
  (`bankColorHex(bank) ?? tagColorHex(tag)` + Known-Bank-Validator).
- **Dateirechte als Defense-in-Depth:** `chmod 700`/`600` (Linux/macOS), `icacls` current-user-only (Windows) —
  zusätzlich zur Verschlüsselung, nicht als Ersatz dafür.
- **macOS-Spezifika (wichtig, nicht versehentlich rückgängig machen):**
  - `SecureKeyStore` nutzt `MacOsOptions(usesDataProtectionKeychain: false)` — die Data-Protection-Keychain-Variante
    bindet den Key an die Team-ID der Code-Signatur; bei einem unsignierten/ad-hoc-signierten Build (kein Apple
    Developer Team) schlägt das mit `-34018` fehl.
  - App-Sandbox ist **bewusst deaktiviert** (`com.apple.security.app-sandbox = false` in beiden `.entitlements`) —
    sonst virtualisiert macOS `$HOME` auf einen Container-Pfad und `resolveDataDirectory()` würde am dokumentierten
    Pfad vorbeischreiben.

### 4.2 Schema (`lib/data/app_data.dart`)

`AppData` ist das komplette In-Memory-Abbild der JSON-Datei: `schemaVersion`, `baseCurrency`, Listen (`accounts`,
`balances`, `assets`, `subscriptions`), `ratesCache` (Legacy-Migrationspfad, s.o.), Auto-Increment-IDs
(`nextAccountId` etc.), `lastExportAt`, `window` (`WindowPrefs`). `fromDynamic()` ist **fehlertolerant pro Eintrag**:
eine kaputte Zeile in einer Liste wird übersprungen statt die ganze Datei unlesbar zu machen. `toExportJson()` ist
bewusst schlanker als `toJson()` (kein `ratesCache`/`meta`/`window` — internes Implementierungsdetail, nicht Teil
eines Backups) **und ohne `account.color`** (`Account.toExportJson`): die Farbe ist aus der Bank ableitbar und wird
beim Import über `resolveAccountColor` neu gesetzt — kleinere Backups, gehärteter Import.

`currentSchemaVersion = 1` — bei jeder inkompatiblen Schemaänderung hochzählen und die Import-Prüfung in
`AppStore.importAllData()` beachten (lehnt Backups aus einer *neueren* Version ab, mit klarer Fehlermeldung).

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
   - `getBackupReminder()` — überfällig nach `kBackupReminderDays` (30) seit `lastExportAt`, oder wenn nie exportiert
   - `getAssetReminder()` — Liste überfälliger Vermögenswerte (> `kAssetReevaluationDays` = 182 Tage seit `lastEvaluatedAt`)
   - `getUpdateReminder()` — Nudge, wenn der neueste erfasste Monat älter als der aktuelle ist
   - `computeSubscriptionTotals()` — Einnahmen/Ausgaben/Netto, alle Fixposten auf Monatsäquivalent normiert
   - `previousBalance()` / `latestBalanceForAccount()` / `allPeriodsSorted()` / `balancesInPeriod()`

### 4.5 Reine Analyse-Funktionen (`lib/utils/analysis.dart`)

Bewusst **UI-frei und deterministisch** gehalten, damit sie ohne Flutter-Binding unit-testbar sind (`test/analysis_test.dart`):
- `monthsBetweenPeriods`, `monthsToYearEnd` — Perioden-Arithmetik auf `"YYYY-MM"`-Strings
- `trendSlopePerMonth` — OLS-Steigung einer Zeitreihe (der statistische Trend fürs Dashboard)
- `projectionRate` — mischt Trend (primär) mit Fixposten-Netto als Prior, dessen Gewicht mit wachsender Historie
  (`trendPoints`) gegen 0 geht (`priorStrength = 3`). **Nicht** additiv — beide sind Schätzer derselben monatlichen Rate.
- `contributionMarketSplit` — zerlegt eine Vermögensänderung in "eingezahlt" (Fixposten-Netto × Monatsabstand) vs. "Markt/Sonstiges"
- `isBalanceAnomaly` — flags einen 10×-Sprung (typisches Tippfehler-Muster: Ziffer zu viel/zu wenig)
- `computeNetWorthStats` — Bester/schwächster Monat, Ø-Veränderung, Monate im Plus, Höchststand, Gesamtveränderung
  seit Start, aktueller Stand und `drawdownFromPeak` (Abstand zum Höchststand in 0..1)
- `periodsForRange` / `availableRanges` / `defaultRange` — der Dashboard-weite **Zeitraum-Filter** als reine Logik
  (`enum HistoryRange { ytd, twelveMonths, lastYear, all }`, `now` injizierbar für Tests). `availableRanges` blendet ein
  Preset aus, solange es dieselbe Menge wie "Alle" ergäbe (Dedup); `defaultRange` = "Dieses Jahr", sonst "Alle".

Reiner CSV-Export lebt in `lib/utils/csv_export.dart` (`buildBalancesCsv`): eine Zeile pro Konto+Monat, `;`-getrennt,
Dezimalkomma, RFC-4180-Quoting — bewusst verlustbehaftet und **ohne Re-Import** (der JSON-Backup-Pfad ist der einzige
verlustfreie Round-Trip). Getestet in `test/csv_export_test.dart`.

Bei jeder Änderung an diesen Formeln: `test/analysis_test.dart` **und** das zugehörige Gherkin-Feature aktualisieren.

## 5. UI-Konventionen

- **Dark Theme only**, Konstanten in `lib/ui/theme.dart`: `kBackground`, `kSurface`, `kBorder`, `kMuted`, `kPrimary`
  (`#00C878`, Markenfarbe), `kDanger` (`#FF6B6B`), `kTrendUp/Down/Neutral` (Prognose-Linie, bewusst blasser als
  Primary/Danger). Diese Hex-Werte sind mit `kPrimaryHex`/`kDangerHex` in `constants.dart` synchron zu halten
  (String-Form fürs on-disk Kontofarben-Feld vs. `Color`-Form fürs Theme).
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

## 6. Plattform-Besonderheiten (siehe auch README für Setup-Details)

- Cross-Platform-Builds sind **nicht möglich** — jede Plattform muss auf ihrem eigenen OS gebaut werden; alle drei
  gleichzeitig nur über GitHub Actions (`.github/workflows/release.yml`, per Tag-Push `v*.*.*` oder manuell über
  `workflow_dispatch`). Vor den Build-Jobs läuft ein `test`-Gate (analyze + test + Icon-Pipeline); schlägt es fehl,
  wird kein Bundle gebaut/released.
- Icon-Pipeline: ein einziger 1024×1024-Master (`assets/icon/icon.png`) speist alle Plattform-Formate über
  `dart run tool/generate_icons.dart`.
- Kein In-App-Auto-Updater — Update = neues Release-Zip laden, altes Bundle ersetzen.

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
| Kennzahlen | Gesamtveränderung, bester/schwächster Monat, Ø-Veränderung, Monate im Plus, Höchststand, "Unter Höchststand" (Drawdown) |
| Währungsaufteilung | Anteil des Vermögens je Währung im letzten Monat des Zeitraums (nur bei >1 Währung) |
| Zeitraum(-Filter) | Dashboard-weiter Zeitfenster-Filter ("Dieses Jahr" / "12 Monate" / "Letztes Jahr" / "Alle"), steuert alle zeitbasierten Karten |
| Backup exportieren/importieren | Klartext-JSON-Export/Import über native Dateidialoge (verlustfreier Round-Trip) |
| CSV-Export | Verlustbehafteter Tabellen-Export der Kontostände (kein Re-Import) |

## 8. Tests ↔ Gherkin-Zuordnung

| Testdatei | Deckt ab | Zugehöriges Feature |
|---|---|---|
| `test/analysis_test.dart` | Reine Berechnungen (Trend, Prognose, Anomalie, Kennzahlen) | `gherkin/dashboard.feature` |
| `test/app_data_test.dart` | Schema-Parsing, Fehlertoleranz, Export-Shape | `gherkin/data_security.feature` |
| `test/app_state_test.dart` | AppState-CRUD & abgeleitete Werte (Reminder, Summen) | mehrere Features |
| `test/app_store_encryption_test.dart` | Envelope-Verschlüsselung, Quarantäne unlesbarer Dateien | `gherkin/data_security.feature` |
| `test/app_store_ops_test.dart` | Store-CRUD, Export/Import, Schema-Versionsprüfung, Import-Bank→Farbe-Regel | `gherkin/backup_restore.feature` |
| `test/account_color_test.dart` | `resolveAccountColor` (bekannte Bank → Markenfarbe, leer → Kontotyp, unbekannt → Fehler) | `gherkin/accounts.feature`, `gherkin/backup_restore.feature` |
| `test/backup_hardening_test.dart` | Backup-Export→Import-Round-Trip & Fehlertoleranz (AppData-Ebene) | `gherkin/backup_restore.feature` |
| `test/csv_export_test.dart` | CSV-Export (Trennzeichen, Dezimalkomma, Sortierung, Quoting) | `gherkin/settings.feature` |
| `test/tooling_test.dart` | **Regeneriert beim Testlauf** die Demodaten (`buildDemoBackup` → `demo/…json`) und die Linux-Hicolor-Icons (`generateLinuxIcons`) und validiert sie (Schema, Referenzen, Domänenwerte, Icon-Größen) | Dev-Tooling (kein Feature) |
| `test/entries_view_orphan_test.dart` | Verwaiste Balances archivierter Konten | `gherkin/balances_entries.feature` |
| `test/formatting_test.dart` | Zahlen-/Geldformatierung, Parsing | quer über alle Features (nicht-funktional) |

**Regel:** Wird ein Gherkin-Szenario ergänzt, das ein neues Verhalten beschreibt, sollte nach Möglichkeit ein
korrespondierender Dart-Test entstehen (oder zumindest ein TODO-Kommentar mit Verweis auf das Szenario), damit
Spezifikation und automatisierte Prüfung nicht auseinanderlaufen.

---

## Regeln für KI-Agenten (PFLICHTLEKTÜRE)

Diese Regeln gelten für **jede KI**, die an diesem Repository arbeitet — egal ob zur Weiterentwicklung der
bestehenden App oder zur Regenerierung einer neuen Instanz aus diesen Dokumenten heraus.

1. **Dieses Dokument und `gherkin/` sind Pflichtteil jeder Änderung, nicht optional.**
   Ändert sich durch einen Task die Ordnerstruktur, die Architektur, ein Datenmodell, eine Konstante mit fachlicher
   Bedeutung (z. B. `kBackupReminderDays`) oder das Verhalten einer View → **im selben Arbeitsschritt**:
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
   = 0.65`, `kAssetReevaluationDays = 182`, `kBackupReminderDays = 30` sind fachliche Entscheidungen, keine
   beliebigen Defaults.

5. **Architekturentscheidungen mit dokumentierter Begründung nicht ohne Rücksprache rückgängig machen**, u. a.:
   - Wechselkurs-Cache in eigener unverschlüsselter Datei (nicht in der DB) — Abschnitt 4.1.
   - `usesDataProtectionKeychain: false` auf macOS — Abschnitt 4.1.
   - App-Sandbox deaktiviert auf macOS — Abschnitt 4.1.
   - Fensterposition wird bewusst nicht gespeichert — Abschnitt 4.3.
   - Keine DB-Engine, eine einzige JSON-Datei — Abschnitt 2.
   Diese Punkte tauchen typischerweise auch als Kommentar im Code auf; wer den Kommentar entfernt, muss auch hier
   den entsprechenden Absatz anpassen (oder umgekehrt).

6. **Neue fachliche Anforderungen zuerst als Gherkin-Szenario formulieren**, dann implementieren (Spec-first), wo
   praktikabel — mindestens aber **spätestens im selben Schritt wie die Implementierung**, nie danach "irgendwann".

7. **Reihenfolge für eine komplette Neu-Generierung** (z. B. mit einem anderen KI-Modell von Null): Datenmodelle
   (`lib/models/`) → `AppData`/`AppStore` (Persistenz+Verschlüsselung) → `CurrencyService` → `AppState` →
   `theme.dart`/`constants.dart` → Widgets (`lib/ui/widgets/`) → Views (`lib/ui/views/`) → `app_shell.dart` →
   `main.dart`. Jede Stufe gegen das jeweilige `gherkin/*.feature` verifizieren, bevor die nächste beginnt.

8. **Nicht-funktionale Anforderungen nie vergessen**, auch wenn sie in keinem einzelnen Gherkin-Szenario explizit
   auftauchen: rein lokal (kein Netzwerk außer Wechselkurs-API), Verschlüsselung ruht auf OS-Keychain, atomare
   Schreibvorgänge, Offline-Fallback für Kurse, keine stillschweigende Datenvernichtung bei kaputten/fremden
   Dateien (immer quarantänen statt überschreiben).

9. **Bei Unklarheit zwischen Code und Doku gilt: nachfragen bzw. beides angleichen, nicht raten.** Weicht der
   aktuelle Code von diesem Dokument ab, ist das ein Zeichen, dass die Doku beim letzten Change vergessen wurde —
   nicht, dass der Code automatisch recht hat.
