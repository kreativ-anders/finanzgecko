# FinanzGecko 🦎

Nativer Desktop-Vermögenstracker. Kein Server, keine Cloud, kein Account — alle Daten liegen in einer einzigen
JSON-Datei im eigenen Datenverzeichnis der App. Gebaut mit [Flutter](https://flutter.dev), lokal lauffähig auf
Linux, macOS und Windows.

Download für Endnutzer:innen: [Landingpage](https://kreativ-anders.github.io/finanzgecko/) ·
[Download-Seite](https://kreativ-anders.github.io/finanzgecko/download.html)

## Lizenz

[GPL-3.0](LICENSE) mit ["Commons Clause"](https://commonsclause.com/)-Zusatz: Quellcode frei einsehbar, veränderbar
und weitergebbar (Copyleft — Ableitungen bleiben unter denselben Bedingungen), aber **keine kommerzielle Nutzung**.
Die App bleibt über [GitHub Releases](https://github.com/kreativ-anders/finanzgecko/releases) kostenlos; die
Weiterentwicklung finanziert sich freiwillig über "Pay what you want" (Stripe) auf der Landingpage.

## Quick Start

```bash
flutter pub get
flutter run -d linux   # oder -d macos / -d windows
```

Voraussetzung ist die Flutter-Desktop-Toolchain für deine Plattform — Einrichtung:
[dev/setup.md](dev/setup.md). Release-Builds, Packaging und der Icon-Pipeline: [dev/building.md](dev/building.md).

## Architektur

| Datei/Ordner | Zweck |
|---|---|
| `lib/main.dart` | Einstiegspunkt: Fenster-Setup, Store-Initialisierung, `runApp()` |
| `lib/data/app_store.dart` | Persistenz: verschlüsselte JSON-Datei, atomare Writes |
| `lib/data/app_schema.dart` | In-Memory-Schema der Datendatei |
| `lib/models/` | Datenklassen (`Account`, `Balance`, `Asset`, `Subscription`) |
| `lib/services/currency_service.dart` | Wechselkurse (Frankfurter.app) mit Cache |
| `lib/state/app_state.dart` | Zentraler `ChangeNotifier` — CRUD + berechnete Werte für die UI |
| `lib/ui/views/` | Die sechs Ansichten: Dashboard, Einträge, Konten, Fixposten, Vermögenswerte, Einstellungen |
| `lib/utils/analysis.dart` | Reine, testbare Berechnungslogik (Trend, Prognose, Kennzahlen) |
| `gherkin/` | Fachliche Spezifikation (Gherkin) |

Vollständige Referenz (Datenfluss, Domänen-Glossar, Feature↔Test-Zuordnung): [AI_MASTER.md](AI_MASTER.md).
Architektur-Entscheidungen im Detail (Verschlüsselung, warum keine DB-Engine, Fensterverhalten):
[dev/architecture.md](dev/architecture.md).

## Mitentwickeln

Workflow, Spec-first-Vorgehen, Checks vor dem Commit: [CONTRIBUTING.md](CONTRIBUTING.md).

## Bekannte Einschränkungen

Kein In-App-Auto-Updater; ungesignte Builds lösen bei Erstnutzung Gatekeeper-/SmartScreen-Warnungen aus. Details
und Workarounds: [dev/troubleshooting.md](dev/troubleshooting.md).
