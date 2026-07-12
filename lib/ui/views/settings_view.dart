import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../data/app_store.dart';
import '../../state/app_state.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/reset_confirm_dialog.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/section_card.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.onExport, required this.onImport, required this.onNavigate});

  final Future<void> Function() onExport;
  final Future<void> Function() onImport;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lastExport = app.store.lastExportAt;
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
                const Text('Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.', style: TextStyle(color: kMuted)),
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
                const Text(
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
                  value: AppStore.resolveDataDirectory().path,
                  onOpen: () => _openInFileManager(context, AppStore.resolveDataDirectory().path),
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
                const Text('Schreibt eine unverschlüsselte JSON-Datei mit allen Konten und Kontoständen an einen Ort deiner Wahl.', style: TextStyle(color: kMuted)),
                const SizedBox(height: 6),
                Text(
                  lastExport != null ? 'Letzter Export: ${_formatDateTime(lastExport)}' : 'Noch nie exportiert.',
                  style: const TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(onPressed: onExport, child: noSelect(const Text('Backup exportieren…'))),
                    const SizedBox(width: 10),
                    Text('$modKeyLabel+E', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Import',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Achtung: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    Text('$modKeyLabel+I', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
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
                const Text(
                  'Setzt die Basiswährung auf ihren Standardwert zurück und löscht ALLE Konten, '
                  'Kontostände, Vermögenswerte und Fixposten unwiderruflich.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Erstelle vorher ggf. ein Backup über den Export oben — diese Aktion kann nicht rückgängig gemacht werden.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => _handleReset(context),
                  style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger)),
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
            child: Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
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
                  icon: const Icon(Icons.folder_open, color: kMuted),
                  onPressed: onOpen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
