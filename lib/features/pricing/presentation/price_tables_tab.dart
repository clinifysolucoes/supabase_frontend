import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../data/pricing_repository.dart';
import '../domain/pricing_models.dart';

/// Tabela de preco particular (od.price_table) com o preco de cada
/// procedimento.
class PriceTable {
  const PriceTable({
    required this.nrPriceTable,
    required this.vcName,
    this.idDefault = false,
    this.vcNotes,
    this.itStatus = 1,
    this.prices = const {},
  });

  factory PriceTable.fromJson(Map<String, dynamic> j) => PriceTable(
    nrPriceTable: (j['nr_price_table'] as num).toInt(),
    vcName: j['vc_name'] as String? ?? '',
    idDefault: j['id_default'] == true,
    vcNotes: j['vc_notes'] as String?,
    itStatus: (j['it_status'] as num?)?.toInt() ?? 1,
    prices: {
      for (final i in (j['items'] as List? ?? const []))
        ((i as Map)['nr_procedure'] as num).toInt(): (i['vl_price'] as num)
            .toDouble(),
    },
  );

  final int nrPriceTable;
  final String vcName;
  final bool idDefault;
  final String? vcNotes;
  final int itStatus;

  /// nr_procedure -> preco.
  final Map<int, double> prices;

  bool get isActive => itStatus == 1;

  /// Preco do procedimento nesta tabela (null = valor cobrado hoje).
  double? priceOf(int nrProcedure) => prices[nrProcedure];
}

/// Tabelas da filial atual (com as inativas).
final priceTablesProvider = FutureProvider.autoDispose<List<PriceTable>>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const [];
  final json = await ref.read(supabaseGatewayProvider).rpc('price_table_list', {
    'nr_company': c,
    'nr_branch': b,
    'id_include_inactive': true,
  });
  return [
    for (final t in (json['tables'] as List? ?? const []))
      PriceTable.fromJson((t as Map).cast<String, dynamic>()),
  ];
});

/// Todos os procedimentos da filial (sem os filtros da aba Procedimentos).
final priceTableProceduresProvider =
    FutureProvider.autoDispose<List<Procedure>>((ref) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const [];
      final data = await ref
          .read(pricingRepositoryProvider)
          .procedures(nrCompany: c, nrBranch: b, includeInactive: true);
      return data.procedures;
    });

/// Aba Tabelas de preco da Precificacao.
class PriceTablesTab extends ConsumerWidget {
  const PriceTablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.pricing));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.pricing));
    final async = ref.watch(priceTablesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(priceTablesProvider),
      ),
      data: (tables) => ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  Strings.priceTablesHint,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              if (canCreate)
                AppButton(
                  label: Strings.priceTableNew,
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () => PriceTableDialog.show(context),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (tables.isEmpty)
            const AppEmptyState(
              icon: Icons.request_quote_outlined,
              title: Strings.priceTablesEmpty,
            )
          else
            for (final t in tables)
              Card(
                child: ListTile(
                  leading: Icon(
                    t.idDefault
                        ? Icons.star_rounded
                        : Icons.request_quote_outlined,
                    color: t.isActive ? AppColors.primary : AppColors.muted,
                  ),
                  title: Text(
                    t.vcName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: t.isActive ? null : AppColors.muted,
                    ),
                  ),
                  subtitle: Text(
                    [
                      Strings.priceTableCount(t.prices.length),
                      if (t.idDefault) Strings.priceTableDefault,
                      if (!t.isActive) Strings.statusInactive,
                    ].join(' · '),
                  ),
                  trailing: canUpdate
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: canUpdate
                      ? () => PriceTableDialog.show(context, table: t)
                      : null,
                ),
              ),
        ],
      ),
    );
  }
}

/// Cria ou altera uma tabela de preco e os precos dos procedimentos.
class PriceTableDialog extends ConsumerStatefulWidget {
  const PriceTableDialog({super.key, this.table});

  final PriceTable? table;

  static Future<void> show(BuildContext context, {PriceTable? table}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PriceTableDialog(table: table),
      );

  @override
  ConsumerState<PriceTableDialog> createState() => _PriceTableDialogState();
}

class _PriceTableDialogState extends ConsumerState<PriceTableDialog> {
  late final _name = TextEditingController(text: widget.table?.vcName ?? '');
  late final _notes = TextEditingController(text: widget.table?.vcNotes ?? '');
  late bool _default = widget.table?.idDefault ?? false;
  late bool _active = widget.table?.isActive ?? true;
  final Map<int, TextEditingController> _prices = {};
  String _q = '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _priceField(int nrProcedure) =>
      _prices.putIfAbsent(nrProcedure, () {
        final v = widget.table?.priceOf(nrProcedure);
        return TextEditingController(text: v == null ? '' : Numbers.toField(v));
      });

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppSnack.error(context, Strings.priceTableNameRequired);
      return;
    }
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    // precos: os que ja estavam e os digitados agora
    final items = <Map<String, dynamic>>[];
    final ids = {...?widget.table?.prices.keys, ..._prices.keys};
    for (final id in ids) {
      final text = _prices[id]?.text ?? '';
      final v = _prices.containsKey(id)
          ? Numbers.parse(text)
          : widget.table?.priceOf(id);
      if (v != null) items.add({'nr_procedure': id, 'vl_price': v});
    }
    setState(() => _saving = true);
    try {
      await ref.read(supabaseGatewayProvider).rpc('price_table_save', {
        'vc_action': widget.table == null ? 'I' : 'U',
        'nr_company': c,
        'nr_branch': b,
        if (widget.table != null) 'nr_price_table': widget.table!.nrPriceTable,
        'vc_name': _name.text.trim(),
        'vc_notes': _notes.text.trim(),
        'id_default': _default,
        if (widget.table != null) 'it_status': _active ? 1 : 90,
        'items': items,
      });
      ref.invalidate(priceTablesProvider);
      if (mounted) {
        Navigator.of(context).pop();
        AppSnack.success(context, Strings.savedSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final procedures = [
      for (final p
          in ref.watch(priceTableProceduresProvider).valueOrNull ??
              const <Procedure>[])
        if (p.isActive || widget.table?.priceOf(p.nrProcedure) != null)
          if (_q.isEmpty || p.vcName.toLowerCase().contains(_q.toLowerCase()))
            p,
    ];
    return AlertDialog(
      title: Text(
        widget.table == null ? Strings.priceTableNew : Strings.priceTableEdit,
      ),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: Strings.name,
              controller: _name,
              maxLength: 60,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
            ),
            AppTextField(
              label: Strings.notes,
              controller: _notes,
              maxLength: 500,
              enabled: !_saving,
            ),
            Wrap(
              spacing: AppSpacing.lg,
              children: [
                FilterChip(
                  label: const Text(Strings.priceTableDefault),
                  selected: _default,
                  onSelected: _saving || !_active
                      ? null
                      : (v) => setState(() => _default = v),
                ),
                if (widget.table != null)
                  FilterChip(
                    label: const Text(Strings.statusActive),
                    selected: _active,
                    onSelected: _saving
                        ? null
                        : (v) => setState(() {
                            _active = v;
                            if (!v) _default = false;
                          }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              Strings.priceTableItemsHint,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              label: Strings.search,
              prefixIcon: Icons.search_rounded,
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: ListView(
                children: [
                  for (final p in procedures)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.vcName, overflow: TextOverflow.ellipsis),
                                Text(
                                  Strings.priceTableToday(
                                    p.vlCurrentPrice == null
                                        ? '-'
                                        : Numbers.money(p.vlCurrentPrice),
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: AppNumberField(
                              label: Strings.priceTablePrice,
                              controller: _priceField(p.nrProcedure),
                              prefixText: 'R\$ ',
                              enabled: !_saving,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.save,
          expanded: false,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
