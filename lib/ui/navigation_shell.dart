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

/// Navigation shell: top nav across the six views, the in-app "Datei" area, and global shortcuts.
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  AppView _view = AppView.dashboard;

// Deliberately not threaded through [_navigate] — widening it would touch six views for one caller.
  int? _focusAccountId;

// Clears any pending focus, so returning to "Einträge" later does not re-focus a stale account.
  void _navigate(AppView view) => setState(() {
    _view = view;
    _focusAccountId = null;
  });

  /// Dashboard account card → "Einträge", positioned on that account.
  void _openAccountEntry(int accountId) => setState(() {
    _view = AppView.entries;
    _focusAccountId = accountId;
  });

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
        return DashboardView(onNavigate: _navigate, onOpenAccountEntry: _openAccountEntry);
      case AppView.entries:
        return EntriesView(onNavigate: _navigate, focusAccountId: _focusAccountId);
      case AppView.accounts:
        return AccountsView(onNavigate: _navigate);
      case AppView.assets:
        return AssetsView(onNavigate: _navigate);
      case AppView.subscriptions:
        return SubscriptionsView(onNavigate: _navigate);
      case AppView.settings:
        return SettingsView(
          onExport: () => exportBackup(context, _navigate),
          onExportCsv: () => exportCsvTables(context, _navigate),
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
        decoration: BoxDecoration(
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
    return Semantics(
      selected: active,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: active ? kPrimaryText : kMuted),
// INFO: noSelect keeps the pointer a hand here, see dev/ai/ui-conventions.md.
        child: noSelect(Text(view.label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.normal))),
      ),
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
        child: Text(
          'Alle Daten bleiben lokal auf diesem Rechner. Kein Server, keine Cloud.',
          style: TextStyle(color: kMuted, fontSize: 12),
        ),
      ),
    );
  }
}
