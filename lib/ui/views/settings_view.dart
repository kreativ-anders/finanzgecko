import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../../utils/file_manager.dart';
import '../../utils/formatting.dart';
import '../../utils/update_assets.dart';
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
          // INFO: shown even before consent was ever asked; displaying it never triggers a fetch itself.
          SectionCard(
            title: 'Wechselkurse',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beträge in Fremdwährung brauchen einen Wechselkurs. FinanzGecko kann ihn bei '
                  'api.frankfurter.dev abrufen (EZB-Referenzkurse) — dabei werden nur Währungspaar und Datum '
                  'übertragen, keine Beträge und keine Kontodaten. Ohne Abruf werden bereits gespeicherte '
                  'Kurse genutzt, sonst fragt die App dich nach dem Kurs.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                SegmentedButton<RateFetchConsent>(
                  segments: const [
                    ButtonSegment(
                      value: RateFetchConsent.unset,
                      label: Text('Noch nicht entschieden'),
                      icon: Icon(Icons.help_outline),
                    ),
                    ButtonSegment(
                      value: RateFetchConsent.granted,
                      label: Text('Abrufen'),
                      icon: Icon(Icons.cloud_download_outlined),
                    ),
                    ButtonSegment(
                      value: RateFetchConsent.denied,
                      label: Text('Nicht abrufen'),
                      icon: Icon(Icons.cloud_off_outlined),
                    ),
                  ],
                  selected: {app.rateFetchConsent},
                  onSelectionChanged: (selection) {
                    context.read<AppState>().setRateFetchConsent(selection.first);
                    showSavedSnackBar(context, onNavigate);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  app.rateFetchConsent == RateFetchConsent.unset
                      ? 'Solange nichts entschieden ist, wird nichts abgerufen. Gefragt wirst du erst, wenn '
                            'das erste Mal wirklich ein Kurs gebraucht wird.'
                      : 'Diese Entscheidung lässt sich hier jederzeit ändern.',
                  style: TextStyle(color: kMuted, fontSize: 12),
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
                const SizedBox(height: 8),
                Text(
                  // Only macOS has an authorization prompt to warn about.
                  Platform.isMacOS
                      ? 'Standardmäßig aus. Beim Einschalten fragt macOS einmalig um Erlaubnis.'
                      : 'Standardmäßig aus.',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: noSelect(const Text('Desktop-Benachrichtigungen')),
                  value: app.notificationsEnabled,
                  // Awaited because macOS can refuse and cannot be asked twice — see AppState.setNotificationsEnabled.
                  onChanged: (v) async {
                    final enabled = await context.read<AppState>().setNotificationsEnabled(v);
                    if (!v || enabled) return;
                    if (!context.mounted) return;
                    showErrorSnackBar(
                      context,
                      'Das Betriebssystem erlaubt keine Benachrichtigungen für FinanzGecko. '
                      'Ändern lässt sich das in den Systemeinstellungen unter "Mitteilungen".',
                    );
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
                          Icon(Icons.lock_outline, color: kPrimaryText, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Verschlüsselung aktiv',
                            style: TextStyle(color: kPrimaryText, fontSize: 12, fontWeight: FontWeight.w600),
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
                const SizedBox(height: 12),
                // Permanent, not a one-off dialog: this consequence must still be readable years later.
                _DeviceBoundHint(onExport: onExport),
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
                  'Schreibt eine JSON-Datei mit allen Konten und Kontoständen an einen Ort deiner Wahl — auf Wunsch '
                  'mit einem Passwort geschützt. Das ist deine einzige Sicherung, die sich auch auf einem anderen '
                  'Computer wieder einlesen lässt. Bewahre sie außerhalb dieses Rechners auf, etwa auf einer '
                  'externen Platte oder in einer Cloud.',
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
                  'Als Tabellen (CSV) für Excel/Numbers exportieren — vier Dateien in einen Ordner deiner Wahl: '
                  'Konten, Kontostände, Fixposten und Vermögenswerte. Kein Backup: CSV-Dateien lassen sich nicht '
                  'wieder importieren.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onExportCsv, child: noSelect(const Text('Als CSV-Tabellen exportieren…'))),
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
                    Icon(Icons.warning_amber_rounded, color: kDangerText, size: 20),
                    const SizedBox(width: 8),
                    Text('Zurücksetzen', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kDangerText)),
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
                    foregroundColor: kDangerText,
                    side: BorderSide(color: kDangerText),
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
  final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${fmtDate(date)}, $t';
}

String _keyStoreLabel() {
  if (Platform.isWindows) return 'Windows Anmeldeinformationsspeicher (Credential Locker)';
  if (Platform.isMacOS) return 'macOS Schlüsselbund (Keychain)';
  if (Platform.isLinux) return 'Linux Secret Service (libsecret/kwallet)';
  return 'Betriebssystem-Schlüsselspeicher';
}

// INFO: no parent detour any more — the macOS data dir was renamed from "de.finanzgecko.app" to
// "FinanzGecko" on 2026-08-14, so LaunchServices no longer mistakes it for an app bundle.
/// Opens the app's own data directory. Only for container paths on macOS — see [openFolderInFileManager].
Future<void> _openInFileManager(BuildContext context, String path) async {
  final opened = await openFolderInFileManager(path, Platform.operatingSystem);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ordner konnte nicht geöffnet werden.')));
  }
}

/// Shows a downloaded file in the file manager. Deliberately the FILE, not its folder: the sandbox grants
/// access to what the user picked in the save dialog, and asking for the folder instead is what produced
/// the macOS "keine Berechtigung, den Ordner zu öffnen" alert with nothing to grant.
Future<void> _revealInFileManager(BuildContext context, String filePath) async {
  final shown = await revealFileInFileManager(filePath, Platform.operatingSystem);
  if (!shown && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datei konnte nicht angezeigt werden.')));
  }
}

// INFO: the App Store build ([kIsMacAppStore]) drops the update entry and its GitHub sentence — guideline 2.4.5.
// INFO: for the app's two network occasions, both user-triggered, see dev/ai/stack.md.
/// "Hilfe" section: system diagnostics for bug reports, with a live API reachability probe.
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
          const _ApiReachabilityRow(),
          const SizedBox(height: 10),
          Text(
            kIsMacAppStore
                ? 'FinanzGecko baut von sich aus keine Netzwerkverbindung auf. Die EZB-Wechselkurse '
                      '(api.frankfurter.dev) werden nur abgerufen, wenn du das oben unter "Wechselkurse" erlaubt '
                      'hast. Sonst findet keine Kommunikation statt, kein Tracking, keine Analyse-Dienste. '
                      'Updates erhältst du über den App Store.'
                : 'FinanzGecko baut von sich aus keine Netzwerkverbindung auf. Die EZB-Wechselkurse '
                      '(api.frankfurter.dev) werden nur abgerufen, wenn du das oben unter "Wechselkurse" erlaubt '
                      'hast, und die öffentliche GitHub-Releases-API nur, wenn du unten explizit auf "Nach Updates '
                      'suchen" klickst. Sonst findet keine Kommunikation statt, kein Tracking, keine '
                      'Analyse-Dienste.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
          Divider(height: 28, color: kBorder),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              if (!kIsMacAppStore)
                InkWell(
                  onTap: () => _checkForUpdates(context),
                  child: noSelect(Text('Nach Updates suchen', style: TextStyle(color: kPrimaryText, fontSize: 13))),
                ),
              InkWell(
                onTap: _openSupportMail,
                child: noSelect(Text('E-Mail-Support', style: TextStyle(color: kPrimaryText, fontSize: 13))),
              ),
              InkWell(
                onTap: _openIssueTracker,
                child: noSelect(Text('Fehler melden (GitHub)', style: TextStyle(color: kPrimaryText, fontSize: 13))),
              ),
              InkWell(
                onTap: () => _copyDebugInfo(context, displayLabel, windowSize),
                child: noSelect(
                  Text('Debug-Informationen kopieren', style: TextStyle(color: kPrimaryText, fontSize: 13)),
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
  final uri = Uri.parse('https://github.com/kreativ-anders/finanzgecko/issues/new');
  await launchUrl(uri);
}

/// The site's per-OS download page — not GitHub's release page, which leaves picking the asset to the user.
const _downloadPageUrl = 'https://finanzgecko.app/download.html';

/// Manual, user-triggered update check ([UpdateService]) — never automatic; the file is verified, never run.
// INFO: unreachable in the App Store build; the null guard is the second lock, the missing UI entry the first.
Future<void> _checkForUpdates(BuildContext context) async {
  final appState = context.read<AppState>();
  final updater = appState.updateService;
  if (updater == null) return;
  final info = await PackageInfo.fromPlatform();
  final result = await updater.checkForUpdate(currentVersion: info.version);
  if (!context.mounted) return;

  switch (result.status) {
    case UpdateCheckStatus.upToDate:
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Du verwendest bereits die neueste Version (${info.version}).')));
    case UpdateCheckStatus.updateAvailable:
      final confirmed = await _showUpdateAvailableDialog(
        context,
        currentVersion: info.version,
        latestVersion: result.latestVersion!,
      );
      if (confirmed != true || !context.mounted) return;
      await _downloadUpdate(context, updater: updater, assets: result.assets);
    case UpdateCheckStatus.failed:
      showErrorSnackBar(context, 'Update-Prüfung fehlgeschlagen — bitte später erneut versuchen.');
  }
}

/// A dialog rather than a snackbar: this result is actionable and shouldn't be dismissed by accident.
Future<bool?> _showUpdateAvailableDialog(
  BuildContext context, {
  required String currentVersion,
  required String latestVersion,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Update verfügbar'),
      content: Text('Eine neue Version ($latestVersion) ist verfügbar. Du verwendest aktuell $currentVersion.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: noSelect(const Text('Später'))),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: noSelect(const Text('Herunterladen')),
        ),
      ],
    ),
  );
}

// INFO: the save dialog is deliberate — writing to ~/Downloads unprompted makes macOS raise its own prompt.
/// Downloads the release file for this platform, verifies it and saves it where the user chose.
Future<void> _downloadUpdate(
  BuildContext context, {
  required UpdateService updater,
  required Map<String, String> assets,
}) async {
  final assetName = selectAssetName(assets.keys, Platform.operatingSystem);
  // No asset for this platform: send the user to the download page rather than guess at a file.
  if (assetName == null) {
    await launchUrl(Uri.parse(_downloadPageUrl));
    return;
  }

  final location = await getSaveLocation(suggestedName: assetName);
  if (location == null || !context.mounted) return; // dialog cancelled

  final progress = ValueNotifier<double?>(null);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update wird geladen'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, child) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                Text(value == null ? assetName : '${(value * 100).round()} %'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final result = await updater.downloadAndVerify(
    assets: assets,
    assetName: assetName,
    targetPath: location.path,
    onProgress: (received, total) {
      // Without a Content-Length the bar stays indeterminate rather than inventing progress.
      progress.value = (total == null || total <= 0) ? null : received / total;
    },
  );

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // progress dialog

  // WARNING: no progress.dispose() — an early dispose crashes with "used after being disposed".

  switch (result.status) {
    case UpdateDownloadStatus.verified:
      await _showDownloadDoneDialog(context, filePath: result.filePath!);
    case UpdateDownloadStatus.checksumMismatch:
      // A dialog, not a snackbar: a corrupted or altered file must not slide away unread.
      await _showChecksumMismatchDialog(context);
    case UpdateDownloadStatus.unavailable:
      showErrorSnackBar(context, 'Für dieses Release gibt es keine geprüfte Datei für dein System.');
      await launchUrl(Uri.parse(_downloadPageUrl));
    case UpdateDownloadStatus.failed:
      showErrorSnackBar(context, 'Download fehlgeschlagen — bitte später erneut versuchen.');
  }
}

/// What to do with the verified file — the app deliberately does not run it.
Future<void> _showDownloadDoneDialog(BuildContext context, {required String filePath}) {
  // WARNING: keep the "quit first" note outside the per-platform strings — it went missing on Linux once.
  final hint = switch (Platform.operatingSystem) {
    'macos' => 'Öffne dann die Datei und ziehe FinanzGecko in den Programme-Ordner, über die vorhandene Version.',
    'windows' => 'Führe dann den Installer aus — er ersetzt die vorhandene Version.',
    'linux' => 'Mach dann die Datei ausführbar und starte sie anstelle der bisherigen.',
    _ => '',
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Update geladen und geprüft'),
      content: Text(
        'Die Datei stimmt mit der im Release veröffentlichten Prüfsumme überein.\n\n'
        'Beende FinanzGecko, bevor du die neue Version installierst — eine laufende App zu ersetzen kann zu '
        'Fehlern führen.\n\n$hint\n\n'
        'Deine Daten bleiben dabei erhalten.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: noSelect(const Text('Schließen'))),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _revealInFileManager(context, filePath);
          },
          child: noSelect(const Text('Im Ordner zeigen')),
        ),
      ],
    ),
  );
}

Future<void> _showChecksumMismatchDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Prüfsumme stimmt nicht'),
      content: const Text(
        'Die heruntergeladene Datei entspricht nicht der im Release veröffentlichten Prüfsumme und wurde '
        'deshalb nicht gespeichert. Meistens liegt das an einer abgebrochenen Übertragung — versuche es '
        'später noch einmal oder lade die Datei direkt von der Website.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: noSelect(const Text('Schließen'))),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            launchUrl(Uri.parse(_downloadPageUrl));
          },
          child: noSelect(const Text('Zur Website')),
        ),
      ],
    ),
  );
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
    // INFO: isApiReachable returns null without consent — the debug info must not silently bypass it.
    'Wechselkurs-API erreichbar: ${switch (apiReachable) {
      true => 'ja',
      false => 'nein',
      null => 'nicht geprüft (Abruf nicht erlaubt)',
    }}',
  ].join('\n');
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debug-Informationen kopiert.')));
}

// INFO: permanent next to the location row on purpose — a dismissed one-off dialog helps nobody years later.
/// Explains in everyday language that the data file is bound to this computer, and what a backup is instead.
class _DeviceBoundHint extends StatelessWidget {
  const _DeviceBoundHint({required this.onExport});

  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diese Datei gehört zu diesem Computer. Nur er kann sie lesen — auch dann, wenn du sie kopierst.',
            style: TextStyle(color: kTextPrimary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Eine Kopie in einem Cloud-Ordner oder auf einer externen Platte hilft dir also, wenn diese '
            'Festplatte kaputtgeht. Sie hilft dir nicht bei einem neuen Computer und nicht nach einer '
            'Neuinstallation — dort lässt sich die Datei nicht mehr öffnen.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Ein Backup, das du überall wieder einlesen kannst, bekommst du nur über den Export — auf Wunsch '
            'mit einem Passwort geschützt.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Deshalb lässt sich dieser Ordner auch nicht ändern: ihn in eine Cloud zu legen würde eine '
            'Sicherheit vortäuschen, die es nicht gibt.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onExport,
            child: noSelect(Text('Backup exportieren', style: TextStyle(color: kPrimaryText, fontSize: 13))),
          ),
        ],
      ),
    );
  }
}

// INFO: deliberately no ping on build — only the click on "Jetzt prüfen" justifies a fetch.
/// "Wechselkurs-API" row in the Hilfe section.
class _ApiReachabilityRow extends StatefulWidget {
  const _ApiReachabilityRow();

  @override
  State<_ApiReachabilityRow> createState() => _ApiReachabilityRowState();
}

class _ApiReachabilityRowState extends State<_ApiReachabilityRow> {
  String? _result;
  bool _checking = false;

  Future<void> _check(AppState app) async {
    setState(() => _checking = true);
    final reachable = await app.currencyService.isApiReachable();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = switch (reachable) {
        true => 'Erreichbar',
        false => 'Nicht erreichbar',
        // Consent was revoked in the meantime.
        null => 'Nicht geprüft (Abruf nicht erlaubt)',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final value = switch ((_checking, _result, app.mayFetchRates)) {
      (true, _, _) => 'Prüfe…',
      (_, final r?, _) => r,
      (_, _, false) => 'Nicht geprüft (Abruf nicht erlaubt)',
      _ => 'Nicht geprüft',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SecurityMetaRow(label: 'Wechselkurs-API', value: value),
        ),
        if (app.mayFetchRates && !_checking)
          InkWell(
            onTap: () => _check(app),
            child: noSelect(Text('Jetzt prüfen', style: TextStyle(color: kPrimaryText, fontSize: 13))),
          ),
      ],
    );
  }
}

/// Read-only "label: value" line for public encryption meta info; with [onOpen], a file-manager button follows.
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
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
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
