import 'dart:math' as math;

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
import 'procedure_materials_dialog.dart';

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
  final _groupKeys = <String, GlobalKey>{};
  final _jumpMenu = GlobalKey<PopupMenuButtonState<String>>();
  final _listScroll = ScrollController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _listScroll.dispose();
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

  /// Rola a lista ate o titulo da especialidade escolhida. No desktop a
  /// posicao e exata; nos cards e estimada e acertada depois de montar.
  Future<void> _jumpTo(String group) async {
    final data = ref.read(proceduresProvider).valueOrNull;
    if (data == null || !_listScroll.hasClients) return;
    final mobile = context.isMobile;
    final pos = _listScroll.position;
    final target = groupOffset(
      data.procedures,
      group,
      mobile: mobile,
    ).clamp(0.0, pos.maxScrollExtent);
    await _listScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (!mobile || !mounted) return;
    final ctx = _groupKeys[group]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
      );
    }
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
            if (data != null && groupBySpecialty(data.procedures).length > 1)
              PopupMenuButton<String>(
                key: _jumpMenu,
                tooltip: Strings.jumpToSpecialty,
                onSelected: _jumpTo,
                itemBuilder: (_) => [
                  for (final g in groupBySpecialty(data.procedures))
                    PopupMenuItem(
                      value: g.name ?? Strings.noSpecialty,
                      child: Text(
                        '${g.name ?? Strings.noSpecialty} · ${g.items.length}',
                      ),
                    ),
                ],
                child: AppButton(
                  label: Strings.jumpToSpecialty,
                  icon: Icons.format_list_bulleted_rounded,
                  variant: AppButtonVariant.secondary,
                  expanded: false,
                  onPressed: () => _jumpMenu.currentState?.showButtonMenu(),
                ),
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
                  groupKeys: _groupKeys,
                  controller: _listScroll,
                  onTap: (p) => _openForm(d, p),
                ),
                desktop: (_) => ProcedureTable(
                  items: d.procedures,
                  groupKeys: _groupKeys,
                  controller: _listScroll,
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

/// Agrupa por especialidade: nomes em ordem alfabetica e os sem especialidade
/// no fim. Dentro do grupo mantem a ordem que veio do banco.
List<({String? name, List<Procedure> items})> groupBySpecialty(
  List<Procedure> items,
) {
  final map = <String?, List<Procedure>>{};
  for (final p in items) {
    (map[p.vcSpecialty] ??= []).add(p);
  }
  final keys = map.keys.toList()
    ..sort((a, b) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [for (final k in keys) (name: k, items: map[k]!)];
}

/// Uma linha da lista: titulo de grupo ou procedimento.
typedef _Entry = ({String? group, int count, Procedure? procedure});

List<_Entry> _entries(List<Procedure> items, bool grouped) => grouped
    ? [
        for (final g in groupBySpecialty(items)) ...[
          (
            group: g.name ?? Strings.noSpecialty,
            count: g.items.length,
            procedure: null,
          ),
          for (final p in g.items) (group: null, count: 0, procedure: p),
        ],
      ]
    : [for (final p in items) (group: null, count: 0, procedure: p)];

const _groupExtent = 40.0;
const _rowExtent = 64.0;

/// Altura de cada linha da lista: exata no desktop, estimada nos cards.
double _entryExtent(_Entry e, {required bool mobile}) => e.procedure == null
    ? (mobile ? _groupExtent + AppSpacing.sm : _groupExtent)
    : (mobile ? 128 : _rowExtent);

/// Onde comeca o grupo [group] na lista (desktop exato, mobile estimado).
double groupOffset(List<Procedure> items, String group, {bool mobile = false}) {
  var offset = 0.0;
  for (final e in _entries(items, true)) {
    if (e.procedure == null && e.group == group) return offset;
    offset += _entryExtent(e, mobile: mobile);
  }
  return offset;
}

class _Col {
  const _Col(this.label, {this.width, this.numeric = false});
  final String label;
  final double? width;
  final bool numeric;
}

// Acoes na primeira coluna: em janela estreita a tabela rola na horizontal
// e os botoes continuam visiveis.
const _cols = [
  _Col(Strings.actions, width: 96),
  _Col(Strings.procedureName),
  _Col(Strings.time, width: 80),
  _Col(Strings.directCost, width: 112, numeric: true),
  _Col(Strings.minPrice, width: 112, numeric: true),
  _Col(Strings.suggestedPrice, width: 120, numeric: true),
  _Col(Strings.current, width: 112, numeric: true),
  _Col(Strings.difference, width: 112, numeric: true),
  _Col(Strings.priceCheckColumn, width: 210),
  _Col(Strings.status, width: 110),
];

const _cellPad = AppSpacing.sm;

Widget _row(List<Widget> cells) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - _cellPad),
  child: Row(
    children: [
      for (var i = 0; i < _cols.length; i++)
        _cols[i].width == null
            ? Expanded(child: _cell(_cols[i], cells[i]))
            : SizedBox(width: _cols[i].width, child: _cell(_cols[i], cells[i])),
    ],
  ),
);

Widget _cell(_Col c, Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: _cellPad),
  child: Align(
    alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft,
    // colunas de largura fixa: encolhe em vez de estourar (chips, valores altos)
    child: c.width == null
        ? child
        : FittedBox(fit: BoxFit.scaleDown, child: child),
  ),
);

/// Lista de procedimentos no desktop (aba Procedimentos e especialidade aberta).
/// O cabecalho das colunas fica fixo e so a lista rola. [showSpecialty] = true
/// agrupa por especialidade (na especialidade aberta todos sao da mesma).
class ProcedureTable extends StatelessWidget {
  const ProcedureTable({
    super.key,
    required this.items,
    required this.onTap,
    this.showSpecialty = true,
    this.groupKeys,
    this.controller,
  });

  final List<Procedure> items;
  final ValueChanged<Procedure> onTap;
  final bool showSpecialty;

  /// Chave do titulo de cada grupo (nome da especialidade), para o seletor
  /// "Ir para especialidade" rolar ate ele.
  final Map<String, GlobalKey>? groupKeys;

  /// Rolagem da lista (o seletor "Ir para especialidade" usa).
  final ScrollController? controller;

  /// Colunas fixas + 300 para o nome; abaixo disso rola na horizontal.
  static const minWidth = 1520.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries(items, showSpecialty);
    final headStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, minWidth);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Container(
                    key: const Key('procedure-table-header'),
                    color: AppColors.surface,
                    height: 48,
                    child: _row([
                      for (final c in _cols) Text(c.label, style: headStyle),
                    ]),
                  ),
                  const Divider(height: 1, thickness: 0.6),
                  Expanded(
                    // altura fixa por linha: o seletor calcula onde fica cada
                    // grupo sem montar a lista inteira
                    child: ListView.builder(
                      controller: controller,
                      itemCount: entries.length,
                      itemExtentBuilder: (i, _) => i < entries.length
                          ? _entryExtent(entries[i], mobile: false)
                          : null,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final p = e.procedure;
                        if (p == null) {
                          return _GroupHeader(
                            key: groupKeys?.putIfAbsent(
                              e.group!,
                              GlobalKey.new,
                            ),
                            name: e.group!,
                            count: e.count,
                          );
                        }
                        return _ProcedureRow(
                          procedure: p,
                          onTap: () => onTap(p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mint,
      height: _groupExtent,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(
            Icons.category_outlined,
            size: 18,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Strings.proceduresCount(count),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProcedureRow extends StatelessWidget {
  const _ProcedureRow({required this.procedure, required this.onTap});

  final Procedure procedure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = procedure;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _rowExtent,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line, width: 0.6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: _row([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: Strings.procedureMaterials,
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => ProcedureMaterialsDialog.show(context, p),
              ),
              IconButton(
                tooltip: Strings.edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onTap,
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (p.setupAlerts.isNotEmpty)
                ProcedureAlertChips(alerts: p.setupAlerts),
            ],
          ),
          Text(Numbers.minutes(p.qtMinutes)),
          Text(Numbers.money(p.pricing?.vlDirectCost)),
          Text(Numbers.money(p.pricing?.vlPriceMin)),
          Text(
            Numbers.money(p.pricing?.vlPrice),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          Text(Numbers.money(p.vlCurrentPrice)),
          Text(
            _diffText(p.priceDiff),
            style: TextStyle(
              color: _diffColor(p.priceDiff),
              fontWeight: FontWeight.w700,
            ),
          ),
          p.vlCurrentPrice == null
              ? const Text('-')
              : PriceStatusChip(status: p.priceStatus),
          AppStatusChip(status: p.itStatus, compact: true),
        ]),
      ),
    );
  }
}

/// Lista de procedimentos no mobile (cards), agrupada como a do desktop.
class ProcedureCards extends StatelessWidget {
  const ProcedureCards({
    super.key,
    required this.items,
    required this.onTap,
    this.showSpecialty = true,
    this.groupKeys,
    this.controller,
  });

  final List<Procedure> items;
  final ValueChanged<Procedure> onTap;
  final bool showSpecialty;

  /// Chave do titulo de cada grupo (nome da especialidade), para o seletor
  /// "Ir para especialidade" rolar ate ele.
  final Map<String, GlobalKey>? groupKeys;

  /// Rolagem da lista (o seletor "Ir para especialidade" usa).
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final entries = _entries(items, showSpecialty);
    return ListView.builder(
      controller: controller,
      itemCount: entries.length,
      itemBuilder: (context, i) => _card(context, entries[i]),
    );
  }

  Widget _card(BuildContext context, _Entry e) {
    final p = e.procedure;
    if (p == null) {
      return Padding(
        key: groupKeys?.putIfAbsent(e.group!, GlobalKey.new),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _GroupHeader(name: e.group!, count: e.count),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
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
                    IconButton(
                      tooltip: Strings.procedureMaterials,
                      icon: const Icon(Icons.inventory_2_outlined),
                      onPressed: () =>
                          ProcedureMaterialsDialog.show(context, p),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    Numbers.minutes(p.qtMinutes),
                    '${Strings.directCost} ${Numbers.money(p.pricing?.vlDirectCost)}',
                    '${Strings.minPrice} ${Numbers.money(p.pricing?.vlPriceMin)}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
      ),
    );
  }
}
