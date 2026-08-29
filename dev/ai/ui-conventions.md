# FinanzGecko — UI conventions

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

**Color palette, brand-color rules, typography, app icon — reader-friendly for designers:** see
[`CORPORATE_DESIGN.md`](../../CORPORATE_DESIGN.md), deliberately kept compact and code-free (audience: design,
marketing, external design work). The technical implementation of these tokens (getter mechanics, contrast
fallbacks, sync obligations with `theme.dart`/`constants.dart`) lives instead in
[design-tokens.md](design-tokens.md). This file covers interaction patterns and behavior (navigation, dialogs, formats, notifications, charts,
splash).

## Empty states and entry points

- The Dashboard's empty state is **staged**: no Konto → "Konto anlegen"; a Konto but no Kontostand → "Einträge
  erfassen". The call to action always names what is actually missing, never a generic "get started".
- On the Dashboard, the **whole Konto card is the click target**, not just its 70px mini chart — the chart alone
  is too small a hit area to be discovered.
- The Zeitraum filter is a global control and sits **top right, anchored to the top of the block**, not on the
  baseline of the "erfasst" caption: it governs the whole Dashboard, not the line it stands next to.

## Reading order inside a card

The number meant to be read at a glance gets the type weight; everything supporting it is demoted to a smaller
second line. Verlauf/Prognose shows the monthly rate large, basis and endpoint small; the Konto cards show the
amount large and the month-over-month change under it.

Blocks **without** a `SectionCard` border of their own get asymmetric padding (top 16 / bottom 4): `cardGap` (20)
plus the next card's own 20px top padding already separate them. A symmetric 16 made the gap to "Verlauf" nearly
five times the intra-block line gap.

## Dialogs and permissions

- The **exchange-rate consent dialog** appears only from the two places that actually need a rate (Einträge and
  Fixposten, while saving) — never on opening a view, and never from Einstellungen, where an unprompted
  permission dialog would be baffling. The decision is reversible under Einstellungen → Wechselkurse.
- **Desktop notifications are opt-in.** macOS (`UNUserNotificationCenter`) shows its authorization dialog only on
  the very first call ever, so the toggle cannot re-ask after a denial — a refused user has to change it in the
  Systemeinstellungen, and the UI says so instead of silently doing nothing. Linux and Windows know no such
  authorization and always grant. `AppState.setNotificationsEnabled` therefore persists `true` only when
  authorization was actually granted, and returns the effective value so the caller can explain a refusal: a
  toggle standing on while the OS suppresses every notification would be a lie.
- The **foreign-data screen** (`_ForeignDataApp`) explains "this file belongs to another computer" in everyday
  language and deliberately avoids the words key, Keychain and encryption: someone who knows the file from a
  cloud folder expects it to open anywhere, and the text has to clear that expectation and point at
  export/import — not teach cryptography.
- An entered Kontostand an order of magnitude off the account's last one is flagged as a **likely mistyped
  digit**, deliberately non-blocking: a genuine large move still saves.

## Charts and accessibility

All three Dashboard charts render with `excludeSemantics` plus a hand-written `Semantics` label that replaces the
**purely graphical** part only — line: span + trend/forecast; donut: largest share; stacked area: span + current
total. The itemized legend below each chart is already real, readable text; duplicating it into the label would
make a screen reader say everything twice.

## Error wording

Data-layer exceptions (`app_store.dart`) deliberately carry **no message text**. The German user-facing wording
is composed in exactly one place, `describeError` (`ui/widgets/app_snackbar.dart`), so it is not re-derived ad hoc
at each catch site.

## Theme initialization order

Two ordering constraints that fail silently when broken: `primeThemeBrightness()` must run **before**
`WindowOptions` is built (its `backgroundColor` reads `kBackground`, which still holds the dark default until
then), and `buildAppTheme()` must be called from an inner `Builder` **under** `ThemeScope`, not as `ThemeScope`'s
child argument, or it evaluates against the previous brightness.

## Where the backup flow lives

Export/import are free functions in `ui/backup_actions.dart`, not methods on `NavigationShell`, so navigation and
the backup feature each keep their own primary file — matching the `navigation` / `backup_restore` feature split
in [testing.md](testing.md).
