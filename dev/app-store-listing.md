# App Store Connect — listing copy

Ready-to-paste content for the Mac App Store entry, derived from `docs/index.html`. Primary language **German**.
Character limits are Apple's; the counts in brackets are what the text below actually uses.

> **Keep this in sync with `docs/index.html`.** The listing and the landing page make the same promises to the
> same audience — if a feature claim changes on one, change it on the other. Nothing enforces this automatically.

---

## Basics

| Field | Value |
|---|---|
| Name | `FinanzGecko` |
| Subtitle (30) | `Vermögen im Blick, ohne Cloud` [29] |
| Bundle ID | `de.finanzgecko.app` |
| SKU | `finanzgecko-macos` |
| Primary category | Finance |
| Secondary category | Productivity |
| Age rating | 4+ |
| Copyright | `2026 kreativ-anders | Manuel Steinberg` |
| Support URL | `https://finanzgecko.app` |
| Marketing URL | `https://finanzgecko.app` |
| Privacy Policy URL | `https://finanzgecko.app/datenschutz.html` |

## Promotional text (170, editable without review)

```
Einmal im Monat Kontostände eintragen — den Rest erledigt FinanzGecko. Ohne Bank-Login, ohne Cloud, ohne Abo. Deine Zahlen bleiben auf deinem Mac.
```

[145]

## Keywords (100, comma-separated, no spaces)

```
Vermögen,Nettovermögen,Finanzübersicht,Sparen,Depot,Konten,Offline,Datenschutz,Prognose,Haushalt
```

[99] — deliberately omits "FinanzGecko" (the name is indexed anyway) and "Banking" (the app does no banking, and
a mismatch between keyword and function is a review risk).

## Description

```
FinanzGecko zeigt dir dein Gesamtvermögen — nicht jede einzelne Buchung, sondern die Linie darunter.

Einmal im Monat trägst du deine Kontostände ein, alle auf einer Seite, jeweils mit dem letzten Wert als Gedächtnisstütze. In zwei Minuten bist du fertig. Den Rest erledigt die App: Verlauf, Verteilung, Kennzahlen, Prognose.

KEIN BANK-LOGIN, KEINE CLOUD
FinanzGecko liest keine Konten aus. Kein PSD2, kein Online-Banking-Zugang, kein Konto bei uns — es gibt gar keine Registrierung. Deine Daten liegen AES-256-verschlüsselt auf deinem Mac, der Schlüssel im Schlüsselbund deines Systems. Von sich aus geht die App nicht ins Netz: öffentliche Wechselkurse nur nach deiner ausdrücklichen Zustimmung. Deine Finanzdaten verlassen dein Gerät nie.

WAS DU BEKOMMST
• Verlauf & Prognose — Gesamtvermögen über die Zeit, mit trendbasierter Vorschau
• Alle Konten an einem Ort — Girokonto, Tagesgeld, Depot, Bargeld, Krypto, in Euro oder Fremdwährung
• Über 40 Banken und Neobanken mit ihrer echten Markenfarbe
• Fixposten — Gehalt, Miete, Abos und Dividenden, automatisch auf ein Monatsäquivalent normiert
• Vermögenswerte — E-Bike, Auto, MacBook: Sachwerte mit Erinnerung zur Neubewertung
• Kennzahlen & Verteilung — bester und schwächster Monat, Ø-Veränderung, Aufteilung nach Kontotyp
• Zusammensetzung über Zeit — welcher Kontotyp deinen Verlauf tatsächlich trägt
• Verschlüsselter Export und Import für Backups und den Umzug auf einen neuen Mac

WOFÜR ES NICHT GEDACHT IST
Kein Haushaltsbuch. FinanzGecko erfasst keine einzelnen Ausgaben und keine Kategorien wie Lebensmittel oder Freizeit. Für die tägliche Ausgabenkontrolle sind andere Apps besser. FinanzGecko ist für den ruhigen Moment einmal im Monat — und für die Frage, wie sich dein Vermögen über Jahre entwickelt.

EINMAL ZAHLEN
Kein Abo. Kein Verbrauchsmodell. Kein Konto.

FinanzGecko ist quelloffen und auf finanzgecko.app auch kostenlos erhältlich. Im App Store bezahlst du für den bequemen Weg: Installation und Updates automatisch über den Mac App Store, ohne manuelles Nachladen — und du unterstützt damit die Weiterentwicklung. Beide Versionen sind funktional identisch.

Fragen oder Wünsche: finanzgecko@kreativ-anders.de
```

## What's New (first version)

```
Erste Version im Mac App Store. FinanzGecko läuft jetzt in der App-Sandbox von macOS und wird über den App Store aktualisiert.
```

## App Review — Notes

Reviewers see an empty app and no login. Say so before they ask:

```
Die App hat bewusst keine Registrierung und keinen Login — sie startet sofort einsatzbereit. Es gibt daher keinen Demo-Account.

Beim ersten Start ist die App leer. Um Daten zu sehen, entweder unter "Konten" ein Konto anlegen und unter "Einträge" einen Kontostand eintragen, oder in den Einstellungen "Backup importieren…" verwenden.

Zur Einordnung: FinanzGecko stellt KEINE Verbindung zu Banken her. Es gibt keinen Online-Banking-Zugang, kein PSD2, keine Kontoaggregation. Alle Werte werden manuell eingetragen. Die App speichert ausschließlich lokal und verschlüsselt.

Netzwerkverbindungen: ausschließlich api.frankfurter.dev für öffentliche EZB-Wechselkurse, und auch das nur nach ausdrücklicher Zustimmung im Einstellungsdialog. Die App-Store-Version enthält keine eigene Update-Prüfung.

Die App ist quelloffen: https://github.com/kreativ-anders/finanzgecko
```

## App Privacy — answers

**Data Collection: No** — "Data Not Collected". Accurate and easy to defend: no analytics, no identifiers, no
telemetry, no account. The only outbound call is an anonymous exchange-rate request carrying no user data.

## Screenshots

Required sizes: 1280×800, 1440×900, 2560×1600 or 2880×1800. Existing crops in
`docs/assets/screenshots/` are the right shots but likely the wrong dimensions — re-export via
`tool/capture_screenshots.sh` (see CLAUDE.md "Regenerating the website screenshots").

**Use `demo/finanzgecko-demo.json` — never real finances.** Suggested order, strongest first:

1. `finanzgecko-gesamtvermoegen-verlauf-prognose` — the headline: total plus trend
2. `finanzgecko-vermoegen-zusammensetzung-ueber-zeit` — the most distinctive chart
3. `finanzgecko-verteilung-nach-kontotyp-kennzahlen` — breakdown and KPIs
4. `finanzgecko-kontostaende-monatlich-erfassen` — shows how little work it is
5. `finanzgecko-konten-uebersicht` — the bank colours
6. `finanzgecko-vermoegenswerte-sachwerte` — the differentiator vs. pure account trackers

Dark theme first: it is the app's default and the website's default.
