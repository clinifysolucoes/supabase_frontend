import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/pricing_controllers.dart';
import '../domain/pricing_models.dart';
import 'material_form_dialog.dart';

final _date = DateFormat('dd/MM/yyyy');

/// Aba Materiais: catalogo com custo por unidade de uso, origem do preco
/// (manual ou pesquisa de mercado) e em quantos procedimentos e usado.
class MaterialsTab extends ConsumerStatefulWidget {
  const MaterialsTab({super.key});

  @override
  ConsumerState<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends ConsumerState<MaterialsTab>
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

  void _setFilters(MaterialFilters f) =>
      ref.read(materialFiltersProvider.notifier).state = f;

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _setFilters(ref.read(materialFiltersProvider).copyWith(search: value));
    });
  }

  Future<void> _openForm([MaterialItem? m]) async {
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.pricing));
    final saved = await MaterialFormDialog.show(
      context,
      material: m,
      readOnly: m != null && !canUpdate,
    );
    if (saved && mounted) AppSnack.success(context, Strings.savedSuccess);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filters = ref.watch(materialFiltersProvider);
    final async = ref.watch(materialsProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.pricing));
    final isMobile = context.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 280,
              child: AppTextField(
                label: Strings.search,
                hint: Strings.searchMaterialsHint,
                controller: _search,
                prefixIcon: Icons.search_rounded,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
            FilterChip(
              label: const Text(Strings.showInactive),
              selected: filters.includeInactive,
              onSelected: (v) =>
                  _setFilters(filters.copyWith(includeInactive: v)),
            ),
            if (canCreate)
              AppButton(
                label: Strings.newMaterial,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () => _openForm(),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(materialsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: Strings.noMaterials,
                );
              }
              return ResponsiveBuilder(
                mobile: (_) => _MaterialCards(items: items, onTap: _openForm),
                desktop: (_) => _MaterialTable(items: items, onTap: _openForm),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _yieldText(MaterialItem m) =>
    '${Numbers.qty(m.qtYield)} ${m.vcUnit ?? ''}'.trim();

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.material});

  final MaterialItem material;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final date = m.dhPriceUpdated == null
        ? null
        : _date.format(m.dhPriceUpdated!.toLocal());
    return Tooltip(
      message: m.vcPriceSource ?? '',
      child: AppTagChip(
        icon: m.isMarketPrice
            ? Icons.travel_explore_rounded
            : Icons.edit_note_rounded,
        highlighted: m.isMarketPrice,
        label: [
          m.isMarketPrice
              ? Strings.priceSourceMarket
              : Strings.priceSourceManual,
          if (date != null) date,
        ].join(' · '),
      ),
    );
  }
}

class _MaterialTable extends StatelessWidget {
  const _MaterialTable({required this.items, required this.onTap});

  final List<MaterialItem> items;
  final ValueChanged<MaterialItem> onTap;

  @override
  Widget build(BuildContext context) {
    return AppTable(
      minWidth: 960,
      columns: const [
        DataColumn(label: Text(Strings.materialName)),
        DataColumn(label: Text(Strings.packagePriceShort), numeric: true),
        DataColumn(label: Text(Strings.yieldShort), numeric: true),
        DataColumn(label: Text(Strings.waste), numeric: true),
        DataColumn(label: Text(Strings.unitCost), numeric: true),
        DataColumn(label: Text(Strings.priceSource)),
        DataColumn(label: Text(Strings.tabProcedures), numeric: true),
        DataColumn(label: Text(Strings.status)),
        DataColumn(label: Text(Strings.actions)),
      ],
      rows: [
        for (final m in items)
          DataRow(
            // a linha inteira abre o cadastro (o lapis pode ficar fora da tela)
            onSelectChanged: (_) => onTap(m),
            cells: [
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.vcName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (m.vcPackage != null)
                      Text(
                        m.vcPackage!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  m.hasPrice ? Numbers.money(m.vlPackagePrice) : '-',
                  style: TextStyle(
                    color: m.hasPrice ? AppColors.ink : AppColors.warning,
                    fontWeight: m.hasPrice ? null : FontWeight.w700,
                  ),
                ),
              ),
              DataCell(Text(_yieldText(m))),
              DataCell(Text(Numbers.percent(m.pcWaste))),
              DataCell(
                Text(
                  Numbers.money(m.vlUnitCost, unit: true),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              DataCell(_SourceChip(material: m)),
              DataCell(Text('${m.qtProcedures}')),
              DataCell(AppStatusChip(status: m.itStatus, compact: true)),
              DataCell(
                IconButton(
                  tooltip: Strings.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onTap(m),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MaterialCards extends StatelessWidget {
  const _MaterialCards({required this.items, required this.onTap});

  final List<MaterialItem> items;
  final ValueChanged<MaterialItem> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final m = items[index];
        return Card(
          child: ListTile(
            onTap: () => onTap(m),
            title: Text(
              m.vcName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (m.vcPackage != null) m.vcPackage!,
                      m.hasPrice ? Numbers.money(m.vlPackagePrice) : '-',
                      _yieldText(m),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _SourceChip(material: m),
                      AppTagChip(label: Strings.usedIn(m.qtProcedures)),
                      if (!m.isActive)
                        AppStatusChip(status: m.itStatus, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Text(
              Numbers.money(m.vlUnitCost, unit: true),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        );
      },
    );
  }
}
