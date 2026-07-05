# Vermögenstracker

Lokaler, privater Vermögenstracker als PWA. Kein Server, kein Account, keine Cloud —
alle Daten liegen in IndexedDB im Browser.

## Deployment (kein npm, kein Build-Step)

Das ist eine reine Standalone-HTML/CSS/JS-App. Für GitHub Pages, Netlify,
einen eigenen Nginx/Apache-Server oder jedes andere statische Hosting reicht:
Ordnerinhalt hochladen, fertig. Kein `npm install`, kein Build, keine
Server-Runtime nötig — sobald die Dateien über `https://` (oder `http://`)
ausgeliefert werden, funktionieren ES-Module, Service Worker und Manifest
ohne weiteres Zutun.

## Lokal testen (vor dem Hosten)

Ein Doppelklick auf `index.html` reicht **nicht**: Browser blockieren
ES-Module (`import`/`export`) beim `file://`-Protokoll aus Sicherheitsgründen,
und Service Worker lassen sich auf `file://` grundsätzlich nicht registrieren.
Du brauchst also kurz einen lokalen HTTP-Server — dafür ist kein npm nötig,
Python reicht (ist auf macOS/Linux i.d.R. vorinstalliert, für Windows von
python.org):

```bash
python3 -m http.server 8080 & xdg-open http://localhost:8080
```

Alternativ jede andere Methode, einen Ordner lokal per HTTP auszuliefern
(z.B. die "Live Server"-Erweiterung in VS Code).

*Hinweis für macOS:* `xdg-open` durch `open` ersetzen.

**Wichtig bei GitHub Pages in einem Unterpfad** (z.B. `username.github.io/repo/`):
Die relativen Pfade in `manifest.json`, `sw.js` und den `<script>`-Tags
funktionieren bereits mit `./`-Präfix und sollten ohne Anpassung laufen.

## Architektur

| Datei | Zweck |
|---|---|
| `index.html` | App-Shell, Navigation, Pico.css-Einbindung |
| `css/theme.css` | Grün-Schwarz-Theme über Pico-CSS-Variablen |
| `js/db.js` | Kompletter IndexedDB-Zugriff (Accounts, Balances, Settings, Rate-Cache, Export/Import) |
| `js/currency.js` | Wechselkurs-Abfrage über die kostenlose [Frankfurter.app](https://frankfurter.app)-API, mit lokalem Cache |
| `js/charts.js` | Eigener minimaler SVG-Linienchart + CSS-Donut — bewusst ohne externe Chart-Library, damit Charts auch offline zuverlässig funktionieren |
| `js/main.js` | Routing (Hash-basiert) + alle Views (Dashboard, Konten, Erfassung, Einstellungen) |
| `sw.js` | Service Worker, cached die App-Shell für Offline-Start |
| `manifest.json` | PWA-Manifest (installierbar, Icons, Theme-Farbe) |

## Fachliche Entscheidungen (aus der Konzeptphase)

- **Wechselkurse**: pro Kontostand-Eintrag wird der historische Kurs zum
  Monatsende gespeichert (nicht der aktuelle) — damit bleibt die Historie
  korrekt, auch wenn sich der Kurs später ändert.
- **Lücken**: fehlt für ein Konto ein Eintrag in einem Monat, wird dieser
  Monat für die Gesamtsumme einfach ausgeklammert (kein Forward-Fill). Das
  Dashboard zeigt deshalb transparent an, auf wie vielen von wie vielen
  Konten die aktuelle Summe basiert.
- **Kredit-Konten**: negative Salden fließen netto in die Gesamtsumme ein.
- **Archivierte Konten**: verschwinden komplett aus allen Charts (Annahme:
  Konto wurde vorher auf 0 gebracht).
- **Export/Import**: MVP-bewusst **unverschlüsselt**. Verschlüsselung
  (WebCrypto AES-GCM + Passwort) ist als spätere Erweiterung vorgesehen,
  ohne dass sich am Datenmodell etwas ändern muss.
- **Duplikate**: pro Konto und Monat existiert genau ein Eintrag (unique
  Index in IndexedDB). Ein erneutes Speichern für denselben Monat
  überschreibt den bestehenden Wert.

## Offene Punkte für später (bewusst nicht im MVP)

- Verschlüsselter Export/Import (Passwort + WebCrypto AES-GCM)
- Undo nach Import (Snapshot wird technisch schon gezogen, aber nur
  in-memory für die laufende Sitzung — noch keine UI dafür)
- Erinnerung an monatliche Erfassung / Backup-Reminder
- Unterscheidung Einzahlung vs. Rendite bei Depot-Konten
