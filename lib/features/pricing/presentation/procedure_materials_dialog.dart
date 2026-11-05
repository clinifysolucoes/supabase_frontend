import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/pricing_controllers.dart';
import '../domain/pricing_calculator.dart';
import '../domain/pricing_models.dart';
import 'procedure_form_dialog.dart';

/// Materiais de um procedimento: lista com quantidade e custo e, para quem
/// pode alterar, o botao que libera a edicao (adicionar, mudar quantidade,
/// remover). Salva so os materiais (o resto do cadastro nao muda).
class ProcedureMaterialsDialog extends ConsumerStatefulWidget {
  const ProcedureMaterialsDialog({super.key, required this.procedure});

  final Procedure procedure;

  static Future<void> show(BuildContext context, Procedure procedure) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProcedureMaterialsDialog(procedure: procedure),
    );
    if ((saved ?? false) && context.mounted) {
      AppSnack.success(context, Strings.materialsSaved);
    }
  }

  @override
  ConsumerState<ProcedureMaterialsDialog> createState() =>
      _ProcedureMaterialsDialogState();
}

class _ProcedureMaterialsDialogState
    extends ConsumerState<ProcedureMaterialsDialog> {
  late List<ProcedureMaterial> _materials = [...widget.procedure.materials];
  final Map<int, TextEditingController> _qty = {};
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final m in _materials) {
      _qty[m.nrMaterial] = TextEditingController(
        text: Numbers.toField(m.qtUsed, decimals: 3),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _materials.fold<double>(
    0,
    (s, m) => s + PricingCalculator.round2(m.qtUsed * m.vlUnitCost),
  );

  void _add(MaterialItem m) {
    if (_materials.any((x) => x.nrMaterial == m.nrMaterial)) return;
    setState(() {
      _materials = [..._materials, ProcedureMaterial.fromMaterial(m, 1)];
      _qty[m.nrMaterial] = TextEditingController(text: '1');
    });
  }

  void _setQty(int nrMaterial, String text) {
    final qty = Numbers.parse(text) ?? 0;
    setState(() {
      _materials = [
        for (final m in _materials)
          if (m.nrMaterial == nrMaterial) m.copyWith(qtUsed: qty) else m,
      ];
    });
  }

  void _remove(int nrMaterial) {
    setState(() {
      _materials = _materials.where((m) => m.nrMaterial != nrMaterial).toList();
      _qty.remove(nrMaterial)?.dispose();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_materials.any((m) => m.qtUsed <= 0)) {
      AppSnack.error(context, Strings.mustBePositive);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(proceduresProvider.notifier)
          .updateMaterials(widget.procedure.nrProcedure, _materials);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final p = widget.procedure;
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.pricing));
    final catalog = _editing
        ? ref.watch(materialCatalogProvider).valueOrNull ?? const []
        : const <MaterialItem>[];
    final available = [
      for (final m in catalog)
        if (!_materials.any((x) => x.nrMaterial == m.nrMaterial)) m,
    ];

    Widget totalLine(String label, double value, {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: bold ? null : AppColors.muted,
                    fontWeight: bold ? FontWeight.w800 : null,
                  ),
                ),
              ),
              Text(
                Numbers.money(value),
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.materialsUsed,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                p.displayName,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_materials.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    Strings.noMaterialsInProcedure,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _materials.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        if (_editing)
                          ProcedureMaterialRow(
                            material: _materials[i],
                            controller: _qty[_materials[i].nrMaterial]!,
                            enabled: !_saving,
                            compact: isMobile,
                            onChanged: (v) =>
                                _setQty(_materials[i].nrMaterial, v),
                            onRemove: () => _remove(_materials[i].nrMaterial),
                          )
                        else
                          _ReadRow(material: _materials[i]),
                      ],
                    ],
                  ),
                ),
              if (canUpdate && !_editing) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: Strings.editMaterials,
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => setState(() => _editing = true),
                ),
              ],
              if (_editing) ...[
                const SizedBox(height: AppSpacing.sm),
                SearchableDropdown<MaterialItem>(
                  label: Strings.addMaterial,
                  items: available,
                  itemLabel: (m) => m.vcName,
                  itemSubtitle: (m) =>
                      '${m.vcPackage ?? ''} · ${Numbers.money(m.vlUnitCost, unit: true)}/${m.vcUnit ?? Strings.unit.toLowerCase()}',
                  prefixIcon: Icons.add_rounded,
                  enabled: !_saving,
                  onChanged: _add,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              totalLine(Strings.materialsTotal, _total),
              if (p.vlMaterialOther > 0)
                totalLine(Strings.otherMaterials, p.vlMaterialOther),
              if (p.vlMaterialOther > 0)
                totalLine(
                  Strings.materialsGrandTotal,
                  _total + p.vlMaterialOther,
                  bold: true,
                ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _editing ? Strings.cancel : Strings.close,
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: Strings.save,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha so de leitura: nome, custo por unidade, quantidade e custo da linha.
class _ReadRow extends StatelessWidget {
  const _ReadRow({required this.material});

  final ProcedureMaterial material;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final unit = m.vcUnit ?? Strings.unit.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.vcName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Numbers.toField(m.qtUsed, decimals: 3)} $unit × ${Numbers.money(m.vlUnitCost, unit: true)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Numbers.money(PricingCalculator.round2(m.qtUsed * m.vlUnitCost)),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
