import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../constants.dart';
import 'app_view.dart';
import 'backup_actions.dart';
import 'theme.dart';
import 'views/accounts_view.dart';
import 'views/assets_view.dart';
import 'views/dashboard_view.dart';
import 'views/entries_view.dart';
import 'views/settings_view.dart';
import 'views/subscriptions_view.dart';

/// Navigations-Shell der App: Top-Navigation über die sechs Ansichten,
/// In-App-"Datei"-Menü-Ersatz und globale Tastenkürzel. Der Backup-Fluss selbst
/// liegt in `backup_actions.dart`; hier wird er nur verdrahtet (Feature
/// `navigation` vs. `backup_restore`).
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  AppView _view = AppView.dashboard;

  void _navigate(AppView view) => setState(() => _view = view);

  Future<void> _handleQuit() async {
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;
    final modKey = isMac ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(modKey, AppShortcuts.export.key): () => exportBackup(context, _navigate),
        LogicalKeySet(modKey, AppShortcuts.import_.key): () => importBackup(context, _navigate),
        LogicalKeySet(modKey, AppShortcuts.quit.key): _handleQuit,
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
        return AccountsView(onNavigate: _navigate);
      case AppView.assets:
        return AssetsView(onNavigate: _navigate);
      case AppView.subscriptions:
        return SubscriptionsView(onNavigate: _navigate);
      case AppView.settings:
        return SettingsView(
          onExport: () => exportBackup(context, _navigate),
          onExportCsv: () => exportBalancesCsv(context, _navigate),
          onImport: () => importBackup(context, _navigate),
          onNavigate: _navigate,
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.current, required this.onNavigate});

  final AppView current;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          children: [
            const Text(
              '🦎 FinanzGecko',
              style: TextStyle(fontWeight: FontWeight.w700, color: kPrimary, fontSize: 16),
            ),
            Wrap(
              spacing: 2,
              children: [
                for (final view in AppView.values)
                  _NavButton(view: view, active: view == current, onTap: () => onNavigate(view)),
              ],
            ),
          ],
        ),
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
    return SelectionContainer.disabled(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: const Text(
          'Alle Daten bleiben lokal auf diesem Rechner. Kein Server, keine Cloud.',
          style: TextStyle(color: kMuted, fontSize: 12),
        ),
      ),
    );
  }
}
