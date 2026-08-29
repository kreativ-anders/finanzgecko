# FinanzGecko — Corporate Design

**Purpose of this document:** FinanzGecko's visual identity — color palette, brand-color rules, typography, and app
icon — kept compact and code-free, for marketing material, presentations, or external design work. For the technical
implementation of these values in code, see [`dev/ai/design-tokens.md`](dev/ai/design-tokens.md); keep both documents in sync whenever a color/typography change is made.

## Brand

FinanzGecko is a private, local net-worth tracker — no cloud service, no subscription, no tracking of your own
financial data. The visual language reflects that: calm, reduced, dark as the base tone, with a single clear accent
(mint green) instead of a colorful palette. The name combines the German word for "finance" ("Finanzen") with a
gecko — watchful, agile, unobtrusive — as a mascot, not a gimmick.

## App Icon

![FinanzGecko App Icon](assets/icon/icon.png)

A bar chart whose rightmost, tallest bar transitions into a gecko-head silhouette — mint green on a near-black
background. A single 1024×1024 master feeds all platform icon formats (macOS/Windows/Linux, taskbar, dock, start
menu).

## Colors

Dark is the app's default appearance; Light is selectable. The three brand colors (mint, coral, amber) stay
identical in both variants — they are brand identity, not theme-dependent styling.

### Accent colors

<table style="width:100%; border-collapse:collapse; margin:0.5em 0 1.5em;">
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#00C878; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Primary — Mint Green</strong> · <code>#00C878</code><br/><span style="color:#555;">Buttons, active states, app icon, the „🦎 FinanzGecko" wordmark, positive trends</span></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#FF6B6B; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Danger — Coral</strong> · <code>#FF6B6B</code><br/><span style="color:#555;">Errors, losses, destructive actions (e.g. deleting)</span></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#E0A030; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Warning — Amber</strong> · <code>#E0A030</code><br/><span style="color:#555;">non-critical warnings, e.g. an incompletely recorded month — deliberately milder than coral</span></td>
</tr>
</table>

**As body text or an icon glyph** (rather than as a fill), all three colors are too pale in the light theme to stay
reliably readable. For that there is a slightly darkened text variant of each, which stays unchanged in the dark
theme:

<table style="width:100%; border-collapse:collapse; margin:0.5em 0 1.5em;">
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#00814D; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Primary-Text (light only)</strong> · <code>#00814D</code></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#BA4E4E; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Danger-Text (light only)</strong> · <code>#BA4E4E</code></td>
</tr>
<tr>
<td style="width:64px; padding:6px 0;"><div style="width:48px; height:48px; border-radius:10px; background:#936920; border:1px solid rgba(0,0,0,0.12);"></div></td>
<td style="padding:6px 12px; vertical-align:middle;"><strong>Warning-Text (light only)</strong> · <code>#936920</code></td>
</tr>
</table>

**Rule:** Mint/Coral/Amber as a fill (button, badge background, chart line) — the text variant as type, an icon
glyph, or a border/focus ring on a light background. Exception: the „🦎 FinanzGecko" wordmark always stays the
original mint; brand names are exempt from the contrast rule.

### Surfaces (theme-dependent)

| Label | Dark (default) | Light | Used for |
|---|---|---|---|
| Background | `#0A0F0C` | `#F4F7F5` | App window |
| Surface | `#101713` | `#FFFFFF` | Cards, dialogs |
| Border | `#1C2721` | `#DCE3DE` | Dividers, card borders |
| Muted text | `#7C8A83` | `#5B6B62` | secondary labels, icons |
| Text (solid) | `#FFFFFF` | `#10160F` | body text |

### Trend and Kontotyp colors

**Forecast line** (deliberately paler than the accent colors, identical in both themes): Up `#8FE3B3` ·
Down `#FFC98A` · Neutral `#A6B0A9`.

**Kontotyp colors** (fallback when no bank name is set, e.g. cash/crypto): Girokonto `#00C878` ·
Tagesgeld `#2FD0A0` · Depot `#7EE6C0` · Bargeld `#C9D6CF` · Krypto `#F5A623`.

### Bank colors

Every recorded Konto can carry its bank's **official brand color** (hand-researched from the logo/brand kit, never a
guessed value) — as a small fill or dot next to the Konto's name. Some bank colors are very dark or very light
(e.g. pure black or a bright yellow) and would be unreadable as a text color; in that case a contrast-safe but
hue-matched variant is used automatically whenever the color tints text rather than a fill.

## Typography

No custom brand font — the app consistently uses each platform's native system font:

- **macOS** — SF Pro (San Francisco)
- **Windows** — Segoe UI
- **Linux** — depends on the desktop environment, typically Ubuntu or Cantarell

Numbers always appear in German format — comma as the decimal separator, period as the thousands separator, e.g.
`24.180,42 €`.
