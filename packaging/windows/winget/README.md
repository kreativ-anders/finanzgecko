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
| `ReleaseDate` | Das Datum des Git-Tags, nicht das Datum des Einreichens. |
| `PrivacyUrl` | Die Policy-Prüfung von `winget-pkgs` verlangt sie für Anwendungen, die Finanzdaten speichern (Policies 1.5.1/1.5.5, PR [#417767](https://github.com/microsoft/winget-pkgs/pull/417767)). Pro Sprache eine Seite: de-DE auf `datenschutz.html`, en-US auf `privacy.html`. Beide erklären die App in **Teil B**, getrennt von der Website in Teil A — Prüfer wie Nutzer sollen nicht raten müssen, welcher Absatz für die App gilt. Beide Pfade stehen damit in einem veröffentlichten Manifest — Umbenennen ist ein Bruch. |

**Bewusst nicht gesetzt:** `ProductCode`, `InstallModes` und `InstallerSwitches`. Alle drei sind optional, und
winget ermittelt sie für Inno-Installer selbst. Ein geratener `ProductCode` führt zu
`Version-Parameter-Mismatch`, also lieber weglassen als schätzen.

## Erste Einreichung (einmalig, von Hand)

```bash
./packaging/windows/winget/render.sh 1.8.0
```

Holt die Prüfsumme aus der veröffentlichten `SHA256SUMS` des Releases — nicht neu berechnet, damit Manifest,
Website und die In-App-Update-Prüfung denselben Wert nennen. Danach die vier Dateien nach
`manifests/k/KreativAnders/FinanzGecko/<version>/` im eigenen Fork von `microsoft/winget-pkgs` kopieren,
committen und als Pull Request einreichen.

Auf einem Windows-Rechner vorher prüfen (auf macOS/Linux nicht möglich):

```powershell
winget validate --manifest <pfad>
winget install  --manifest <pfad>
```

## Danach: automatisch

Der Job `winget` in `.github/workflows/release.yml` aktualisiert das Manifest bei jedem Release selbst. Er
kopiert das bestehende Manifest aus `winget-pkgs`, tauscht Version, URL und Prüfsumme aus und öffnet den Pull
Request — deshalb muss die erste Fassung von Hand dort ankommen.

Voraussetzung: Secret `WINGET_TOKEN` (klassischer PAT mit `public_repo`) und ein Fork von
`microsoft/winget-pkgs`. Fehlt das Secret, wird der Job übersprungen statt das Release fehlschlagen zu lassen.

## Was winget nicht löst

Die SmartScreen-Warnung bleibt: winget führt denselben unsignierten Installer aus, und Mark-of-the-Web greift
genauso. Der Nutzen ist Auffindbarkeit und ein bequemer Installationsweg — siehe ROADMAP.
