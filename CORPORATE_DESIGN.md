# FinanzGecko — Corporate Design

**Zweck dieses Dokuments:** Bündelt die visuelle Identität der App — Farbpalette, Markenfarben-Regeln, Typografie
und App-Icon — als eigenständige Referenz, z. B. für Marketingmaterial, Präsentationen oder externe Gestaltung.
Ausgelagert aus [`AI_MASTER.md`](AI_MASTER.md) §5 (UI-Konventionen), damit dieses Dokument nicht weiter wächst;
`AI_MASTER.md` bleibt Quelle der Wahrheit für Architektur, Datenmodelle, Interaktionsmuster und Verhalten.

> **Pflicht für jede KI:** Ändert sich eine Farbe, ein Farb-Token oder die Typografie in `lib/ui/theme.dart` bzw.
> `lib/constants.dart`, ist diese Datei **im selben Arbeitsschritt** zu aktualisieren (siehe `AI_MASTER.md`
> "Regeln für KI-Agenten" #1/#4). Werte hier sind dokumentierte Design-Entscheidungen, keine beliebigen Defaults —
> nicht ohne Rücksprache neu interpretieren.

## App-Icon

![FinanzGecko App-Icon](assets/icon/icon.png)

Ein Balkendiagramm, dessen rechter, höchster Balken in eine Gecko-Kopf-Silhouette übergeht — Primary-Grün auf
fast-schwarzem Grund (`kBackground` dunkel). Quelle: `assets/icon/icon.png`, ein einziger 1024×1024-Master, der
über `dart run tool/generate_icons.dart` alle Plattform-Icon-Formate speist (Details zur Build-Pipeline: siehe
`AI_MASTER.md` §6 "Plattform-Besonderheiten").

## Farbpalette (Referenztabelle)

Quelle: `lib/ui/theme.dart`, `lib/constants.dart` (`kTagColors`). Die Begründungen dazu stehen in den Abschnitten
darunter.

**Oberflächen** (einzige Tokens, die zwischen Dunkel- und Hell-Theme wechseln — Dunkel ist Standard):

| Bezeichnung | Dunkel (Standard) | Hell | Verwendung |
|---|---|---|---|
| Hintergrund | `#0A0F0C` | `#F4F7F5` | App-Fenster |
| Fläche | `#101713` | `#FFFFFF` | Karten, Dialoge |
| Rahmen | `#1C2721` | `#DCE3DE` | Trennlinien, Card-Border |
| Gedämpfter Text | `#7C8A83` | `#5B6B62` | sekundäre Beschriftung, Icons |
| Text (volltonig) | `#FFFFFF` | `#10160F` | Lesetext |

**Markenfarben** (in beiden Themes identisch — als Fläche gedacht, nicht als Textfarbe; Text-Variante s. u.):

| Farbe | Wert | Text-Variante (nur Hell) | Verwendung |
|---|---|---|---|
| Primary (Mint) | `#00C878` | `#00814D` | Buttons, aktive Zustände, App-Icon, Schriftzug „🦎 FinanzGecko“ |
| Danger (Koralle) | `#FF6B6B` | `#BA4E4E` | Fehler, Verlust, destruktive Aktionen |
| Warning (Amber) | `#E0A030` | `#936920` | unkritische Warnungen (z. B. unvollständiger Monat) |

**Trendfarben** (Prognose-Linie, beide Themes identisch): Aufwärts `#8FE3B3` · Abwärts `#FFC98A` · Neutral `#A6B0A9`.

**Kontotyp-Farben** (`kTagColors`, Fallback wenn kein Bankname gesetzt ist, z. B. Bargeld/Krypto): Girokonto
`#00C878` · Tagesgeld `#2FD0A0` · Depot `#7EE6C0` · Bargeld `#C9D6CF` · Krypto `#F5A623`.

## Markenfarben — Hintergrund & Regeln

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
  Taskleisten-/Dock-Icon (aktuell ein einziges Icon für beide Themes, siehe Icon-Pipeline in `AI_MASTER.md` §6).
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
  gefunden im Qualitäts-Audit (`AI_MASTER.md` §9): `.card.warn` färbte seinen linken Rahmenindikator mit `--danger`
  (2,6:1 gegen `--bg` hell). Deshalb gibt es in `style.css` jetzt — analog zur App — auch ein `--danger-text`
  (`#FF6B6B` dunkel / `#BA4E4E` hell, spiegelt `kDangerText`); `--danger` bleibt als Markenfarbe stehen, ist
  aktuell aber nirgends mehr referenziert.
- **Bankfarben sind Logofarben, keine Textfarben.** `kBanks` enthält u. a. `#000000` (Trade Republic, C24,
  Mercedes-Benz Bank) und `#ffe600` (comdirect) — als Fläche oder 10px-Punkt unproblematisch, als Beschriftung auf
  `kSurface` unlesbar (bis herunter zu 1,06:1). Wo eine Kontofarbe **Text** einfärbt (aktuell der Kontotyp-Chip auf
  den Dashboard-Konto-Karten), läuft sie deshalb durch `readableOn(hex, kSurfaceHex)` aus `constants.dart`: eine
  reine Hex-zu-Hex-Funktion, die in 2%-Schritten Richtung Weiß bzw. Schwarz mischt, bis 4,5:1 erreicht sind, und
  sonst unverändert durchreicht. Die Chip-**Fläche** behält bewusst die ungefilterte Markenfarbe (15% Deckkraft) —
  Hintergründe haben keine Kontrastvorgabe, und sie ist es, die den Chip nach der Bank aussehen lässt. 51 der 96
  Kombinationen (48 Farben × 2 Themes) brauchen die Korrektur; dass **alle** konvergieren, sichert ein Szenario in
  `gherkin/executable/account_color.feature` ab.

## Typografie

Kein eigenes Webfont eingebunden (`pubspec.yaml` deklariert keine `fonts:`-Sektion, kein `fontFamily`/`GoogleFonts`
in `lib/`) — die App nutzt konsequent die native Systemschrift der jeweiligen Plattform:

- **macOS** — SF Pro (San Francisco)
- **Windows** — Segoe UI
- **Linux** — je nach Desktop-Umgebung, i. d. R. Ubuntu oder Cantarell

Zahlen erscheinen durchgehend im deutschen Format (`de_DE`, Komma als Dezimaltrennzeichen, Punkt als
Tausendertrennzeichen) — z. B. `24.180,42 €`, über `fmtMoney`/`fmtPercent` aus `lib/utils/formatting.dart`.
