# FinanzGecko — Corporate Design

**Zweck dieses Dokuments:** Die visuelle Identität von FinanzGecko — Farbpalette, Markenfarben-Regeln, Typografie
und App-Icon — kompakt und ohne Code-Bezug, für Marketingmaterial, Präsentationen oder externe Gestaltung. Für die
technische Umsetzung dieser Werte im Code siehe [`AI_MASTER.md`](AI_MASTER.md) §5 "Farbtoken — technische
Umsetzung"; beide Dokumente sind bei jeder Farb-/Typografie-Änderung gemeinsam zu pflegen.

## Marke

FinanzGecko ist ein privater, lokaler Vermögenstracker — kein Cloud-Dienst, kein Abo, kein Tracking der eigenen
Finanzdaten. Die visuelle Sprache spiegelt das: ruhig, reduziert, dunkel als Grundton, mit einem einzigen klaren
Akzent (Mint-Grün) statt einer bunten Palette. Der Name kombiniert "Finanzen" mit einem Gecko — wachsam, wendig,
unauffällig — als Maskottchen, nicht als Spielerei.

## App-Icon

![FinanzGecko App-Icon](assets/icon/icon.png)

Ein Balkendiagramm, dessen rechter, höchster Balken in eine Gecko-Kopf-Silhouette übergeht — Mint-Grün auf
fast-schwarzem Grund. Ein einziger 1024×1024-Master speist alle Plattform-Icon-Formate (macOS/Windows/Linux,
Taskleiste, Dock, Startmenü).

## Farben

Dunkel ist das Standard-Erscheinungsbild der App; Hell ist wählbar. Die drei Markenfarben (Mint, Koralle, Amber)
bleiben in beiden Varianten identisch — sie sind Markenidentität, keine themenabhängige Gestaltung.

### Akzentfarben

<table style="width:100%; border-collapse:collapse; margin:0.5em 0 1.5em;">
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#00C878; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Primary — Mint-Grün</strong> · <code>#00C878</code><br/><span style="color:#555;">Buttons, aktive Zustände, App-Icon, Schriftzug „🦎 FinanzGecko", positive Trends</span></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#FF6B6B; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Danger — Koralle</strong> · <code>#FF6B6B</code><br/><span style="color:#555;">Fehler, Verluste, destruktive Aktionen (z. B. Löschen)</span></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#E0A030; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Warning — Amber</strong> · <code>#E0A030</code><br/><span style="color:#555;">unkritische Warnungen, z. B. ein unvollständig erfasster Monat — bewusst milder als Koralle</span></td>
</tr>
</table>

**Als Fließtext oder Icon-Glyph** (statt als Fläche) wirken alle drei Farben im hellen Theme zu blass, um zuverlässig
lesbar zu sein. Dafür gibt es je eine leicht abgedunkelte Text-Variante, die im dunklen Theme unverändert bleibt:

<table style="width:100%; border-collapse:collapse; margin:0.5em 0 1.5em;">
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#00814D; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Primary-Text (nur Hell)</strong> · <code>#00814D</code></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#BA4E4E; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Danger-Text (nur Hell)</strong> · <code>#BA4E4E</code></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#936920; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Warning-Text (nur Hell)</strong> · <code>#936920</code></td>
</tr>
</table>

**Regel:** Mint/Koralle/Amber als Fläche (Button, Badge-Hintergrund, Chart-Linie) — die Text-Variante als Schrift,
Icon-Glyph oder Rahmen/Fokusring auf hellem Grund. Ausnahme: der Schriftzug „🦎 FinanzGecko" bleibt immer im
Original-Mint, Markennamen sind von der Kontrastregel ausgenommen.

### Oberflächen (theme-abhängig)

| Bezeichnung | Dunkel (Standard) | Hell | Verwendung |
|---|---|---|---|
| Hintergrund | `#0A0F0C` | `#F4F7F5` | App-Fenster |
| Fläche | `#101713` | `#FFFFFF` | Karten, Dialoge |
| Rahmen | `#1C2721` | `#DCE3DE` | Trennlinien, Card-Border |
| Gedämpfter Text | `#7C8A83` | `#5B6B62` | sekundäre Beschriftung, Icons |
| Text (volltonig) | `#FFFFFF` | `#10160F` | Lesetext |

### Trend- und Kontotyp-Farben

**Prognose-Linie** (bewusst blasser als die Akzentfarben, in beiden Themes gleich): Aufwärts `#8FE3B3` ·
Abwärts `#FFC98A` · Neutral `#A6B0A9`.

**Kontotyp-Farben** (Fallback, wenn kein Bankname hinterlegt ist, z. B. Bargeld/Krypto): Girokonto `#00C878` ·
Tagesgeld `#2FD0A0` · Depot `#7EE6C0` · Bargeld `#C9D6CF` · Krypto `#F5A623`.

### Bankfarben

Jedes hinterlegte Konto kann seine **offizielle Markenfarbe** der jeweiligen Bank tragen (von Hand recherchiert aus
Logo/Brand-Kit, keine geratenen Werte) — als kleine Fläche oder Punkt neben dem Kontonamen. Manche Bankfarben sind
sehr dunkel oder sehr hell (z. B. reines Schwarz oder ein grelles Gelb) und wären als Schriftfarbe unlesbar; dort
wird automatisch eine kontrastsichere, aber farbtongleiche Variante eingesetzt, sobald die Farbe Text statt Fläche
einfärbt.

## Typografie

Kein eigenes Markenfont — die App nutzt konsequent die native Systemschrift der jeweiligen Plattform:

- **macOS** — SF Pro (San Francisco)
- **Windows** — Segoe UI
- **Linux** — je nach Desktop-Umgebung, i. d. R. Ubuntu oder Cantarell

Zahlen erscheinen durchgehend im deutschen Format — Komma als Dezimaltrennzeichen, Punkt als Tausendertrennzeichen,
z. B. `24.180,42 €`.
