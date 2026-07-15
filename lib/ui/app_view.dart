enum AppView { dashboard, accounts, entries, subscriptions, assets, settings }

extension AppViewLabel on AppView {
  String get label {
    switch (this) {
      case AppView.dashboard:
        return 'Dashboard';
      case AppView.entries:
        return 'Einträge';
      case AppView.accounts:
        return 'Konten';
      case AppView.assets:
        return 'Vermögenswerte';
      case AppView.subscriptions:
        return 'Fixposten';
      case AppView.settings:
        return 'Einstellungen';
    }
  }
}
