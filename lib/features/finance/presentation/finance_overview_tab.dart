import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'finance_widgets.dart';

/// Visao geral: saldo das contas, o dia, vencidos, o mes e os proximos
/// vencimentos. Sem configuracao, oferece criar contas e plano de contas.
class FinanceOverviewTab extends ConsumerStatefulWidget {
  const FinanceOverviewTab({super.key, this.onOpenTab});

  /// Abre outra aba (indice do TabController da pagina).
  final ValueChanged<int>? onOpenTab;

  @override
  ConsumerState<FinanceOverviewTab> createState() => _FinanceOverviewTabState();
}

class _FinanceOverviewTabState extends ConsumerState<FinanceOverviewTab> {
  bool _settingUp = false;

  Future<void> _setup() async {
    setState(() => _settingUp = true);
    try {
      await ref.read(financeActionsProvider).setup();
      if (mounted) AppSnack.success(context, Strings.finSetupDone);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _settingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financeOverviewProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(financeOverviewProvider),
      ),
      data: (o) {
        if (!o.idConfigured) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    Strings.finSetupTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    canCreate
                        ? Strings.finSetupSubtitle
                        : Strings.finSetupNoPermission,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (canCreate) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: Strings.finSetupAction,
                      icon: Icons.auto_fix_high_rounded,
                      expanded: false,
                      loading: _settingUp,
                      onPressed: _setup,
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(financeOverviewProvider.future),
          child: ListView(
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  FinKpiCard(
                    label: Strings.finBalance,
                    value: o.vlBalance,
                    icon: Icons.account_balance_wallet_rounded,
                    color: o.vlBalance < 0
                        ? AppColors.danger
                        : AppColors.primaryDark,
                    caption: Dates.format(DateTime.now()),
                    onTap: () => widget.onOpenTab?.call(3),
                  ),
                  FinKpiCard(
                    label: Strings.finTodayReceivable,
                    value: o.todayReceivable,
                    icon: Icons.south_west_rounded,
                    color: AppColors.success,
                    onTap: () => widget.onOpenTab?.call(2),
                  ),
                  FinKpiCard(
                    label: Strings.finTodayPayable,
                    value: o.todayPayable,
                    icon: Icons.north_east_rounded,
                    color: AppColors.danger,
                    onTap: () => widget.onOpenTab?.call(1),
                  ),
                  FinKpiCard(
                    label: Strings.finOverdueReceivable,
                    value: o.overdueReceivable,
                    icon: Icons.warning_amber_rounded,
                    color: o.overdueReceivableQt > 0
                        ? AppColors.warning
                        : AppColors.muted,
                    caption: Strings.finOverdueCount(o.overdueReceivableQt),
                    onTap: () => _openOverdue(EntryKind.receivable, 2),
                  ),
                  FinKpiCard(
                    label: Strings.finOverduePayable,
                    value: o.overduePayable,
                    icon: Icons.warning_amber_rounded,
                    color: o.overduePayableQt > 0
                        ? AppColors.danger
                        : AppColors.muted,
                    caption: Strings.finOverdueCount(o.overduePayableQt),
                    onTap: () => _openOverdue(EntryKind.payable, 1),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final month = _MonthCard(overview: o);
                  final accounts = _AccountsCard(accounts: o.accounts);
                  final next = _NextDueCard(entries: o.next);
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        month,
                        const SizedBox(height: AppSpacing.md),
                        next,
                        const SizedBox(height: AppSpacing.md),
                        accounts,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            month,
                            const SizedBox(height: AppSpacing.md),
                            accounts,
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: next),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openOverdue(int kind, int tab) {
    ref.read(entriesFilterProvider(kind).notifier).state = EntryFilter.overdue;
    widget.onOpenTab?.call(tab);
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.overview});

  final FinOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final result = o.monthReceived - o.monthPaid;
    Widget line(String label, double value, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            Numbers.money(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSectionTitle(
              '${Strings.finMonth} · ${Strings.monthName(now.month)}',
            ),
            line(Strings.finReceived, o.monthReceived, AppColors.success),
            line(Strings.finPaid, o.monthPaid, AppColors.danger),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    Strings.finMonthResult,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SignedMoney(result, bold: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            line(Strings.finToReceive, o.monthToReceive, AppColors.muted),
            line(Strings.finToPay, o.monthToPay, AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.accounts});

  final List<FinAccount> accounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinSectionTitle(Strings.finAccounts),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(accountIcon(a.itType), color: AppColors.primary),
                title: Text(
                  a.vcName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(AccountType.label(a.itType)),
                trailing: Text(
                  Numbers.money(a.vlBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: a.vlBalance < 0 ? AppColors.danger : AppColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData accountIcon(int type) => switch (type) {
  AccountType.bank => Icons.account_balance_rounded,
  AccountType.safe => Icons.lock_rounded,
  _ => Icons.payments_rounded,
};

class _NextDueCard extends StatelessWidget {
  const _NextDueCard({required this.entries});

  final List<FinEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinSectionTitle(Strings.finNextDue),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  Strings.finNoNextDue,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (final e in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  e.itKind == EntryKind.receivable
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: e.itKind == EntryKind.receivable
                      ? AppColors.success
                      : AppColors.danger,
                ),
                title: Text(
                  e.vcDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [Dates.format(e.dtDue), ?e.vcCategory].join(' · '),
                ),
                trailing: Text(
                  Numbers.money(e.vlAmount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
