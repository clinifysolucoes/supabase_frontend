import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'cashflow_tab.dart';
import 'entries_tab.dart';
import 'finance_overview_tab.dart';
import 'registers_tab.dart';
import 'statement_tab.dart';

/// Financeiro da filial: visao geral, a pagar, a receber, extrato, fluxo de
/// caixa e cadastros (contas, plano de contas, fornecedores).
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = ref.watch(canReadProvider(ScreenCodes.finance));
    return AppShell(
      section: AppSection.finance,
      child: canRead
          ? const FinancePageBody()
          : const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: Strings.noPermissionTitle,
              subtitle: Strings.noPermissionSubtitle,
            ),
    );
  }
}

/// Conteudo do Financeiro (sem a moldura).
class FinancePageBody extends ConsumerStatefulWidget {
  const FinancePageBody({super.key});

  @override
  ConsumerState<FinancePageBody> createState() => _FinancePageBodyState();
}

class _FinancePageBodyState extends ConsumerState<FinancePageBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  static const _items = [
    (Icons.space_dashboard_outlined, Strings.tabFinOverview),
    (Icons.north_east_rounded, Strings.tabPayables),
    (Icons.south_west_rounded, Strings.tabReceivables),
    (Icons.list_alt_rounded, Strings.tabStatement),
    (Icons.show_chart_rounded, Strings.tabCashflow),
    (Icons.tune_rounded, Strings.tabFinRegisters),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // sem configuracao so a visao geral faz sentido (ela oferece configurar)
    final configured =
        ref.watch(financeOverviewProvider).valueOrNull?.idConfigured ?? true;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: Strings.finance,
            subtitle: Strings.financeSubtitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (configured) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primaryDark,
                  unselectedLabelColor: AppColors.muted,
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  tabs: [
                    for (final (icon, label) in _items)
                      Tab(
                        height: 44,
                        icon: Icon(icon, size: 18),
                        iconMargin: EdgeInsets.zero,
                        text: label,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Expanded(
            child: configured
                ? TabBarView(
                    controller: _tabs,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      FinanceOverviewTab(onOpenTab: _tabs.animateTo),
                      const EntriesTab(kind: EntryKind.payable),
                      const EntriesTab(kind: EntryKind.receivable),
                      const StatementTab(),
                      const CashflowTab(),
                      const RegistersTab(),
                    ],
                  )
                : const FinanceOverviewTab(),
          ),
        ],
      ),
    );
  }
}
