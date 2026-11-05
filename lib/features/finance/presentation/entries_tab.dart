import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_table.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'checkout_dialog.dart';
import 'entry_actions.dart';
import 'entry_form_dialog.dart';
import 'finance_widgets.dart';
import 'recurrences_dialog.dart';

/// Contas a pagar ou a receber do mes: filtros, totais e a lista.
class EntriesTab extends ConsumerStatefulWidget {
  const EntriesTab({super.key, required this.kind});

  final int kind;

  @override
  ConsumerState<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<EntriesTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(entriesSearchProvider(widget.kind));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(entriesSearchProvider(widget.kind).notifier).state = text;
    });
  }

  Future<void> _create() async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!mounted) return;
    await EntryFormDialog.show(context, kind: widget.kind, catalog: catalog);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final receivable = kind == EntryKind.receivable;
    final month = ref.watch(entriesMonthProvider(kind));
    final filter = ref.watch(entriesFilterProvider(kind));
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final async = ref.watch(entriesProvider(kind));
    final data = async.valueOrNull;
    final labels = {
      EntryFilter.all: Strings.finFilterAll,
      EntryFilter.open: Strings.finFilterOpen,
      EntryFilter.overdue: Strings.finFilterOverdue,
      EntryFilter.paid: Strings.finFilterPaid,
      EntryFilter.cancelled: Strings.finFilterCancelled,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filter != EntryFilter.overdue)
              MonthSwitcher(
                month: month,
                onChanged: (m) =>
                    ref.read(entriesMonthProvider(kind).notifier).state = m,
              ),
            SizedBox(
              width: context.isMobile ? double.infinity : 260,
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: Strings.finSearchHint,
                ),
              ),
            ),
            if (canCreate)
              AppButton(
                label: receivable ? Strings.newReceivable : Strings.newPayable,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: _create,
              ),
            AppButton(
              label: Strings.recurrences,
              icon: Icons.event_repeat_rounded,
              variant: AppButtonVariant.secondary,
              expanded: false,
              onPressed: () => RecurrencesDialog.show(context, kind),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final f in EntryFilter.values)
              ChoiceChip(
                label: Text(labels[f]!),
                selected: filter == f,
                onSelected: (_) =>
                    ref.read(entriesFilterProvider(kind).notifier).state = f,
              ),
            if (filter != EntryFilter.overdue)
              FilterChip(
                label: const Text(Strings.finByCompetence),
                selected: ref.watch(entriesByCompetenceProvider(kind)),
                onSelected: (v) =>
                    ref.read(entriesByCompetenceProvider(kind).notifier).state =
                        v,
              ),
            FilterChip(
              label: const Text(Strings.finOnlyInstallments),
              selected: ref.watch(entriesInstallmentsProvider(kind)),
              onSelected: (v) =>
                  ref.read(entriesInstallmentsProvider(kind).notifier).state =
                      v,
            ),
          ],
        ),
        if (receivable) const _PendingCheckouts(),
        if (filter == EntryFilter.overdue)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              Strings.finOverdueRange,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (data != null) ...[
          _Totals(totals: data.totals, receivable: receivable),
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(entriesProvider(kind)),
            ),
            data: (d) => d.entries.isEmpty
                ? const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: Strings.finNoEntries,
                    subtitle: Strings.finNoEntriesHint,
                  )
                : context.isMobile
                ? ListView.separated(
                    itemCount: d.entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _EntryCard(
                      entry: d.entries[i],
                      onTap: () =>
                          EntryActions.open(context, ref, d.entries[i]),
                    ),
                  )
                : AppTable(
                    minWidth: 900,
                    columns: [
                      const DataColumn(label: Text(Strings.finDue)),
                      const DataColumn(label: Text(Strings.finDescription)),
                      const DataColumn(label: Text(Strings.finCategory)),
                      DataColumn(
                        label: Text(
                          receivable ? Strings.finPatient : Strings.finSupplier,
                        ),
                      ),
                      const DataColumn(
                        label: Text(Strings.finAmount),
                        numeric: true,
                      ),
                      const DataColumn(label: Text(Strings.status)),
                      const DataColumn(label: Text(Strings.finAccount)),
                    ],
                    rows: [
                      for (final e in d.entries)
                        DataRow(
                          onSelectChanged: (_) =>
                              EntryActions.open(context, ref, e),
                          cells: [
                            DataCell(Text(Dates.format(e.dtDue))),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.vcDescription,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: e.isCancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (e.isGrouped ||
                                      e.idRecurring ||
                                      e.qtAttachments > 0)
                                    Row(
                                      children: [
                                        if (e.isGrouped || e.idRecurring)
                                          Text(
                                            e.idRecurring
                                                ? Strings.finRecurring
                                                : Strings.finInstallmentOf(
                                                    e.nrInstallment,
                                                    e.qtInstallments,
                                                  ),
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (e.qtAttachments > 0) ...[
                                          const SizedBox(width: 6),
                                          Tooltip(
                                            message: Strings.attachments,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.attach_file_rounded,
                                                  size: 14,
                                                  color: AppColors.muted,
                                                ),
                                                Text(
                                                  '${e.qtAttachments}',
                                                  style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text(e.vcCategory ?? '-')),
                            DataCell(Text(e.counterpart ?? '-')),
                            DataCell(
                              Text(
                                Numbers.money(e.isPaid ? e.vlPaid : e.vlAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(EntryStatusChip(entry: e)),
                            DataCell(Text(e.vcAccount ?? '-')),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Aviso das consultas do mes que ja aconteceram e nao foram fechadas;
/// abre a lista e o fechamento de cada uma.
class _PendingCheckouts extends ConsumerWidget {
  const _PendingCheckouts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(pendingCheckoutsProvider).valueOrNull ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        color: AppColors.goldPale,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(
              Icons.pending_actions_rounded,
              color: AppColors.goldDark,
            ),
            title: Text(
              Strings.pendingCheckoutTitle(list.length),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              Strings.pendingCheckoutHint,
              style: TextStyle(fontSize: 12),
            ),
            children: [
              for (final a in list)
                ListTile(
                  dense: true,
                  title: Text(
                    a.vcPatient,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      '${Dates.format(a.dhStart)} ${Dates.formatTime(a.dhStart)}',
                      ?a.vcProcedure,
                      ?a.vcProfessional,
                    ].join(' · '),
                  ),
                  trailing: canCreate
                      ? TextButton(
                          onPressed: () =>
                              CheckoutDialog.show(context, a.nrAppointment),
                          child: const Text(Strings.checkoutAction),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.receivable});

  final FinTotals totals;
  final bool receivable;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    Widget item(String label, double value, Color color) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Text(
            Numbers.money(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    final byType = [
      for (final type in CostType.all)
        if ((t.byCostType[type] ?? 0) > 0)
          '${CostType.label(type)} ${Numbers.money(t.byCostType[type])}',
    ];
    return Wrap(
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        item(Strings.finTotalOpen, t.vlOpen, AppColors.ink),
        item(Strings.finTotalOverdue, t.vlOverdue, AppColors.danger),
        item(
          receivable ? Strings.finReceived : Strings.finPaid,
          t.vlPaid,
          AppColors.success,
        ),
        if (!receivable && byType.isNotEmpty)
          Text(
            '${Strings.finByCostType}: ${byType.join(' · ')}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final FinEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: EntryStatusChip.colorOf(e)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.vcDescription,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                Dates.format(e.dtDue),
                                ?e.vcCategory,
                                ?e.counterpart,
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Numbers.money(e.isPaid ? e.vlPaid : e.vlAmount),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          EntryStatusChip(entry: e),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
