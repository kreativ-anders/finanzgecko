# FinanzGecko — Color tokens — technical implementation

> Part of the AI reference set in `dev/ai/`. Map of all files: [CLAUDE.md](../../CLAUDE.md).

- **Only four tokens differ per theme:** `kBackground`, `kSurface`, `kBorder`, `kMuted`, plus `kTextPrimary`
  (full-strength reading text on `kBackground`/`kSurface`, e.g. splash screen, chart tooltips, month picker —
  replaces the earlier hardcoded `Colors.white` spots), all in `lib/ui/theme.dart`. Every other color —
  `kPrimary` (`#00C878`), `kDanger` (`#FF6B6B`), `kWarning` (`#E0A030`), `kTrendUp/Down/Neutral` — is
  **deliberately identical across both themes** (brand colors, no reinterpretation). These four dynamic tokens
  (plus `kTextPrimary`) are top-level **getters** (no longer `const`), reading the `Brightness` value most
  recently resolved by `ThemeScope` — `ThemeScope` sits in `main.dart` above `MaterialApp` (inside a
  `Consumer<AppState>` that rebuilds on every `setThemeMode()`) and resolves `AppThemeMode.system` against
  `MediaQuery.platformBrightnessOf(context)`. Any place referencing one of these tokens therefore **must not** be
  `const` (the Dart compiler aborts with "Invalid constant value" if it is — a reliable marker when reviewing).
  These hex values must stay in sync with `kPrimaryHex`/`kDangerHex` in `constants.dart` (string form for the
  on-disk Konto color field vs. `Color` form for the theme). **Still open:** dedicated light/dark variants for the
  taskbar/dock icon (currently one single icon for both themes, see the icon pipeline in [platform.md](platform.md)).
- **`kPrimaryText`/`kDangerText`/`kWarningText`** (`lib/ui/theme.dart`, same getter pattern as above): WCAG-2.1-AA-
  safe variants of `kPrimary`/`kDanger`/`kWarning` for use as **text/icon color** (as opposed to a fill/chart
  line/button background). `kPrimary` & co. deliberately stay theme-identical as a brand/fill color (see above) —
  but as a text color on the light theme, all three fall short of the 4.5:1 minimum contrast requirement
  (~2.0–2.8:1 against `kBackground`/`kSurface` light). The `*Text` getters return exactly the original constant on
  the dark theme (already ≥6.9:1 there) and only on the light theme a darker, same-hue variant
  (`#00814D`/`#BA4E4E`/`#936920`, all ≥4.5:1 against `#F4F7F5`/`#FFFFFF`). Rule: **any spot where one of the three
  brand colors colors a text line, a standalone icon glyph, or a focus/border indicator
  (`InputDecorationTheme.focusedBorder`) uses the `*Text` variant** — fills (button/chip background,
  `AppLineChart` line color, colored badges with dark text on top) stay on the original constant. Exception: the
  brand wordmark "🦎 FinanzGecko" in the header (`navigation_shell.dart`) stays `kPrimary`, since logos/brand
  names are exempt from the contrast requirement under WCAG 1.4.3. **The same rule applies to
  `docs/assets/style.css`**, which mirrors the app's tokens: the bug already happened there once — the
  JS-highlighted download card (`.download-card-primary`) got `border-color: var(--primary)` and was invisible on
  the light theme at 2.2:1 against `--surface`, while the badge above it (`--primary-text`, 4.9:1) rendered
  correctly. A second case, found in the quality audit ([quality-audit.md](quality-audit.md)): `.card.warn` colored its left border indicator with
  `--danger` (2.6:1 against `--bg` light). That's why `style.css` now also has — analogous to the app — a
  `--danger-text` (`#FF6B6B` dark / `#BA4E4E` light, mirroring `kDangerText`); `--danger` stays as the brand color
  but is currently referenced nowhere else. **A third case, same cause, August 2026:** the new `.download-note`
  (backup recommendation on `download.html`) initially got its left border indicator with `--primary` — 2.2:1
  against `--surface` light, while `.card.note` right below it in the same file had long since used
  `--primary-text`. That the rule got violated the same way three times despite being documented is the actual
  finding: **when adding a new border/focus indicator, reach for an existing
  `border-left: 3px solid var(--*-text)` first** rather than the brand color. Fills stay unchanged on
  `--primary`/`--danger`.
- **Bank colors are logo colors, not text colors.** `kBanks` includes among others `#000000` (Trade Republic, C24,
  Mercedes-Benz Bank) and `#ffe600` (comdirect) — fine as a fill or a 10px dot, unreadable as a label on
  `kSurface` (down to 1.06:1 in the worst case). Where a Konto color colors **text** (currently the Kontotyp chip
  on the Dashboard Konto cards), it therefore passes through `readableOn(hex, kSurfaceHex)` in `constants.dart`: a
  pure hex-to-hex function that mixes toward white or black in 2% steps until 4.5:1 is reached, and otherwise
  passes it through unchanged. The chip's **fill** deliberately keeps the unfiltered brand color (15% opacity) —
  backgrounds have no contrast requirement, and it's what makes the chip look like the bank. 51 of 96
  combinations (48 colors × 2 themes) need the correction; that **all** of them converge is guarded by a scenario
  in `gherkin/executable/account_color.feature`.

- **No native menu** on Linux/Windows (Flutter's `PlatformMenuBar` is macOS-only) → an in-app "Datei" area in the
  window header, identical across platforms, plus global keyboard shortcuts (`Strg`/`⌘`+E/I/Q) via `CallbackShortcuts`.
- **Money/number format:** always via `fmtMoney`/`fmtPercent`/`fmtInputNumber`/`parseInputNumber` from
  `formatting.dart` — German format (`de_DE`, comma as the decimal separator), but the parser also accepts the
  old dot notation for backward compatibility.
- **The `noSelect()` helper** (`theme.dart`) excludes button labels/nav chrome from the app-wide `SelectionArea`
  (in `main.dart`) — only content text should be selectable/copyable. **This is also a prerequisite for the
  correct mouse cursor:** the `SelectionArea` places a text cursor over every selectable `Text`, and that sits
  *deeper* in the tree than the click cursor of the enclosing `InkWell`/`TextButton` — on a tie, the deeper one
  wins, so the pointer never turns into a hand. Rule: **every clickable element whose label is a `Text` wraps that
  label in `noSelect(...)`** (buttons, nav entries, clickable cards, `ListTile` suggestions). An explicit
  `mouseCursor` isn't needed then — Material buttons and `InkWell` already request the click cursor themselves.
  Elements without a text child (`IconButton`, `Switch`) are never affected; input fields correctly keep the text
  cursor, and the hover charts (`line_chart.dart`, `stacked_area_chart.dart`) deliberately stay at the default
  cursor, since they don't trigger anything, only show a tooltip.
- **Confirmation dialogs:** simple yes/no (`AlertDialog`) for reversible-ish actions (archive, delete); for the
  **one true "point of no return" action** (resetting the app), a **typed confirmation phrase**
  (`ZURÜCKSETZEN`, `reset_confirm_dialog.dart`) instead of a simple click.
- **Inline edit with debounce** (600 ms, `Timer`) for Vermögenswerte and Fixposten — no explicit "Speichern"
  needed, saves automatically on typing pause/focus loss/Enter.
- **Reminder/banner order on the Dashboard** (`dashboard_view.dart`): update reminder → overspend banner (only if
  the Fixposten net is negative) → backup reminder → asset reminder. This order is deliberate (urgency).
- **Desktop notifications** (Einstellungen → "Benachrichtigungen", **off by default, opt-in**): mirror the
  backup and asset reminders additionally as a native OS notification, so they're seen even when the Dashboard
  isn't currently open. Fires **episode-based, exactly once** per newly-entered overdue state (not on every app
  start) and **only while the app is running** — no background service, see [platform.md](platform.md) and
  `gherkin/notifications.feature`. The Dashboard banners are the primary channel and are unaffected by the
  toggle; the notification only duplicates them outside the window.
  **Why opt-in.** macOS needs `UNUserNotificationCenter` authorization, and the app asks the user for nothing
  else. So `NotificationService.init()` runs at startup with all `request*Permission` flags false and never
  prompts; the prompt belongs to `requestPermission()`, which only the toggle calls. A refusal is not hidden:
  `AppState.setNotificationsEnabled()` stores `true` only if authorization was granted and returns what it
  stored, and the Einstellungen switch shows a Snackbar pointing at Systemeinstellungen → "Mitteilungen" when
  the OS said no — macOS asks a given user only once, so the app cannot re-prompt. Linux and Windows have no
  such authorization and always grant it.
- **Mouse hover on all three Dashboard charts** (`AppLineChart`, `AppDonutChart`, `AppStackedAreaChart`, all in
  `lib/ui/widgets/`): Verlauf and Zusammensetzung über Zeit show a vertical guide line + tooltip (period, per
  series a color dot/name/amount, for the composition chart additionally the share in %), hand-built via
  `MouseRegion`/`setState` instead of fl_chart's own touch system — the latter demonstrably lost the hover state
  unpredictably between adjacent positions with continuous x positions (time series). The distribution donut, by
  contrast, deliberately uses fl_chart's own `PieTouchData`: there, touch resolution is a discrete "which segment"
  hit test without the position interpolation that was the problem for the line chart; the hovered segment grows
  slightly, Kontotyp + share appear in the empty inner circle. Tooltip rows with differently long labels get a
  **fixed, right-aligned column width** for amount/share instead of plain text after an `Expanded` label — the
  latter produces a row-to-row inconsistent (visually restless) gap before the number.
- **Readable line width:** running text in a Dashboard card (e.g. the foreign-currency rounding note) is capped
  at a fixed `maxWidth` (`ConstrainedBox`), instead of running the full, very long card/dashboard width on wide
  windows (up to 1100px, see `navigation_shell.dart`).
- **Splash duration (1100ms hold + 400ms crossfade, `splash_screen.dart`)** is a deliberate branding, not a
  loading, decision: `main()` calls `windowManager.show()` **before** `runApp()`, so the window is already
  visible (empty, in `kBackground`) before the splash even appears — both values add to this init time, so the
  start feels branded for ~1.5s overall. A shorter duration would make the start noticeably snappier; that was
  specifically evaluated (issue #11) and rejected. Don't change the values without discussing it first.
