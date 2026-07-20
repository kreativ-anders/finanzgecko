# Contributing

## Bevor du anfängst

[AI_MASTER.md](AI_MASTER.md) ist die Source of Truth für Architektur, Datenmodelle, Konventionen und
Domänensprache; [gherkin/](gherkin/) die fachliche Spezifikation. Lies beides, bevor du eine nicht-triviale Änderung
machst — insbesondere den Abschnitt "Regeln für KI-Agenten" am Ende von AI_MASTER.md, der auch für menschliche
Beiträge gilt:

- Deutsche Domänenbegriffe (Konto, Fixposten, Vermögenswerte, …) sind verbindlich, nicht kosmetisch.
- Dokumentierte Architekturentscheidungen (z. B. macOS-Keychain-/Sandbox-Settings, unverschlüsselter
  Wechselkurs-Cache) nicht ohne Rücksprache rückgängig machen — siehe [dev/architecture.md](dev/architecture.md).
- Jede Änderung an Ordnerstruktur, Architektur, Datenmodellen oder View-Verhalten aktualisiert **im selben Schritt**
  AI_MASTER.md und das betroffene `gherkin/*.feature`.

## Dev-Umgebung einrichten

Plattform-Setup (Toolchain, Flutter SDK): [dev/setup.md](dev/setup.md).

```bash
flutter pub get
flutter run -d linux   # oder -d macos / -d windows
```

## Workflow

1. **Spec-first:** Neues fachliches Verhalten zuerst als Gherkin-Szenario formulieren (spätestens im selben Schritt
   wie die Implementierung). Navigation: AI_MASTER §8 Feature-Übersicht → Feature-Datei → deren
   `# Implementierung:`-Datei.
2. Ändern, dabei nur die durch das Feature betroffenen Dateien anfassen (siehe AI_MASTER "Regenerierung eines
   Features").
3. Für neue reine Logik: `Scenario` in `gherkin/executable/*.feature` + `s.step(...)` in `test/bdd/`.

## Checks vor jedem Commit

```bash
flutter analyze
flutter test
```

Beides muss grün sein — das ist exakt das, was der `gate`-Job in `.github/workflows/release.yml` vor jedem Release
prüft. `test/gherkin_sync_test.dart` schlägt fehl und zeigt genau, welcher Spec/Code/Test-Link gebrochen ist, falls
Doku und Code auseinanderlaufen.

## Pull Requests

- Kleine, fokussierte Änderungen.
- Beschreibe das *Warum*, nicht nur das *Was* — Commit-Messages landen automatisch im `CHANGELOG.md`.
- Ändert der PR Verhalten, gehören das aktualisierte `gherkin/*.feature` und ggf. AI_MASTER.md zum Diff, nicht zu
  einem Follow-up.

## Lizenz

Beiträge fallen unter dieselbe Lizenz wie das Projekt: [GPL-3.0 mit Commons-Clause-Zusatz](LICENSE).
