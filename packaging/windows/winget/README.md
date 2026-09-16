# winget-Manifeste

Vorlagen für `winget install KreativAnders.FinanzGecko`. `render.sh` ersetzt Version, Prüfsumme und Datum und
legt das Ergebnis im Verzeichnislayout ab, das `microsoft/winget-pkgs` erwartet.

**Die Vorlagen enthalten bewusst keine Kommentare außer dem Zwei-Zeilen-Kopf.** Die Dateien werden in ein
fremdes Repository eingereicht und dort von Menschen gelesen; jede erklärende Zeile darin ist Lärm. Alle
Begründungen stehen deshalb hier.

## Der Kopf ist Pflicht, kein Stil

```yaml
# Created with packaging/windows/winget/render.sh
# yaml-language-server: $schema=https://aka.ms/winget-manifest.<typ>.1.12.0.schema.json
```

Fehlt die zweite Zeile, bricht die Validierungs-Pipeline mit `SchemaHeaderNotFound` ab — einmal pro Datei, ohne
Hinweis darauf, dass ein *Kommentar* gemeint ist. `<typ>` ist `version`, `installer`, `defaultLocale` oder
`locale` und muss zum `ManifestType` der Datei passen.

## Warum die Felder so gesetzt sind

| Feld | Grund |
| --- | --- |
| `InstallerType: inno` | `finanzgecko.iss` ist Inno Setup. Mit `exe` kennt winget die stillen Schalter nicht und die Installation im Testlauf hängt. |
| `ElevationRequirement: elevationRequired` | `finanzgecko.iss` installiert nach `{autopf}` (Programme) und setzt kein `PrivilegesRequired`, verlangt also immer Adminrechte. Die Pipeline startet Installer als normaler Benutzer; ohne diesen Eintrag scheitert sie. Nicht `elevatesSelf` — das gilt nur für Installer, die selbst entscheiden, ob sie Rechte anfordern. |
| `Scope: machine` | Folgt aus `{autopf}`. Steht innerhalb des `Installers`-Eintrags, nicht auf oberster Ebene. |
| `ReleaseDate` | Das Datum der Veröffentlichung, nicht das Datum des Einreichens. `render.sh` holt es aus `published_at` des GitHub-Releases, damit ein nachgereichtes Manifest (siehe unten: 1.8.0 → 1.11.0) nicht den Einreichungstag nennt. |
| `PrivacyUrl` | Die Policy-Prüfung von `winget-pkgs` verlangt sie für Anwendungen, die Finanzdaten speichern (Policies 1.5.1/1.5.5, PR [#417767](https://github.com/microsoft/winget-pkgs/pull/417767)). Pro Sprache eine Seite: de-DE auf `datenschutz.html`, en-US auf `privacy.html`. Beide erklären die App in **Teil B**, getrennt von der Website in Teil A — Prüfer wie Nutzer sollen nicht raten müssen, welcher Absatz für die App gilt. Beide Pfade stehen damit in einem veröffentlichten Manifest — Umbenennen ist ein Bruch. |

**Bewusst nicht gesetzt:** `ProductCode`, `InstallModes` und `InstallerSwitches`. Alle drei sind optional, und
winget ermittelt sie für Inno-Installer selbst. Ein geratener `ProductCode` führt zu
`Version-Parameter-Mismatch`, also lieber weglassen als schätzen.

**Ebenfalls bewusst nicht gesetzt: `Dependencies` auf `Microsoft.VCRedist.2015+.x64`.** Die
Validierungs-Pipeline schlug bei 1.8.0 mit `Validation-Executable-Error` fehl, weil die App auf einer Maschine
ohne VC++-Redistributable gar nicht startet (`STATUS_DLL_NOT_FOUND`, `0xC0000135`). Der naheliegende Weg wäre,
das Redistributable als Paketabhängigkeit zu deklarieren — der Weg hier ist stattdessen, dass der Installer die
drei Laufzeit-DLLs seit v1.10.0 selbst mitbringt (`release.yml`, Job `windows`; siehe `dev/ai/platform.md`). Das
gilt dann auch für Downloads von der Website, nicht nur für winget. Wer die Abhängigkeit nachträglich einträgt,
zwingt Nutzern eine ~25-MB-Installation auf, die sie nicht brauchen.

## Erste Einreichung (einmalig, von Hand)

```bash
./packaging/windows/winget/render.sh 1.11.0
```

Holt die Prüfsumme aus der veröffentlichten `SHA256SUMS` des Releases — nicht neu berechnet, damit Manifest,
Website und die In-App-Update-Prüfung denselben Wert nennen. Danach die vier Dateien nach
`manifests/k/KreativAnders/FinanzGecko/<version>/` im eigenen Fork von `microsoft/winget-pkgs` kopieren,
committen und als Pull Request einreichen.

Eingereicht wurde zuerst 1.8.0 (PR [#417767](https://github.com/microsoft/winget-pkgs/pull/417767)); dieselbe
PR trägt seit September 2026 **1.11.0**, weil erst dieser Build die VC++-Laufzeit mitbringt und damit die
automatische Prüfung besteht. Eine Version pro PR — beim Wechsel wird der alte Versionsordner gelöscht, nicht
zusätzlich ein neuer angelegt.

Auf einem Windows-Rechner vorher prüfen (auf macOS/Linux nicht möglich):

```powershell
winget validate --manifest <pfad>
winget install  --manifest <pfad>
```

## Danach: automatisch

Der Job `winget` in `.github/workflows/release.yml` aktualisiert das Manifest bei jedem Release selbst — mit
**`wingetcreate`** (`microsoft/winget-create`), dem Werkzeug des winget-Herstellers. `wingetcreate update` holt
das bestehende Manifest aus `winget-pkgs`, tauscht Version, URL, Prüfsumme und `ReleaseDate` aus und öffnet den
Pull Request — deshalb muss die erste Fassung von Hand dort ankommen.

Die oben begründeten Felder (`InstallerType`, `ElevationRequirement`, `Scope`, `PrivacyUrl`, beide Locale-Dateien)
werden dabei **nicht** neu erzeugt, sondern aus dem veröffentlichten Manifest übernommen. Wer sie ändern will,
ändert sie in `winget-pkgs` — und zieht die Vorlagen hier im selben Schritt nach, sonst driften die beiden
auseinander.

Der Job läuft auf `windows-latest`, nicht auf ubuntu: `wingetcreate` gibt es ausschließlich als Windows-Binary.

**`render.sh` bleibt bewusst bestehen und wird nicht durch `wingetcreate` ersetzt.** Es erzeugt die Manifeste der
*ersten* Einreichung aus den Vorlagen in diesem Ordner. `wingetcreate new` würde die oben begründeten Felder
nicht von selbst wieder so setzen, und als Shell-Skript läuft `render.sh` auch auf macOS/Linux — das
Windows-Binary nicht.

Voraussetzung: Secret `WINGET_TOKEN` (klassischer PAT mit `public_repo`) und ein Fork von
`microsoft/winget-pkgs`. Fehlt das Secret, wird der Job übersprungen statt das Release fehlschlagen zu lassen.

## Was winget nicht löst

Die SmartScreen-Warnung bleibt: winget führt denselben unsignierten Installer aus, und Mark-of-the-Web greift
genauso. Der Nutzen ist Auffindbarkeit und ein bequemer Installationsweg — siehe ROADMAP.
