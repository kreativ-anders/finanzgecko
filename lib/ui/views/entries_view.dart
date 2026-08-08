import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/balance.dart';
import '../../state/app_state.dart';
import '../../utils/analysis.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/month_picker_field.dart';
import '../widgets/rate_consent_dialog.dart';
import '../widgets/section_card.dart';

/// Single screen for both capturing new balances and correcting/deleting
/// existing ones — scoped to one month/year at a time (default: current
/// month) so the list stays manageable as entries pile up over time.
class EntriesView extends StatefulWidget {
  const EntriesView({super.key, required this.onNavigate, this.focusAccountId});

  final ValueChanged<AppView> onNavigate;

  /// Set when arriving from a dashboard account card: that account's row gets
  /// the initial focus instead of the first one, and is scrolled into view.
  /// Ignored if the account isn't in the current list (archived, or filtered
  /// out by "Nur fehlende anzeigen").
  final int? focusAccountId;

  @override
  State<EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<EntriesView> {
  String _period = currentPeriod();
  bool _onlyMissing = false;
  String _notice = '';
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  /// Marks the row addressed by [EntriesView.focusAccountId] so it can be
  /// scrolled to. `autofocus` alone only moves the focus — with a long account
  /// list the focused field can sit far below the fold.
  final GlobalKey _focusedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusAccountId == null) return;
    // After the first layout: the row's context (and the scroll extent) don't
    // exist yet while initState runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusedRowKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int accountId, Balance? balance) {
    final existing = _controllers[accountId];
    if (existing != null) return existing;
    final ctrl = TextEditingController(text: balance == null ? '' : fmtInputNumber(balance.amountOriginal));
    _controllers[accountId] = ctrl;
    return ctrl;
  }

  FocusNode _focusNodeFor(int accountId) => _focusNodes.putIfAbsent(accountId, FocusNode.new);

  void _syncControllers(AppState app) {
    for (final accountId in _controllers.keys) {
      final matches = app.balances.where((b) => b.accountId == accountId && b.period == _period);
      _controllers[accountId]!.text = matches.isEmpty ? '' : fmtInputNumber(matches.first.amountOriginal);
    }
  }

  void _changePeriod(String period, AppState app) {
    setState(() {
      _period = period;
      _notice = '';
      _syncControllers(app);
    });
  }

  /// Best-effort exchange rate for the live running total, without hitting the
  /// network: 1 for base-currency accounts, otherwise the rate from this
  /// account's last stored balance (or any recent balance in that currency).
  /// [prev] is the account's own previous balance, already resolved by the
  /// caller so this doesn't re-scan `app.balances` on top of that lookup.
  /// Returns null when nothing is available to estimate with.
  double? _rateEstimate(AppState app, Account acc, Balance? prev) {
    if (acc.currency == app.baseCurrency) return 1;
    if (prev != null && prev.currencyOriginal == acc.currency && prev.rate != 0) return prev.rate;
    final sameCurrency = app.balances.where((b) => b.currencyOriginal == acc.currency && b.rate != 0).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    return sameCurrency.isEmpty ? null : sameCurrency.last.rate;
  }

  /// Running preview of what "Alle speichern" will produce, computed from the
  /// text fields as the user types — no network, using [_rateEstimate].
  ///
  /// Rebuilds on every keystroke (see the amount fields' `onChanged` below),
  /// so the per-account "previous balance" lookup is indexed once here
  /// instead of re-filtering+sorting the full `app.balances` list per
  /// account, as `AppState.previousBalance` does on its own.
  _LiveTotals _computeLiveTotals(AppState app) {
    final byAccount = <int, List<Balance>>{};
    for (final b in app.balances) {
      (byAccount[b.accountId] ??= []).add(b);
    }
    for (final list in byAccount.values) {
      list.sort((a, b) => a.period.compareTo(b.period));
    }
    Balance? previousFor(int accountId) {
      final list = byAccount[accountId];
      if (list == null) return null;
      for (var i = list.length - 1; i >= 0; i--) {
        if (list[i].period.compareTo(_period) < 0) return list[i];
      }
      return null;
    }

    var running = 0.0;
    var baseline = 0.0;
    var filled = 0;
    var withoutRate = 0;
    for (final acc in app.accounts) {
      final raw = _controllers[acc.id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final amount = parseInputNumber(raw);
      if (amount == null) continue;
      final prev = previousFor(acc.id);
      final rate = _rateEstimate(app, acc, prev);
      if (rate == null) {
        withoutRate++;
        continue;
      }
      running += amount * rate;
      filled++;
      if (prev != null) baseline += prev.amountBase;
    }
    return _LiveTotals(running: running, delta: running - baseline, filled: filled, withoutRate: withoutRate);
  }

  Future<void> _submit(AppState app) async {
    // The current month isn't over yet, so its last day is a future date
    // with no published rate (Frankfurter 404s). Use today instead — the
    // API itself falls back to the latest published business day. Closed
    // months keep their own last-day rate for historical accuracy.
    final dateISO = _period == currentPeriod() ? todayISO() : lastDayOfMonthISO(_period);
    final rateCache = <String, double?>{};
    var saved = 0;
    var failed = 0;
    var invalid = 0;
    var errored = 0;

    setState(() => _notice = 'Wird gespeichert …');

    for (final acc in app.accounts) {
      final ctrl = _controllers[acc.id];
      final raw = ctrl?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final amount = parseInputNumber(raw);
      if (amount == null) {
        invalid++;
        continue;
      }

      if (!rateCache.containsKey(acc.currency)) {
        if (!mounted) return;
        // resolveRate asks for the online-lookup consent once (only when a
        // foreign currency is actually involved), then falls back to the cache
        // and finally to a manually entered rate — see rate_consent_dialog.dart.
        rateCache[acc.currency] = await resolveRate(
          context,
          app,
          from: acc.currency,
          to: app.baseCurrency,
          dateISO: dateISO,
        );
      }

      final rate = rateCache[acc.currency];
      if (rate == null) {
        failed++;
        continue;
      }

      try {
        await app.upsertBalance(
          accountId: acc.id,
          period: _period,
          amountOriginal: amount,
          currencyOriginal: acc.currency,
          rate: rate,
          amountBase: amount * rate,
        );
        saved++;
      } catch (_) {
        // Keep going for the remaining accounts — one failed write shouldn't
        // strand the whole batch on "Wird gespeichert …" with nothing saved.
        errored++;
      }
    }

    if (!mounted) return;
    _syncControllers(app);
    final parts = ['$saved ${saved == 1 ? 'Konto' : 'Konten'} gespeichert.'];
    if (failed > 0) parts.add('$failed ohne Kurs übersprungen.');
    if (invalid > 0) parts.add('$invalid mit ungültigem Betrag übersprungen.');
    if (errored > 0) parts.add('$errored beim Speichern fehlgeschlagen.');
    setState(() => _notice = parts.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.accounts.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Text('Erst ein Konto anlegen', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Bevor du einen Kontostand erfassen kannst, brauchst du mindestens ein Konto.',
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => widget.onNavigate(AppView.accounts),
                child: noSelect(const Text('Konto anlegen')),
              ),
            ],
          ),
        ),
      );
    }

    final periodBalances = app.balances.where((b) => b.period == _period).toList();
    final activeIds = app.accounts.map((a) => a.id).toSet();
    final balanceByAccount = {for (final b in periodBalances) b.accountId: b};
    final orphanBalances = periodBalances.where((b) => !activeIds.contains(b.accountId)).toList();
    final visibleAccounts = app.accounts
        .where((acc) => !(_onlyMissing && balanceByAccount.containsKey(acc.id)))
        .toList();
    final totals = _computeLiveTotals(app);
    // Which row starts focused: the account we were sent to, else the first.
    final requestedIndex = widget.focusAccountId == null
        ? -1
        : visibleAccounts.indexWhere((acc) => acc.id == widget.focusAccountId);
    final focusIndex = requestedIndex >= 0 ? requestedIndex : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Zeitraum:', style: TextStyle(color: kMuted)),
                  const SizedBox(width: 12),
                  MonthPickerField(value: _period, onChanged: (p) => _changePeriod(p, app)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(value: _onlyMissing, onChanged: (v) => setState(() => _onlyMissing = v)),
                  Text('Nur fehlende anzeigen', style: TextStyle(color: kMuted)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionCard(
                  title: 'Kontostände',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full detail lives in the tooltip so it's available on
                      // demand without permanently occupying three lines above
                      // the account rows on every single visit.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message:
                                'Auch rückwirkend möglich — einfach den passenden Monat wählen. Ein bestehender '
                                'Eintrag für Konto + Monat wird überschrieben. Leere Felder werden übersprungen. '
                                'Enter springt zum nächsten Konto.',
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.info_outline, size: 14, color: kMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Auch rückwirkend erfassbar — bestehende Einträge werden überschrieben.',
                              style: TextStyle(color: kMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (visibleAccounts.isEmpty)
                        Text(
                          'Für ${periodLabel(_period)} sind bereits alle Konten erfasst.',
                          style: TextStyle(color: kMuted),
                        )
                      else
                        for (var i = 0; i < visibleAccounts.length; i++)
                          _EntryRow(
                            // Only attached when a row was actually requested —
                            // otherwise the GlobalKey would ride along on
                            // whatever row happens to be first.
                            key: requestedIndex >= 0 && i == focusIndex ? _focusedRowKey : null,
                            account: visibleAccounts[i],
                            controller: _controllerFor(visibleAccounts[i].id, balanceByAccount[visibleAccounts[i].id]),
                            focusNode: _focusNodeFor(visibleAccounts[i].id),
                            nextFocusNode: i < visibleAccounts.length - 1
                                ? _focusNodeFor(visibleAccounts[i + 1].id)
                                : null,
                            autofocus: i == focusIndex,
                            app: app,
                            period: _period,
                            existing: balanceByAccount[visibleAccounts[i].id],
                            onChanged: () => setState(() {}),
                            onSubmitLast: () => _submit(app),
                            onNavigate: widget.onNavigate,
                          ),
                    ],
                  ),
                ),
                if (orphanBalances.isNotEmpty) ...[
                  cardGap,
                  _OrphanEntriesSection(balances: orphanBalances, app: app, onNavigate: widget.onNavigate),
                ],
              ],
            ),
          ),
        ),
        _SaveFooter(totals: totals, notice: _notice, baseCurrency: app.baseCurrency, onSave: () => _submit(app)),
      ],
    );
  }
}

/// Immutable snapshot of the live preview shown in the footer.
class _LiveTotals {
  const _LiveTotals({required this.running, required this.delta, required this.filled, required this.withoutRate});

  final double running;
  final double delta;
  final int filled;
  final int withoutRate;
}

/// Sticky bottom bar: running net-worth preview + delta vs. the previous
/// stored values, plus the single "Alle speichern" action — always reachable
/// without scrolling, however long the account list gets.
class _SaveFooter extends StatelessWidget {
  const _SaveFooter({required this.totals, required this.notice, required this.baseCurrency, required this.onSave});

  final _LiveTotals totals;
  final String notice;
  final String baseCurrency;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totals.filled == 0)
                  Text('Noch nichts eingegeben', style: TextStyle(color: kMuted))
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    children: [
                      Text('Zwischensumme', style: TextStyle(color: kMuted, fontSize: 13)),
                      Text(
                        fmtMoney(totals.running, baseCurrency),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${fmtSignedMoney(totals.delta, baseCurrency)} ggü. vorherigem Stand',
                        style: TextStyle(
                          color: totals.delta >= 0 ? kPrimaryText : kDangerText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (totals.withoutRate > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${totals.withoutRate} Konto${totals.withoutRate == 1 ? '' : 'en'} in Fremdwährung ohne Kursschätzung — '
                      'Kurs wird beim Speichern abgefragt.',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ),
                if (notice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(notice, style: TextStyle(color: kMuted, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(onPressed: onSave, child: noSelect(const Text('Alle speichern'))),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.account,
    required this.controller,
    required this.focusNode,
    required this.nextFocusNode,
    required this.autofocus,
    required this.app,
    required this.period,
    required this.existing,
    required this.onChanged,
    required this.onSubmitLast,
    required this.onNavigate,
  });

  final Account account;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final bool autofocus;
  final AppState app;
  final String period;
  final Balance? existing;
  final VoidCallback onChanged;
  final VoidCallback onSubmitLast;
  final ValueChanged<AppView> onNavigate;

  Future<void> _delete(BuildContext context) async {
    final bal = existing;
    if (bal == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('Eintrag für ${account.name} · ${periodLabel(bal.period)} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AppState>().deleteBalance(bal.id);
    controller.clear();
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'Gelöscht.');
  }

  @override
  Widget build(BuildContext context) {
    final prev = app.previousBalance(account.id, period);

    // Order-of-magnitude guard: a value 10x larger or smaller than this
    // account's last balance is almost always a mistyped digit. Non-blocking —
    // just a hint, since a genuine large move is still allowed to be saved.
    final entered = parseInputNumber(controller.text.trim());
    final prevAmount = prev?.amountOriginal;
    String? anomaly;
    if (entered != null && prevAmount != null && isBalanceAnomaly(entered, prevAmount)) {
      anomaly =
          'Ungewöhnlich: ${entered.abs() > prevAmount.abs() ? 'viel größer' : 'viel kleiner'} als zuletzt '
          '(${fmtMoney(prevAmount, account.currency)}). Tippfehler?';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: account.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        children: [
                          TextSpan(
                            text: '  (${account.currency})',
                            style: TextStyle(color: kMuted, fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      prev != null
                          ? 'zuletzt ${fmtMoney(prev.amountOriginal, prev.currencyOriginal)} (${periodLabel(prev.period)})'
                          : '',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  onChanged: (_) => onChanged(),
                  textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: (_) {
                    final next = nextFocusNode;
                    if (next != null) {
                      next.requestFocus();
                    } else {
                      onSubmitLast();
                    }
                  },
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  // Last month's value as an in-field ghost: most months the
                  // user only nudges a digit instead of retyping from scratch.
                  decoration: InputDecoration(
                    labelText: 'Betrag',
                    hintText: prev != null ? fmtInputNumber(prev.amountOriginal) : '0,00',
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: existing == null
                    ? null
                    : IconButton(
                        tooltip: 'Eintrag löschen',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _delete(context),
                      ),
              ),
            ],
          ),
          if (anomaly != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: kWarningText),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      anomaly,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: kWarningText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Balances left behind by accounts that have since been archived — kept
/// visible here (with a way back to the account) since they no longer
/// surface anywhere else in the app.
class _OrphanEntriesSection extends StatelessWidget {
  const _OrphanEntriesSection({required this.balances, required this.app, required this.onNavigate});

  final List<Balance> balances;
  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Archivierte Konten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Einträge von Konten, die inzwischen archiviert wurden.', style: TextStyle(color: kMuted)),
          ),
          for (final bal in balances)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OrphanRow(balance: bal, account: app.findAccount(bal.accountId), onNavigate: onNavigate),
            ),
        ],
      ),
    );
  }
}

class _OrphanRow extends StatelessWidget {
  const _OrphanRow({required this.balance, required this.account, required this.onNavigate});

  final Balance balance;
  // Null in the rare case the account record itself is gone entirely (e.g. a
  // hand-edited import) rather than merely archived — then only Löschen applies.
  final Account? account;
  final ValueChanged<AppView> onNavigate;

  Future<void> _restore(BuildContext context) async {
    final acc = account;
    if (acc == null) return;
    await context.read<AppState>().restoreAccount(acc.id);
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'Wiederhergestellt.');
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text(
          'Eintrag für ${account?.name ?? 'unbekanntes Konto'} · ${periodLabel(balance.period)} wirklich löschen?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppState>().deleteBalance(balance.id);
      if (!context.mounted) return;
      showSavedSnackBar(context, onNavigate, message: 'Gelöscht.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = account;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 110, child: Text(periodLabel(balance.period))),
        Expanded(
          child: Text(
            acc?.name ?? 'Konto gelöscht',
            style: acc == null ? TextStyle(color: kMuted) : const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 120,
          child: Text(fmtMoney(balance.amountOriginal, balance.currencyOriginal), textAlign: TextAlign.right),
        ),
        const SizedBox(width: 12),
        if (acc != null) ...[
          OutlinedButton(onPressed: () => _restore(context), child: noSelect(const Text('Wiederherstellen'))),
          const SizedBox(width: 8),
        ],
        OutlinedButton(onPressed: () => _delete(context), child: noSelect(const Text('Löschen'))),
      ],
    );
  }
}
