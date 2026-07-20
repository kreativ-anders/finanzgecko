import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../state/app_state.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/reset_confirm_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/section_card.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.onExport,
    required this.onExportCsv,
    required this.onImport,
    required this.onNavigate,
  });

  final Future<void> Function() onExport;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onImport;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lastExport = app.lastExportAt;
    final dataDirectoryPath = app.dataDirectoryPath;
    final modKeyLabel = Platform.isMacOS ? '⌘' : 'Strg';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Basiswährung',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: app.baseCurrency,
                    isExpanded: true,
                    items: [for (final c in kCurrencies) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) {
                      if (v == null) return;
                      context.read<AppState>().setBaseCurrency(v);
                      showSavedSnackBar(context, onNavigate);
                    },
                  ),
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Erscheinungsbild',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Steuert die Hell-/Dunkel-Darstellung der App. "System" folgt der Einstellung deines '
                  'Betriebssystems.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text('Hell'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text('Dunkel'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {app.themeMode},
                  onSelectionChanged: (selection) {
                    context.read<AppState>().setThemeMode(selection.first);
                    showSavedSnackBar(context, onNavigate);
                  },
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Sicherheit',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kPrimary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, color: kPrimary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Verschlüsselung aktiv',
                            style: TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Deine Daten werden ausschließlich lokal auf diesem Gerät gespeichert und dort '
                  'verschlüsselt abgelegt. Der Schlüssel liegt im Anmeldeinformationsspeicher deines '
                  'Betriebssystems, nicht in der Datendatei selbst.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                _SecurityMetaRow(label: 'Verfahren', value: 'AES-256-GCM'),
                _SecurityMetaRow(label: 'Schlüsselspeicher', value: _keyStoreLabel()),
                _SecurityMetaRow(
                  label: 'Speicherort',
                  value: dataDirectoryPath,
                  onOpen: () => _openInFileManager(context, dataDirectoryPath),
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Benachrichtigungen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erinnert dich per nativer System-Benachrichtigung ans Backup-Exportieren und an fällige '
                  'Neubewertungen von Vermögenswerten — höchstens einmal je überfälligem Zustand, nicht bei jedem '
                  'App-Start erneut. Dafür muss die App laufen; es gibt keinen Hintergrunddienst, der '
                  'benachrichtigt, während sie geschlossen ist.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: noSelect(const Text('Desktop-Benachrichtigungen')),
                  value: app.notificationsEnabled,
                  onChanged: (v) => context.read<AppState>().setNotificationsEnabled(v),
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Export',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schreibt eine unverschlüsselte JSON-Datei mit allen Konten und Kontoständen an einen Ort deiner Wahl.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  lastExport != null ? 'Letzter Export: ${_formatDateTime(lastExport)}' : 'Noch nie exportiert.',
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(onPressed: onExport, child: noSelect(const Text('Backup exportieren…'))),
                    const SizedBox(width: 10),
                    Text('$modKeyLabel+${AppShortcuts.export.letter}', style: TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
                Divider(height: 28, color: kBorder),
                Text(
                  'Als Tabelle (CSV) für Excel/Numbers exportieren — alle Kontostände je Monat und Konto. '
                  'Kein Backup: die CSV kann nicht wieder importiert werden.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onExportCsv, child: noSelect(const Text('Als CSV exportieren…'))),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Import',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Achtung: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'Der Import ersetzt alle aktuell gespeicherten Daten vollständig.'),
                    ],
                  ),
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(onPressed: onImport, child: noSelect(const Text('Backup importieren…'))),
                    const SizedBox(width: 10),
                    Text('$modKeyLabel+${AppShortcuts.import_.letter}', style: TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          cardGap,
          const _HelpSection(),
          cardGap,
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDanger.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: kDanger, size: 20),
                    const SizedBox(width: 8),
                    Text('Zurücksetzen', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kDanger)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Setzt die Basiswährung auf ihren Standardwert zurück und löscht ALLE Konten, '
                  'Kontostände, Vermögenswerte und Fixposten unwiderruflich.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Erstelle vorher ggf. ein Backup über den Export oben — diese Aktion kann nicht rückgängig gemacht werden.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => _handleReset(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    side: const BorderSide(color: kDanger),
                  ),
                  child: noSelect(const Text('App zurücksetzen…')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReset(BuildContext context) async {
    final confirmed = await confirmReset(context);
    if (!confirmed) return;
    if (!context.mounted) return;
    await context.read<AppState>().resetAllData();
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'App wurde auf Standardwerte zurückgesetzt.');
  }
}

String _formatDateTime(DateTime date) {
  final d = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$d, $t';
}

String _keyStoreLabel() {
  if (Platform.isWindows) return 'Windows Anmeldeinformationsspeicher (Credential Locker)';
  if (Platform.isMacOS) return 'macOS Schlüsselbund (Keychain)';
  if (Platform.isLinux) return 'Linux Secret Service (libsecret/kwallet)';
  return 'Betriebssystem-Schlüsselspeicher';
}

/// Opens [path] in the OS file manager (Explorer/Finder/Nautilus & co.) via
/// a plain file:// URI — url_launcher's desktop backends hand that off to
/// the platform's native "open this folder" call (ShellExecute on Windows,
/// NSWorkspace on macOS, xdg-open/gio on Linux), so no extra plugin is
/// needed beyond what the app already uses for web links.
Future<void> _openInFileManager(BuildContext context, String path) async {
  final uri = Uri.file(path, windows: Platform.isWindows);
  final opened = await launchUrl(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ordner konnte nicht geöffnet werden.')));
  }
}

/// "Hilfe" section: system diagnostics useful when reporting a bug —
/// version+build come from [PackageInfo], which reads them from the native
/// package metadata each platform build embeds from pubspec.yaml's
/// `version:` (bumped by the release workflow's bump-version job before the
/// platform builds run), so this always reflects the actual installed
/// release rather than a hardcoded string. Screen/window geometry comes from
/// `dart:ui` (`PlatformDispatcher.displays` + `MediaQuery`) — useful for
/// layout bug reports and to tell a multi-monitor setup from a single
/// built-in display. The API reachability check is a live probe (not the
/// cached "last successful rate" state), because it doubles as the privacy
/// answer: the Wechselkurs-API is the app's only external network
/// destination, no telemetry/analytics of any kind.
class _HelpSection extends StatelessWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context) {
    final displays = ui.PlatformDispatcher.instance.displays;
    final displayLabel = displays
        .map((d) => '${(d.size.width / d.devicePixelRatio).round()}×${(d.size.height / d.devicePixelRatio).round()}')
        .join(' · ');
    final windowSize = MediaQuery.sizeOf(context);

    return SectionCard(
      title: 'Hilfe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Angaben zur installierten Version und zum System — hilfreich, wenn du ein Problem meldest.',
            style: TextStyle(color: kMuted),
          ),
          const SizedBox(height: 14),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return _SecurityMetaRow(
                label: 'Version',
                value: info == null ? '…' : '${info.version} (Build ${info.buildNumber})',
              );
            },
          ),
          _SecurityMetaRow(
            label: 'Betriebssystem',
            value: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          ),
          _SecurityMetaRow(label: 'Prozessorkerne', value: '${Platform.numberOfProcessors}'),
          _SecurityMetaRow(label: 'Systemsprache', value: Platform.localeName),
          _SecurityMetaRow(label: 'Dart-Laufzeit', value: Platform.version.split(' ').first),
          _SecurityMetaRow(
            label: displays.length > 1 ? 'Bildschirme (${displays.length})' : 'Bildschirm',
            value: displayLabel,
          ),
          _SecurityMetaRow(label: 'Fenstergröße', value: '${windowSize.width.round()}×${windowSize.height.round()}'),
          FutureBuilder<bool>(
            future: context.read<AppState>().currencyService.isApiReachable(),
            builder: (context, snapshot) {
              final label = switch (snapshot.connectionState) {
                ConnectionState.done => (snapshot.data ?? false) ? 'Erreichbar' : 'Nicht erreichbar',
                _ => 'Prüfe…',
              };
              return _SecurityMetaRow(label: 'Wechselkurs-API', value: label);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Der Abruf der EZB-Wechselkurse (api.frankfurter.dev) ist die einzige externe '
            'Netzwerkverbindung der App — sonst findet keine Kommunikation statt, kein Tracking, '
            'keine Analyse-Dienste.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
          Divider(height: 28, color: kBorder),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: _openSupportMail,
                child: noSelect(const Text('E-Mail-Support', style: TextStyle(color: kPrimary, fontSize: 13))),
              ),
              InkWell(
                onTap: _openIssueTracker,
                child: noSelect(const Text('Fehler melden (GitHub)', style: TextStyle(color: kPrimary, fontSize: 13))),
              ),
              InkWell(
                onTap: () => _copyDebugInfo(context, displayLabel, windowSize),
                child: noSelect(
                  const Text('Debug-Informationen kopieren', style: TextStyle(color: kPrimary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _openSupportMail() async {
  final uri = Uri.parse('mailto:finanzgecko@kreativ-anders.de?subject=Support-Anfrage');
  await launchUrl(uri);
}

Future<void> _openIssueTracker() async {
  final uri = Uri.parse('https://github.com/kreativanders/finanzgecko/issues/new');
  await launchUrl(uri);
}

Future<void> _copyDebugInfo(BuildContext context, String displayLabel, Size windowSize) async {
  final currencyService = context.read<AppState>().currencyService;
  final info = await PackageInfo.fromPlatform();
  final apiReachable = await currencyService.isApiReachable();
  final text = [
    'FinanzGecko ${info.version} (Build ${info.buildNumber})',
    'Betriebssystem: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'Prozessorkerne: ${Platform.numberOfProcessors}',
    'Systemsprache: ${Platform.localeName}',
    'Dart-Laufzeit: ${Platform.version.split(' ').first}',
    'Bildschirm(e): $displayLabel',
    'Fenstergröße: ${windowSize.width.round()}×${windowSize.height.round()}',
    'Wechselkurs-API erreichbar: ${apiReachable ? 'ja' : 'nein'}',
  ].join('\n');
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debug-Informationen kopiert.')));
}

/// Read-only "label: value" line used for non-sensitive encryption meta
/// info in the security section — builds trust without exposing anything
/// an attacker could use (algorithm name and storage path are public
/// implementation facts, not secrets). When [onOpen] is set, an "open in
/// file manager" button is shown after the value.
class _SecurityMetaRow extends StatelessWidget {
  const _SecurityMetaRow({required this.label, required this.value, this.onOpen});

  final String label;
  final String value;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: kMuted, fontSize: 13)),
          ),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
          if (onOpen != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  tooltip: 'Im Dateimanager öffnen',
                  icon: Icon(Icons.folder_open, color: kMuted),
                  onPressed: onOpen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
