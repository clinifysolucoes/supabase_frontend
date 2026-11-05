import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_table.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'finance_widgets.dart';
import 'health_export_dialog.dart';

/// Extrato: movimentos pagos do mes numa conta (ou em todas), com o saldo
/// depois de cada um.
class StatementTab extends ConsumerWidget {
  const StatementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statementMonthProvider);
    final account = ref.watch(statementAccountProvider);
    final accounts = ref.watch(financeCatalogProvider).valueOrNull?.accounts;
    final async = ref.watch(statementProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonthSwitcher(
              month: month,
              onChanged: (m) =>
                  ref.read(statementMonthProvider.notifier).state = m,
            ),
            SizedBox(
              width: context.isMobile ? double.infinity : 260,
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: account,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: Strings.finAccount,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(Strings.finAllAccounts),
                  ),
                  for (final a in accounts ?? const <FinAccount>[])
                    DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
                ],
                onChanged: (v) =>
                    ref.read(statementAccountProvider.notifier).state = v,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => HealthExportDialog.show(context),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text(Strings.healthExport),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(statementProvider),
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    FinKpiCard(label: Strings.finStart, value: s.vlStart),
                    FinKpiCard(
                      label: Strings.finIn,
                      value: s.vlIn,
                      color: AppColors.success,
                      icon: Icons.south_west_rounded,
                    ),
                    FinKpiCard(
                      label: Strings.finOut,
                      value: s.vlOut,
                      color: AppColors.danger,
                      icon: Icons.north_east_rounded,
                    ),
                    FinKpiCard(
                      label: Strings.finEnd,
                      value: s.vlEnd,
                      color: s.vlEnd < 0
                          ? AppColors.danger
                          : AppColors.primaryDark,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: s.lines.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.list_alt_rounded,
                          title: Strings.finNoMovements,
                        )
                      : context.isMobile
                      ? ListView.separated(
                          itemCount: s.lines.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final l = s.lines[i];
                            return ListTile(
                              title: Text(l.vcDescription),
                              subtitle: Text(
                                [
                                  Dates.format(l.dtPaid),
                                  ?l.vcCategory,
                                  ?l.vcAccount,
                                ].join(' · '),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SignedMoney(l.vlValue, bold: true),
                                  Text(
                                    Numbers.money(l.vlBalance),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : AppTable(
                          minWidth: 860,
                          columns: const [
                            DataColumn(label: Text(Strings.finDate)),
                            DataColumn(label: Text(Strings.finDescription)),
                            DataColumn(label: Text(Strings.finCategory)),
                            DataColumn(label: Text(Strings.finAccount)),
                            DataColumn(label: Text(Strings.finPaymentMethod)),
                            DataColumn(
                              label: Text(Strings.finAmount),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(Strings.finBalanceAfter),
                              numeric: true,
                            ),
                          ],
                          rows: [
                            for (final l in s.lines)
                              DataRow(
                                cells: [
                                  DataCell(Text(Dates.format(l.dtPaid))),
                                  DataCell(Text(l.vcDescription)),
                                  DataCell(Text(l.vcCategory ?? '-')),
                                  DataCell(Text(l.vcAccount ?? '-')),
                                  DataCell(
                                    Text(
                                      PaymentMethod.label(l.itPaymentMethod),
                                    ),
                                  ),
                                  DataCell(SignedMoney(l.vlValue)),
                                  DataCell(Text(Numbers.money(l.vlBalance))),
                                ],
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
