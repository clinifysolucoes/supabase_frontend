import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/stock_controllers.dart';
import '../domain/stock_models.dart';
import 'stock_dialogs.dart';

/// Tela Estoque: saldos dos materiais (com alerta de minimo) e movimentos.
/// A baixa pelos procedimentos e automatica, pela evolucao clinica.
class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.stock))) {
      return const AppShell(
        section: AppSection.stock,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    return AppShell(
      section: AppSection.stock,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: AppPageHeader(
                title: Strings.stock,
                subtitle: Strings.stockSubtitle,
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: Strings.stockTabBalances),
                Tab(text: Strings.stockTabMovements),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [StockBalancesTab(), StockMovementsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Saldos: materiais com controle, em alerta ou todos.
class StockBalancesTab extends ConsumerWidget {
  const StockBalancesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(stockFilterProvider);
    final data = ref.watch(stockListProvider);
    final d = data.valueOrNull;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (d != null)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Kpi(Strings.stockKpiControlled, '${d.qtControlled}'),
              _Kpi(
                Strings.stockKpiLow,
                '${d.qtLow}',
                color: d.qtLow > 0 ? AppColors.danger : null,
              ),
              _Kpi(Strings.stockKpiValue, Numbers.money(d.vlStock)),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: AppTextField(
                label: Strings.stockSearch,
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (v) =>
                    ref.read(stockSearchProvider.notifier).state = v.trim(),
              ),
            ),
            for (final f in StockFilter.values)
              ChoiceChip(
                label: Text(f.label),
                selected: filter == f,
                onSelected: (_) =>
                    ref.read(stockFilterProvider.notifier).state = f,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        data.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppEmptyState.error(
            message: describeError(e),
            onRetry: () => ref.invalidate(stockListProvider),
          ),
          data: (d) => d.items.isEmpty
              ? AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: Strings.stockEmpty,
                  subtitle: filter == StockFilter.controlled
                      ? Strings.stockEmptyHint
                      : null,
                )
              : Column(
                  children: [
                    for (final i in d.items)
                      StockItemCard(item: i, suppliers: d.suppliers),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Um material: saldo, minimo, valor e as acoes.
class StockItemCard extends ConsumerWidget {
  const StockItemCard({super.key, required this.item, required this.suppliers});

  final StockItem item;
  final List<({int id, String name})> suppliers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = item;
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.stock));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.stock));
    final unit = i.vcUnit ?? '';
    final stock = i.qtStock ?? 0;
    final pk = i.packages;
    Future<void> move(int type) => StockMoveDialog.show(
      context,
      item: i,
      type: type,
      suppliers: suppliers,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: i.idLow ? AppColors.danger : AppColors.line,
          width: i.idLow ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          i.vcName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (i.idLow) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.danger,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    [
                      if ((i.vcPackage ?? '').isNotEmpty) i.vcPackage!,
                      if (i.vlUnitCost != null)
                        Strings.stockUnitCost(
                          Numbers.money(i.vlUnitCost),
                          unit,
                        ),
                      if (i.dtLastMovement != null)
                        Strings.stockLastMove(Dates.format(i.dtLastMovement)),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (i.idControl)
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Numbers.qty(stock)} $unit'.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: i.idLow ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                    Text(
                      [
                        if (pk != null && pk > 0)
                          '≈ ${Numbers.qty(pk, decimals: 1)} ${i.vcPackage ?? Strings.stockPackages}',
                        if (i.qtMin != null)
                          Strings.stockMinShort(Numbers.qty(i.qtMin)),
                        if (i.vlStock > 0) Numbers.money(i.vlStock),
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                Strings.stockNotControlled,
                style: TextStyle(color: AppColors.muted),
              ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (canCreate && i.idControl) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(Strings.stockTypeEntry),
                    onPressed: () => move(StockMoveType.entry),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text(Strings.stockTypeExit),
                    onPressed: () => move(StockMoveType.exit),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text(Strings.stockTypeAdjust),
                    onPressed: () => move(StockMoveType.adjust),
                  ),
                ],
                if (canUpdate)
                  IconButton(
                    tooltip: Strings.stockConfigure,
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => StockItemDialog.show(context, i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Movimentos do periodo com o resumo em valor.
class StockMovementsTab extends ConsumerWidget {
  const StockMovementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(stockPeriodProvider);
    final type = ref.watch(stockTypeProvider);
    final data = ref.watch(stockMovementsProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in StockPeriod.values)
              ChoiceChip(
                label: Text(switch (p) {
                  StockPeriod.last30 => Strings.lastDays(30),
                  StockPeriod.thisMonth => Strings.reportThisMonth,
                  StockPeriod.lastMonth => Strings.reportLastMonth,
                }),
                selected: period == p,
                onSelected: (_) =>
                    ref.read(stockPeriodProvider.notifier).state = p,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text(Strings.stockAllTypes),
              selected: type == null,
              onSelected: (_) =>
                  ref.read(stockTypeProvider.notifier).state = null,
            ),
            for (final t in StockMoveType.all)
              ChoiceChip(
                label: Text(StockMoveType.label(t)),
                selected: type == t,
                onSelected: (_) =>
                    ref.read(stockTypeProvider.notifier).state = t,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        data.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppEmptyState.error(
            message: describeError(e),
            onRetry: () => ref.invalidate(stockMovementsProvider),
          ),
          data: (d) => StockMovementsView(data: d),
        ),
      ],
    );
  }
}

class StockMovementsView extends StatelessWidget {
  const StockMovementsView({super.key, required this.data});

  final StockMovementData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Kpi(Strings.stockKpiIn, Numbers.money(d.vlIn)),
            _Kpi(Strings.stockKpiProcedures, Numbers.money(d.vlProcedures)),
            _Kpi(Strings.stockKpiOut, Numbers.money(d.vlOut)),
            _Kpi(Strings.stockKpiAdjust, Numbers.money(d.vlAdjust)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (d.movements.isEmpty)
          const AppEmptyState(
            icon: Icons.swap_vert_rounded,
            title: Strings.stockNoMovements,
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text(Strings.stockDate)),
                  DataColumn(label: Text(Strings.stockMaterial)),
                  DataColumn(label: Text(Strings.stockType)),
                  DataColumn(label: Text(Strings.stockQty), numeric: true),
                  DataColumn(label: Text(Strings.stockBalance), numeric: true),
                  DataColumn(label: Text(Strings.stockValue), numeric: true),
                  DataColumn(label: Text(Strings.stockDetails)),
                ],
                rows: [
                  for (final m in d.movements)
                    DataRow(
                      cells: [
                        DataCell(Text(Dates.format(m.dtMovement))),
                        DataCell(Text(m.vcMaterial)),
                        DataCell(Text(StockMoveType.label(m.itType))),
                        DataCell(
                          Text(
                            '${m.qtQuantity > 0 ? '+' : ''}${Numbers.qty(m.qtQuantity)} ${m.vcUnit ?? ''}'
                                .trim(),
                            style: TextStyle(
                              color: m.qtQuantity < 0
                                  ? AppColors.danger
                                  : AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(Text(Numbers.qty(m.qtBalance))),
                        DataCell(
                          Text(
                            m.vlTotal == null ? '' : Numbers.money(m.vlTotal),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(
                              m.details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (d.idTruncated)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              Strings.stockTruncated,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}
