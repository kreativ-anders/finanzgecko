# Gherkin-Spezifikation — FinanzGecko

Dieser Ordner enthält die fachlichen Anforderungen der App als Gherkin-`.feature`-Dateien. Zusammen mit
[`../AI_MASTER.md`](../AI_MASTER.md) (Architektur, Ordnerstruktur, Konventionen, KI-Regeln) bildet er die vollständige
Spezifikation, aus der die App **nahezu identisch neu generiert** oder konsistent weiterentwickelt werden kann.

## Konventionen

- **Sprache:** Alle Feature-/Szenario-Texte sind auf Deutsch geschrieben, in derselben Domänensprache wie die App-UI
  selbst (siehe Glossar in `AI_MASTER.md` Abschnitt 7). Schritt-Keywords (`Feature`, `Scenario`, `Given`/`Angenommen`,
  `When`/`Wenn`, `Then`/`Dann`, `And`/`Und`, `But`/`Aber`) werden **englisch** geschrieben, damit Standard-Cucumber-
  Tooling ohne Sprachkonfiguration funktioniert; der restliche Text ist deutsch.
- **Eine Datei pro fachlicher Domäne**, nicht pro View — z. B. betreffen Wechselkurs-Fallbacks sowohl Einträge als
  auch Fixposten, stehen aber gebündelt in `currency_exchange.feature`.
- **Tags:** jedes Feature trägt einen `@domain`-artigen Tag (z. B. `@accounts`, `@dashboard`) für Rückverfolgbarkeit
  zu `AI_MASTER.md` Abschnitt 8 (Tests ↔ Gherkin-Zuordnung) und zu den entsprechenden Quelldateien (Kommentar
  `# Quelle: lib/...` am Kopf jedes Features).
- **Kein UI-Framework-Detail** (Widget-Namen, Pixel-Werte) in den Szenarien — die beschreiben *Verhalten*, nicht
  Implementierung. Ausnahme: Wo eine konkrete Zahl eine bewusste fachliche Entscheidung ist (z. B. "182 Tage"), wird
  sie explizit genannt, weil sie regenerierungsrelevant ist.
- **Diese Dateien sind keine ausführbaren Tests** (kein Cucumber/Gherkin-Runner ist in diesem Projekt eingebunden) —
  sie sind die menschen- und KI-lesbare Anforderungsspezifikation. Die tatsächliche automatisierte Prüfung läuft über
  die Dart-Tests in `test/` (Zuordnung siehe `AI_MASTER.md` Abschnitt 8).

## Dateien

| Datei | Domäne |
|---|---|
| `accounts.feature` | Konten anlegen/bearbeiten/archivieren/wiederherstellen |
| `balances_entries.feature` | Monatliche Kontostände erfassen/korrigieren/löschen |
| `dashboard.feature` | Übersicht: Zeitfilter, Verlauf+Prognose, Verteilung, Kennzahlen, Reminder-Banner |
| `assets.feature` | Vermögenswerte (Sachwerte) verwalten |
| `subscriptions.feature` | Fixposten (wiederkehrende Ein-/Ausgaben) verwalten |
| `currency_exchange.feature` | Wechselkurs-Abruf, Cache, manueller Fallback |
| `settings.feature` | Basiswährung, Sicherheits-Info, Reset |
| `backup_restore.feature` | Export/Import von Backups |
| `data_security.feature` | Verschlüsselung, Dateiintegrität, Migration |
| `window.feature` | Fensterverhalten (Größe/Maximiert), Standard-/Mindestgröße, Splash |
| `navigation.feature` | Top-Navigation, Banner-Sprünge, In-App-Datei-Menü, Tastenkürzel, Textauswahl |
| `executable/account_color.feature` | (ausführbar) Konto-Akzentfarbe aus der Bank ableiten |
| `executable/net_worth_projection.feature` | (ausführbar) Trend/Prognose/Kennzahlen/Anomalie |

## Pflicht bei Änderungen

Siehe `AI_MASTER.md` → "Regeln für KI-Agenten": jede Verhaltensänderung im Code erfordert im selben Schritt ein
Update des passenden Feature-Files hier (neues Szenario, geändertes Szenario oder — mit Begründung — Entfernen eines
obsoleten Szenarios).
