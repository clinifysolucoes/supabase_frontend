import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/pricing_controllers.dart';
import '../data/pricing_export.dart';
import '../domain/pricing_models.dart';
import 'factor_edit_dialog.dart';
import 'pricing_breakdown.dart';
import 'procedure_form_dialog.dart';

/// Aba Procedimentos: fatores do preco (clicaveis), lista com o preco
/// calculado no banco e a situacao do valor cobrado hoje, filtros (inclusive
/// por especialidade), simulacao do regime (PF x PJ) e cadastro.
class ProceduresTab extends ConsumerStatefulWidget {
  const ProceduresTab({super.key});

  @override
  ConsumerState<ProceduresTab> createState() => _ProceduresTabState();
}

class _ProceduresTabState extends ConsumerState<ProceduresTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setFilters(ProcedureFilters f) =>
      ref.read(procedureFiltersProvider.notifier).state = f;

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _setFilters(ref.read(procedureFiltersProvider).copyWith(search: value));
    });
  }

  Future<void> _openForm(ProcedureListData data, [Procedure? p]) async {
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.pricing));
    final saved = await ProcedureFormDialog.show(
      context,
      procedure: p,
      params: data.params,
      summary: data.summary,
      readOnly: p != null && !canUpdate,
      initialSpecialty: p == null
          ? ref.read(procedureFiltersProvider).nrSpecialty
          : null,
    );
    if (saved && mounted) AppSnack.success(context, Strings.savedSuccess);
  }

  Future<void> _export(ProcedureListData data) async {
    try {
      final now = DateTime.now();
      final bytes = PricingExport.buildXlsx(data, now: now);
      await FileDownload.saveXlsx(
        name: PricingExport.fileName(now),
        bytes: bytes,
      );
      if (mounted) AppSnack.success(context, Strings.exportDone);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _editFactor(PricingFactor factor) async {
    final result = await FactorEditDialog.show(context, factor: factor);
    if (result != null && mounted) {
      AppSnack.success(context, Strings.paramsSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filters = ref.watch(procedureFiltersProvider);
    final async = ref.watch(proceduresProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.pricing));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.pricing));
    final data = async.valueOrNull;
    final isMobile = context.isMobile;

    final specialties =
        ref.watch(specialtyCatalogProvider).valueOrNull ?? const [];
    final specialtyChoices = [
      const Choice<int>(value: null, label: Strings.allSpecialties),
      for (final s in specialties)
        Choice<int>(value: s.nrSpecialty, label: s.vcName),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data != null) ...[
          _FactorTiles(
            params: data.params,
            summary: data.summary,
            enabled: canUpdate || (canCreate && !data.params.idSaved),
            onEdit: _editFactor,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 260,
              child: AppTextField(
                label: Strings.search,
                hint: Strings.searchProceduresHint,
                controller: _search,
                prefixIcon: Icons.search_rounded,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: SearchableDropdown<Choice<int>>(
                label: Strings.specialty,
                items: specialtyChoices,
                value: specialtyChoices.firstWhere(
                  (c) => c.value == filters.nrSpecialty,
                  orElse: () => specialtyChoices.first,
                ),
                itemLabel: (c) => c.label,
                onChanged: (c) => _setFilters(
                  c.value == null
                      ? filters.copyWith(clearSpecialty: true)
                      : filters.copyWith(nrSpecialty: c.value),
                ),
              ),
            ),
            _RegimeChips(
              value: filters.itTaxRegime,
              onChanged: (v) => _setFilters(
                v == null
                    ? filters.copyWith(clearRegime: true)
                    : filters.copyWith(itTaxRegime: v),
              ),
            ),
            FilterChip(
              label: const Text(Strings.showInactive),
              selected: filters.includeInactive,
              onSelected: (v) =>
                  _setFilters(filters.copyWith(includeInactive: v)),
            ),
            if (data != null && data.procedures.isNotEmpty)
              AppButton(
                label: Strings.exportExcel,
                icon: Icons.download_rounded,
                variant: AppButtonVariant.secondary,
                expanded: false,
                onPressed: () => _export(data),
              ),
            if (canCreate && data != null)
              AppButton(
                label: Strings.newProcedure,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () => _openForm(data),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(proceduresProvider),
            ),
            data: (d) {
              if (d == null || d.procedures.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.medical_services_outlined,
                  title: Strings.noProcedures,
                );
              }
              return ResponsiveBuilder(
                mobile: (_) => ProcedureCards(
                  items: d.procedures,
                  onTap: (p) => _openForm(d, p),
                ),
                desktop: (_) => ProcedureTable(
                  items: d.procedures,
                  onTap: (p) => _openForm(d, p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Regime da filial · PF · PJ (simulacao sem alterar os parametros).
class _RegimeChips extends StatelessWidget {
  const _RegimeChips({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(int? v, String label) => ChoiceChip(
      label: Text(label),
      selected: value == v,
      onSelected: (_) => onChanged(v),
    );
    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '${Strings.simulateRegime}:',
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        chip(null, Strings.regimeFromParams),
        chip(TaxRegime.pf, Strings.taxRegimePfShort),
        chip(TaxRegime.pj, Strings.taxRegimePjShort),
      ],
    );
  }
}

/// Fatores do preco em vigor: cada um e um botao que abre a edicao inline.
class _FactorTiles extends StatelessWidget {
  const _FactorTiles({
    required this.params,
    required this.summary,
    required this.enabled,
    required this.onEdit,
  });

  final PricingParams params;
  final PricingSummary summary;
  final bool enabled;
  final ValueChanged<PricingFactor> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regime = summary.itTaxRegime ?? params.itTaxRegime;
    final manual = params.vlStructureHourManual != null;

    Widget tile(PricingFactor f, String label, String value, {String? tag}) {
      final body = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(f.icon, size: 20, color: AppColors.primaryDark),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      AppTagChip(label: tag, highlighted: true),
                    ],
                  ],
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      );
      if (!enabled) return body;
      return Tooltip(
        message: Strings.editFactor,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            hoverColor: AppColors.mint,
            onTap: () => onEdit(f),
            child: body,
          ),
        ),
      );
    }

    final tiles = <Widget>[
      tile(
        PricingFactor.structure,
        Strings.structureHour,
        '${Numbers.money(summary.vlStructureHour)}${Strings.perHour}',
        tag: manual ? Strings.structureManualTag : null,
      ),
      tile(
        PricingFactor.professional,
        Strings.professionalHour,
        '${Numbers.money(params.vlProfessionalHour)}${Strings.perHour}',
      ),
      tile(
        PricingFactor.card,
        Strings.cardFee,
        Numbers.percent(params.pcCard, decimals: 2),
      ),
      tile(
        PricingFactor.commission,
        Strings.commission,
        Numbers.percent(params.pcCommission, decimals: 2),
      ),
      tile(
        PricingFactor.fees,
        Strings.extraFees,
        Numbers.percent(summary.pcFees, decimals: 2),
      ),
      tile(
        PricingFactor.tax,
        '${Strings.incomeTax} · ${TaxRegime.label(regime)}',
        Numbers.percent(summary.pcTax, decimals: 2),
      ),
      tile(
        PricingFactor.profit,
        Strings.profit,
        Numbers.percent(params.pcProfit, decimals: 2),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              Strings.factorsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  Strings.factorsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // janela baixa: uma linha so (rola na horizontal), senao os fatores e
        // os filtros ocupam a altura toda e a lista de procedimentos some
        if (context.isMobile || MediaQuery.sizeOf(context).height < 820)
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => tiles[i],
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: tiles,
          ),
      ],
    );
  }
}

Color _diffColor(double? diff) => diff == null
    ? AppColors.muted
    : (diff >= 0 ? AppColors.success : AppColors.danger);

String _diffText(double? diff) =>
    diff == null ? '-' : '${diff >= 0 ? '+' : ''}${Numbers.money(diff)}';

/// Lista de procedimentos no desktop (aba Procedimentos e especialidade aberta).
/// [showSpecialty] = false quando todos sao da mesma especialidade.
class ProcedureTable extends StatelessWidget {
  const ProcedureTable({
    super.key,
    required this.items,
    required this.onTap,
    this.showSpecialty = true,
  });

  final List<Procedure> items;
  final ValueChanged<Procedure> onTap;
  final bool showSpecialty;

  @override
  Widget build(BuildContext context) {
    return AppTable(
      minWidth: 1100,
      columns: const [
        DataColumn(label: Text(Strings.procedureName)),
        DataColumn(label: Text(Strings.time)),
        DataColumn(label: Text(Strings.directCost), numeric: true),
        DataColumn(label: Text(Strings.minPrice), numeric: true),
        DataColumn(label: Text(Strings.suggestedPrice), numeric: true),
        DataColumn(label: Text(Strings.current), numeric: true),
        DataColumn(label: Text(Strings.difference), numeric: true),
        DataColumn(label: Text(Strings.priceCheckColumn)),
        DataColumn(label: Text(Strings.status)),
        DataColumn(label: Text(Strings.actions)),
      ],
      rows: [
        for (final p in items)
          DataRow(
            // a linha inteira abre o cadastro (o lapis pode ficar fora da tela)
            onSelectChanged: (_) => onTap(p),
            cells: [
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ((showSpecialty && p.vcSpecialty != null) ||
                        p.setupAlerts.isNotEmpty)
                      Row(
                        children: [
                          if (showSpecialty && p.vcSpecialty != null)
                            Text(
                              p.vcSpecialty!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          if (showSpecialty &&
                              p.vcSpecialty != null &&
                              p.setupAlerts.isNotEmpty)
                            const SizedBox(width: AppSpacing.sm),
                          ProcedureAlertChips(alerts: p.setupAlerts),
                        ],
                      ),
                  ],
                ),
                onTap: () => onTap(p),
              ),
              DataCell(Text(Numbers.minutes(p.qtMinutes))),
              DataCell(Text(Numbers.money(p.pricing?.vlDirectCost))),
              DataCell(Text(Numbers.money(p.pricing?.vlPriceMin))),
              DataCell(
                Text(
                  Numbers.money(p.pricing?.vlPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                onTap: () => onTap(p),
              ),
              DataCell(Text(Numbers.money(p.vlCurrentPrice))),
              DataCell(
                Text(
                  _diffText(p.priceDiff),
                  style: TextStyle(
                    color: _diffColor(p.priceDiff),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DataCell(
                p.vlCurrentPrice == null
                    ? const Text('-')
                    : PriceStatusChip(status: p.priceStatus),
                onTap: () => onTap(p),
              ),
              DataCell(AppStatusChip(status: p.itStatus, compact: true)),
              DataCell(
                IconButton(
                  tooltip: Strings.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onTap(p),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Lista de procedimentos no mobile (cards).
class ProcedureCards extends StatelessWidget {
  const ProcedureCards({
    super.key,
    required this.items,
    required this.onTap,
    this.showSpecialty = true,
  });

  final List<Procedure> items;
  final ValueChanged<Procedure> onTap;
  final bool showSpecialty;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final p = items[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => onTap(p),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        Numbers.money(p.pricing?.vlPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (showSpecialty && p.vcSpecialty != null)
                        p.vcSpecialty!,
                      Numbers.minutes(p.qtMinutes),
                      '${Strings.directCost} ${Numbers.money(p.pricing?.vlDirectCost)}',
                      '${Strings.minPrice} ${Numbers.money(p.pricing?.vlPriceMin)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (p.vlCurrentPrice != null)
                    Text(
                      '${Strings.current} ${Numbers.money(p.vlCurrentPrice)} · ${_diffText(p.priceDiff)}',
                      style: TextStyle(
                        color: _diffColor(p.priceDiff),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (p.alerts.isNotEmpty ||
                      !p.isActive ||
                      p.vlCurrentPrice != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (p.vlCurrentPrice != null)
                          PriceStatusChip(status: p.priceStatus),
                        if (!p.isActive)
                          AppStatusChip(status: p.itStatus, compact: true),
                        ProcedureAlertChips(alerts: p.setupAlerts),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
