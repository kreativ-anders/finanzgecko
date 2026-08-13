# FinanzGecko 🦎

Native desktop net-worth tracker. No server, no cloud, no account — all data lives in a single JSON file in the
app's own data directory. Built with [Flutter](https://flutter.dev), runs locally on Linux, macOS, and Windows.

Download for end users: [Website](https://finanzgecko.app/) ·
[Download page](https://finanzgecko.app/download.html)

## Built with AI — spec-first, not vibe-coded

This entire codebase was written by AI (Claude), but not through freeform "vibe coding." Every behavior is
specified as a [Gherkin](https://cucumber.io/docs/gherkin/) scenario in [gherkin/](gherkin/) and tied to
[AI_MASTER.md](AI_MASTER.md), the single source of truth for architecture, data models, and conventions. New
work navigates spec → owning file → test instead of re-deriving context from the whole repo each time — which
keeps generated code consistent with what's already there, and keeps the context/token cost of each change down.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the actual workflow.

## License

[GPL-3.0](LICENSE) with a ["Commons Clause"](https://commonsclause.com/) addition: source freely viewable,
modifiable, and redistributable (copyleft — derivatives stay under the same terms), but **no commercial use**. The
app itself stays free for end users via [GitHub Releases](https://github.com/kreativ-anders/finanzgecko/releases);
further development is funded voluntarily through "Pay what you want" (Stripe) on the website.

## Quick start

```bash
flutter pub get
flutter run -d linux   # or -d macos / -d windows
```

Requires the Flutter desktop toolchain for your platform — setup: [dev/setup.md](dev/setup.md). Release builds,
packaging, and the icon pipeline: [dev/building.md](dev/building.md).

## Architecture

| File/Folder | Purpose |
|---|---|
| `lib/main.dart` | Entry point: window setup, store initialization, `runApp()` |
| `lib/data/app_store.dart` | Persistence: encrypted JSON file, atomic writes |
| `lib/data/app_schema.dart` | In-memory schema of the data file |
| `lib/models/` | Data classes (`Account`, `Balance`, `Asset`, `Subscription`) |
| `lib/services/currency_service.dart` | Exchange rates (Frankfurter.app) with cache |
| `lib/state/app_state.dart` | Central `ChangeNotifier` — CRUD + derived values for the UI |
| `lib/ui/views/` | The six views: Dashboard, Einträge, Konten, Fixposten, Vermögenswerte, Einstellungen |
| `lib/utils/analysis.dart` | Pure, testable computation logic (trend, projection, KPIs) |
| `gherkin/` | Behavioral specification (Gherkin) |

Full reference (data flow, domain glossary, feature↔test mapping): [AI_MASTER.md](AI_MASTER.md) (German — see
"Sprache der Doku" in §3 for why). Architecture decisions in detail (encryption, why no DB engine, window
behavior): [dev/architecture.md](dev/architecture.md).

## Contributing

Workflow, spec-first approach, checks before committing: [CONTRIBUTING.md](CONTRIBUTING.md).

## Known limitations

No background auto-updater — "Nach Updates suchen" only runs when you ask for it. macOS builds are signed with a
Developer ID and notarized, so they start without a warning; Windows builds are unsigned and still trigger a
SmartScreen prompt on first launch. Details and workarounds: [dev/troubleshooting.md](dev/troubleshooting.md).
