import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/budget_controllers.dart';
import '../domain/budget_models.dart';
import 'budget_detail_dialog.dart';
import 'budget_form_dialog.dart';

/// Tela Orcamentos: todos os orcamentos da filial por situacao.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.budgets))) {
      return const AppShell(
        section: AppSection.budgets,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final filter = ref.watch(budgetFilterProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.budgets));
    final data = ref.watch(budgetsProvider(null)).valueOrNull;
    return AppShell(
      section: AppSection.budgets,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: Strings.budgets,
              subtitle: Strings.budgetsSubtitle,
              actions: [
                if (canCreate)
                  AppButton(
                    label: Strings.budgetNew,
                    icon: Icons.add_rounded,
                    expanded: false,
                    onPressed: () =>
                        _new(context, ref, data?.pcMaxDiscount ?? 10),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (data != null)
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  _Kpi(
                    Strings.budgetOpen,
                    '${data.qtOpen} · ${Numbers.money(data.vlOpen)}',
                  ),
                  _Kpi(Strings.budgetPending, '${data.qtPending}'),
                  _Kpi(
                    Strings.budgetAcceptedShort,
                    '${data.qtAccepted} · ${Numbers.money(data.vlAccepted)}',
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: 360,
              child: AppTextField(
                label: Strings.budgetSearch,
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (v) =>
                    ref.read(budgetSearchProvider.notifier).state = v.trim(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final f in BudgetFilter.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: filter == f,
                    onSelected: (_) =>
                        ref.read(budgetFilterProvider.notifier).state = f,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Expanded(child: BudgetList(nrPatient: null)),
          ],
        ),
      ),
    );
  }

  static Future<void> _new(
    BuildContext context,
    WidgetRef ref,
    double max,
  ) async {
    final nr = await BudgetFormDialog.show(context, pcMaxDiscount: max);
    if (nr != null && context.mounted) {
      await BudgetDetailDialog.show(context, nr);
    }
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

/// Lista de orcamentos (da filial ou de um paciente) que abre os detalhes.
class BudgetList extends ConsumerWidget {
  const BudgetList({super.key, required this.nrPatient, this.vcPatient});

  final int? nrPatient;
  final String? vcPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetsProvider(nrPatient));
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.budgets));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(budgetsProvider(nrPatient)),
      ),
      data: (d) {
        final header = nrPatient == null || !canCreate
            ? null
            : Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: Strings.budgetNew,
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () async {
                    final nr = await BudgetFormDialog.show(
                      context,
                      nrPatient: nrPatient,
                      vcPatient: vcPatient,
                      pcMaxDiscount: d.pcMaxDiscount,
                    );
                    if (nr != null && context.mounted) {
                      await BudgetDetailDialog.show(context, nr);
                    }
                  },
                ),
              );
        if (d.budgets.isEmpty) {
          return Column(
            children: [
              ?header,
              const Expanded(
                child: AppEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: Strings.budgetEmpty,
                  subtitle: Strings.budgetEmptyHint,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header,
              const SizedBox(height: AppSpacing.sm),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: d.budgets.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final b = d.budgets[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => BudgetDetailDialog.show(context, b.nrBudget),
                      leading: CircleAvatar(
                        backgroundColor: budgetStatusColor(
                          b.itStatus,
                          expired: b.idExpired,
                        ).withValues(alpha: 0.12),
                        child: Icon(
                          Icons.request_quote_outlined,
                          color: budgetStatusColor(
                            b.itStatus,
                            expired: b.idExpired,
                          ),
                        ),
                      ),
                      title: Text(
                        nrPatient == null
                            ? '${b.vcPatient} · ${b.title}'
                            : b.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${Strings.budgetNumber(b.nrBudget)} · ${Dates.format(b.dtBudget)}'
                        ' · ${Strings.budgetItemsCount(b.qtItems)}'
                        '${b.vcProfessional == null ? '' : ' · ${b.vcProfessional}'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Numbers.money(b.vlTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          BudgetStatusChip(
                            status: b.itStatus,
                            expired: b.idExpired,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
