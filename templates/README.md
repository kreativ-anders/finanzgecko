# Migrations-Vorlage für den Import ("Backup importieren…")

Diese Vorlage beschreibt exakt das JSON-Format, das FinanzGecko unter
**Einstellungen → Import** (bzw. `Strg`/`⌘`+I) einliest. Ziel: Wer von einem
anderen Tool (Excel-Tracker, Banking-App-Export, …) kommt, kann seine Daten —
notfalls mit Hilfe einer KI — in genau diese Struktur überführen und dann
importieren.

> **Achtung:** Der Import **ersetzt alle aktuell gespeicherten Daten
> vollständig**. Vorher ggf. ein Backup exportieren.

`import-template.json` in diesem Ordner ist ein vollständiges, gültiges
Beispiel. Eine KI, die einen Fremdexport konvertiert, sollte ihre Ausgabe
**genau an diesem Schema ausrichten** (gleiche Schlüssel, gleiche Typen).

## Top-Level

| Schlüssel | Typ | Pflicht | Bedeutung |
|---|---|---|---|
| `schemaVersion` | Ganzzahl | empfohlen | Aktuell `1`. Ein Backup aus einer *neueren* Version als der App wird abgelehnt. Fehlt der Wert, wird die aktuelle Version angenommen. |
| `baseCurrency` | String | empfohlen | Basiswährung aller Dashboard-Summen. Eine aus `accounts[].currency` ⊆ `["EUR","USD","CHF","GBP","JPY","SEK","NOK","DKK"]`. Kein/ungültiger String → `EUR`. |
| `accounts` | Liste | ja | Konten (siehe unten). |
| `balances` | Liste | ja | Monatliche Kontostände. |
| `assets` | Liste | optional | Sachwerte ohne Zeitverlauf. |
| `subscriptions` | Liste | optional | Fixposten (wiederkehrende Ein-/Ausgaben). |

Unbekannte Zusatzschlüssel werden ignoriert. Eine einzelne fehlerhafte Zeile in
einer Liste wird übersprungen (nicht der ganze Import abgebrochen) — trotzdem
sollte die Ausgabe sauber sein, damit keine Daten still verloren gehen.

## `accounts[]` — Konto

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | Ganzzahl | **Eindeutig** innerhalb der Konten. Wird von `balances[].accountId` referenziert. |
| `name` | String | Anzeigename, z. B. "Girokonto". |
| `bank` | String | Bankname (frei; kann leer sein). |
| `tag` | String | **Kontotyp**, exakt einer aus: `Girokonto`, `Tagesgeld`, `Depot`, `Bargeld`, `Krypto`. |
| `currency` | String | Kontowährung, aus der Währungsliste oben. |
| `color` | String | Hex-Farbe, z. B. `#00C878`. |
| `archived` | Boolean | `true` = archiviert (Soft-Delete). Normalerweise `false`. |
| `createdAt` | ISO-8601-DateTime | z. B. `2025-01-15T00:00:00.000`. |

## `balances[]` — Kontostand (ein Eintrag pro Konto **und** Monat)

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | Ganzzahl | Eindeutig innerhalb der Kontostände. |
| `accountId` | Ganzzahl | Verweist auf ein `accounts[].id`. |
| `period` | String | Monat als `"YYYY-MM"`, z. B. `"2025-01"`. |
| `amountOriginal` | Zahl | Betrag in der Kontowährung. |
| `currencyOriginal` | String | Kontowährung (i. d. R. gleich `accounts[].currency`). |
| `rate` | Zahl | Wechselkurs Kontowährung → `baseCurrency` zum Erfassungszeitpunkt. Bei gleicher Währung `1.0`. |
| `amountBase` | Zahl | **= `amountOriginal` × `rate`** (Betrag in Basiswährung). Diese Beziehung sollte eingehalten werden. |
| `note` | String | Optionale Notiz, sonst `""`. |
| `enteredAt` | ISO-8601-DateTime | Erfassungszeitpunkt. |

Für einen Verlauf einfach mehrere `balances` mit gleichem `accountId` und
unterschiedlichem `period` anlegen.

## `assets[]` — Vermögenswert / Sachwert (ohne Zeitverlauf)

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | Ganzzahl | Eindeutig innerhalb der Vermögenswerte. |
| `name` | String | z. B. "MacBook Pro", "Auto". |
| `value` | Zahl | Aktueller Wert in der Basiswährung. |
| `createdAt` | ISO-8601-DateTime | Anlagezeitpunkt. |
| `lastEvaluatedAt` | ISO-8601-DateTime oder `null` | Letzte Neubewertung (treibt den 6-Monats-Reminder). |

## `subscriptions[]` — Fixposten (wiederkehrende Ein-/Ausgabe)

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | Ganzzahl | Eindeutig innerhalb der Fixposten. |
| `name` | String | z. B. "Gehalt", "Miete", "Netflix". |
| `interval` | String | Exakt einer aus: `daily`, `weekly`, `monthly`, `quarterly`, `yearly`. |
| `amountOriginal` | Zahl | **Vorzeichen kodiert die Richtung:** positiv = Einnahme, negativ = Ausgabe. |
| `currencyOriginal` | String | Währung des Betrags. |
| `rate` | Zahl | Wechselkurs → Basiswährung (`1.0` bei gleicher Währung). |
| `amountBase` | Zahl | = `amountOriginal` × `rate`. |
| `createdAt` | ISO-8601-DateTime | Anlagezeitpunkt. |

## Prompt-Baustein für eine KI-Konvertierung

> Konvertiere die beigefügten Daten (aus <Quelltool>) in **exakt** die Struktur
> von `templates/import-template.json`. Regeln: `tag` nur aus
> [Girokonto, Tagesgeld, Depot, Bargeld, Krypto]; `interval` nur aus
> [daily, weekly, monthly, quarterly, yearly]; `period` als `"YYYY-MM"`;
> jede `balances[].accountId` muss auf ein `accounts[].id` zeigen;
> `amountBase = amountOriginal × rate`; Ausgaben bei `subscriptions` als
> negativer Betrag. Gib nur gültiges JSON aus, keine Kommentare.
