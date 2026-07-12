import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_state.dart';
import 'app_view.dart';
import 'theme.dart';
import 'views/accounts_view.dart';
import 'views/assets_view.dart';
import 'views/dashboard_view.dart';
import 'views/entries_view.dart';
import 'views/settings_view.dart';
import 'views/subscriptions_view.dart';

const _backupTypeGroups = [XTypeGroup(label: 'JSON-Backup', extensions: ['json'])];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.dashboard;

  void _navigate(AppView view) => setState(() => _view = view);

  Future<void> _handleExport() async {
    final appState = context.read<AppState>();
    final exportData = appState.exportAllData();
    final suggestedName = 'finanzgecko-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';

    final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _backupTypeGroups);
    if (location == null) return; // Dialog abgebrochen

    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      await File(location.path).writeAsString(jsonStr);
      await appState.markExported();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup exportiert.')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $err')));
    }
  }

  Future<void> _handleImport() async {
    final appState = context.read<AppState>();
    final file = await openFile(acceptedTypeGroups: _backupTypeGroups);
    if (file == null) return; // Dialog abgebrochen

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup importieren'),
        content: const Text('Import ersetzt ALLE aktuellen Daten. Fortfahren?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Importieren')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final raw = await file.readAsString();
      final imported = jsonDecode(raw) as Map<String, dynamic>;
      await appState.importAllData(imported);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import abgeschlossen.')));
      setState(() => _view = AppView.dashboard);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: Datei ist kein gültiges Backup.\n$err')));
    }
  }

  Future<void> _handleQuit() async {
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;
    final modKey = isMac ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(modKey, LogicalKeyboardKey.keyE): _handleExport,
        LogicalKeySet(modKey, LogicalKeyboardKey.keyI): _handleImport,
        LogicalKeySet(modKey, LogicalKeyboardKey.keyQ): _handleQuit,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _TopBar(current: _view, onNavigate: _navigate),
              Expanded(
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: _content()),
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_view) {
      case AppView.dashboard:
        return DashboardView(onNavigate: _navigate);
      case AppView.entries:
        return EntriesView(onNavigate: _navigate);
      case AppView.accounts:
        return const AccountsView();
      case AppView.assets:
        return const AssetsView();
      case AppView.subscriptions:
        return const SubscriptionsView();
      case AppView.settings:
        return SettingsView(onExport: _handleExport, onImport: _handleImport);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.current, required this.onNavigate});

  final AppView current;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          const Text('🦎 FinanzGecko', style: TextStyle(fontWeight: FontWeight.w700, color: kPrimary, fontSize: 16)),
          Wrap(
            spacing: 2,
            children: [for (final view in AppView.values) _NavButton(view: view, active: view == current, onTap: () => onNavigate(view))],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.view, required this.active, required this.onTap});

  final AppView view;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: active ? kPrimary : Colors.white70),
      child: Text(view.label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: const Text(
        'Alle Daten bleiben lokal auf diesem Rechner. Kein Server, keine Cloud.',
        style: TextStyle(color: kMuted, fontSize: 12),
      ),
    );
  }
}
