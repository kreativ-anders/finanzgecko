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
          // Bewusst schon sichtbar, bevor jemals gefragt wurde ("Noch nicht
          // entschieden"): wer wissen will, ob die App ins Netz geht, soll das
          // hier nachlesen können, ohne erst einen Fremdwährungsbetrag erfassen
          // zu müssen. Das Anzeigen löst selbst nie einen Abruf oder Dialog aus.
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
                // Dauerhaft sichtbar, nicht als einmaliger Dialog: die
                // Konsequenz der gerätegebundenen Verschlüsselung muss auch
                // Jahre später noch nachlesbar sein, wenn jemand die Datei in
                // einem Cloud-Ordner sieht und sie für ein Backup hält.
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

/// Opens [path] in the OS file manager (Explorer/Finder/Nautilus & co.) via
/// a plain file:// URI — url_launcher's desktop backends hand that off to
/// the platform's native "open this folder" call (ShellExecute on Windows,
/// NSWorkspace on macOS, xdg-open/gio on Linux), so no extra plugin is
/// needed beyond what the app already uses for web links.
Future<void> _openInFileManager(BuildContext context, String path) async {
  // macOS: open the PARENT directory, not the data directory itself.
  //
  // The data directory is named after the application id and therefore ends in
  // ".app" (…/Application Support/de.finanzgecko.app). LaunchServices reads
  // that suffix as an application bundle, tries to *launch* the folder, and
  // fails with "damaged or incomplete" / "the executable is missing" — an
  // alarming dialog for what is purely a cosmetic action.
  //
  // Measured, not assumed (2026-08-13, macOS): a trailing slash does NOT help
  // — `open ".../de.finanzgecko.app/"` fails identically. Opening the parent is
  // what actually works. The user lands one level up and sees the data folder
  // in the listing; slightly less direct, but it opens instead of erroring.
  //
  // Renaming the directory would also fix it and is NOT an option: the name is
  // the bundle id and the sandbox container name, so changing it orphans every
  // existing installation's data.
  //
  // Only macOS: Linux and Windows file managers do not treat ".app" specially,
  // and there the deep link to the exact folder is the better behaviour.
  final target = Platform.isMacOS ? Directory(path).parent.path : path;
  final uri = Uri.directory(target, windows: Platform.isWindows);
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
/// answer: the Wechselkurs-API is the app's only *automatic* external network
/// destination, no telemetry/analytics of any kind. "Nach Updates suchen" is
/// a second, deliberately manual-only network call (GitHub Releases API, see
/// [UpdateService]) — never a silent background check, because an app that
/// phones home on its own is exactly what this app promises not to be. That
/// the builds are signed and notarized doesn't change that; it only makes the
/// downloaded file verifiable, which is what the checksum step already covers.
///
/// In the App Store build ([kIsMacAppStore]) the update entry is absent
/// altogether: the App Store does the updating, and shipping a second
/// self-update path alongside it would violate App Review guideline 2.4.5.
/// The network paragraph below therefore has to drop its GitHub sentence too —
/// it is a privacy claim, and in that build the call genuinely never happens.
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

/// The site's existing per-OS download page (docs/download.html) — one big
/// button per platform, the same link end users already get via the website.
/// Deliberately not GitHub's release page: that would leave picking the right
/// asset (Setup.exe / .dmg / .AppImage) to the user.
const _downloadPageUrl = 'https://finanzgecko.app/download.html';

/// Manual, user-triggered update check against the GitHub Releases API (see
/// [UpdateService]) — never automatic, never on launch, never periodic.
///
/// After the user confirms, the matching file for this platform is downloaded
/// and checked against the release's `SHA256SUMS`. The app still never
/// *executes* anything: it saves the verified file where the user chose and
/// offers to show it in the file manager.
Future<void> _checkForUpdates(BuildContext context) async {
  final appState = context.read<AppState>();
  final info = await PackageInfo.fromPlatform();
  final result = await appState.updateService.checkForUpdate(currentVersion: info.version);
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
      await _downloadUpdate(context, assets: result.assets);
    case UpdateCheckStatus.failed:
      showErrorSnackBar(context, 'Update-Prüfung fehlgeschlagen — bitte später erneut versuchen.');
  }
}

/// Shown instead of a snackbar for the "update available" result — unlike
/// up-to-date/failed, this one is actionable and shouldn't be easy to miss
/// or dismiss by accident via a passing snackbar.
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

/// Downloads the release file for this platform, verifies it and saves it
/// where the user chose.
///
/// The save dialog is deliberate, rather than dropping the file into
/// ~/Downloads: writing there unprompted makes macOS raise its own "would like
/// to access files in your Downloads folder" permission dialog — an alarming
/// thing for an app whose whole point is that it touches nothing. Picking a
/// location grants access to exactly that one file, and it is the same dialog
/// users already know from "Backup exportieren…".
Future<void> _downloadUpdate(BuildContext context, {required Map<String, String> assets}) async {
  final assetName = selectAssetName(assets.keys, Platform.operatingSystem);
  // No file for this platform in this release (a platform build failed, or the
  // release predates the checksums): send the user to the download page rather
  // than guess at the wrong file.
  if (assetName == null) {
    await launchUrl(Uri.parse(_downloadPageUrl));
    return;
  }

  final location = await getSaveLocation(suggestedName: assetName);
  if (location == null || !context.mounted) return; // Dialog abgebrochen

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

  final result = await context.read<AppState>().updateService.downloadAndVerify(
    assets: assets,
    assetName: assetName,
    targetPath: location.path,
    onProgress: (received, total) {
      // Ohne Content-Length bleibt der Balken unbestimmt, statt einen
      // erfundenen Fortschritt anzuzeigen.
      progress.value = (total == null || total <= 0) ? null : received / total;
    },
  );

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // Fortschritts-Dialog

  // Bewusst kein progress.dispose(): der Dialog wird erst nach seiner
  // Schließ-Animation abgebaut und meldet seinen Listener DANN ab — ein
  // sofortiges dispose() ließe genau das mit "used after being disposed"
  // krachen. Ohne Listener wird der ValueNotifier ohnehin eingesammelt.

  switch (result.status) {
    case UpdateDownloadStatus.verified:
      await _showDownloadDoneDialog(context, filePath: result.filePath!);
    case UpdateDownloadStatus.checksumMismatch:
      // Bewusst ein Dialog, kein Snackbar: die Datei kam beschädigt oder
      // verändert an. Das darf nicht wegwischen, bevor es gelesen wurde.
      await _showChecksumMismatchDialog(context);
    case UpdateDownloadStatus.unavailable:
      showErrorSnackBar(context, 'Für dieses Release gibt es keine geprüfte Datei für dein System.');
      await launchUrl(Uri.parse(_downloadPageUrl));
    case UpdateDownloadStatus.failed:
      showErrorSnackBar(context, 'Download fehlgeschlagen — bitte später erneut versuchen.');
  }
}

/// What to do with the verified file. The app deliberately does not run it:
/// on Windows that would mean launching a freshly downloaded executable, and
/// the promise "FinanzGecko installs nothing by itself" is worth more than the
/// saved click.
Future<void> _showDownloadDoneDialog(BuildContext context, {required String filePath}) {
  // Der Hinweis zum Beenden steht bewusst EINMAL für alle Plattformen davor,
  // statt in jedem der drei Sätze unten: so kann er beim Ergänzen einer
  // Plattform nicht versehentlich fehlen (genau das war er unter Linux schon).
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
            _openInFileManager(context, File(filePath).parent.path);
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
    // isApiReachable liefert null, wenn der Abruf nicht erlaubt ist, und geht
    // dann gar nicht erst ins Netz — die Debug-Info darf keine stille Ausnahme
    // von der Zustimmung sein, auch nicht "nur zur Diagnose".
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

/// Read-only "label: value" line used for non-sensitive encryption meta
/// info in the security section — builds trust without exposing anything
/// an attacker could use (algorithm name and storage path are public
/// implementation facts, not secrets). When [onOpen] is set, an "open in
/// file manager" button is shown after the value.
/// Erklärt in Alltagssprache, dass die Datendatei an genau diesen Computer
/// gebunden ist — und was stattdessen ein Backup ist.
///
/// Bewusst dauerhaft an der Speicherort-Zeile statt als einmaliger Dialog beim
/// Ordnerwechsel: eine weggeklickte Warnung erinnert niemand zwei Jahre später,
/// wenn die Festplatte kaputt ist. Kein "Schlüssel", kein "Schlüsselbund",
/// keine "Verschlüsselung" — die Konsequenz zählt, nicht der Mechanismus.
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

/// "Wechselkurs-API"-Zeile im Hilfe-Bereich.
///
/// Pingt bewusst **nicht** beim Aufbau der Ansicht: das wäre ein Netzabruf,
/// den niemand ausgelöst hat, und ein Zustimmungsdialog beim bloßen Öffnen der
/// Einstellungen wäre für Nutzer nicht nachvollziehbar. Ohne erteilte
/// Zustimmung steht hier deshalb nur der gespeicherte Zustand; erst der Klick
/// auf "Jetzt prüfen" ist die ausdrückliche Handlung, die einen Abruf
/// rechtfertigt — analog zu "Nach Updates suchen".
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
        // Zustimmung wurde zwischenzeitlich entzogen.
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
        Expanded(child: _SecurityMetaRow(label: 'Wechselkurs-API', value: value)),
        if (app.mayFetchRates && !_checking)
          InkWell(
            onTap: () => _check(app),
            child: noSelect(Text('Jetzt prüfen', style: TextStyle(color: kPrimaryText, fontSize: 13))),
          ),
      ],
    );
  }
}

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
