import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/pricing_controllers.dart';
import '../data/pricing_repository.dart';
import '../domain/pricing_calculator.dart';
import '../domain/pricing_models.dart';
import 'price_lookup_sheet.dart';

/// Novo material (material = null) ou edicao: embalagem, preco (manual ou
/// pela pesquisa de mercado), rendimento, perda. Devolve true quando salvou.
class MaterialFormDialog extends ConsumerStatefulWidget {
  const MaterialFormDialog({super.key, this.material, this.readOnly = false});

  final MaterialItem? material;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    MaterialItem? material,
    bool readOnly = false,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          MaterialFormDialog(material: material, readOnly: readOnly),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends ConsumerState<MaterialFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _m?.vcName ?? '');
  late final _package = TextEditingController(text: _m?.vcPackage ?? '');
  late final _price = TextEditingController(
    text: _m == null || !_m!.hasPrice
        ? ''
        : Numbers.toField(_m!.vlPackagePrice),
  );
  late final _yield = TextEditingController(
    text: Numbers.toField(_m?.qtYield ?? 1, decimals: 3),
  );
  late final _unit = TextEditingController(text: _m?.vcUnit ?? '');
  late final _waste = TextEditingController(text: Numbers.toField(_m?.pcWaste));
  late final _source = TextEditingController(text: _m?.vcPriceSource ?? '');
  late int _priceSource = _m?.itPriceSource ?? PriceSource.manual;
  late bool _active = _m?.isActive ?? true;
  bool _saving = false;

  MaterialItem? get _m => widget.material;
  bool get _isEdit => _m != null;
  bool get _canEdit => !widget.readOnly && !_saving;

  @override
  void dispose() {
    for (final c in [_name, _package, _price, _yield, _unit, _waste, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _unitCost => PricingCalculator.unitCost(
    Numbers.parse(_price.text) ?? 0,
    Numbers.parse(_yield.text) ?? 0,
    Numbers.parse(_waste.text) ?? 0,
  );

  Future<void> _lookup() async {
    final query = [
      _name.text.trim(),
      _package.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final offer = await PriceLookupSheet.show(context, query: query);
    if (offer == null || !mounted) return;
    setState(() {
      _price.text = Numbers.toField(offer.vlPrice);
      if (_package.text.trim().isEmpty && offer.vcPackage != null) {
        _package.text = offer.vcPackage!;
      }
      _priceSource = PriceSource.market;
      _source.text = [
        offer.vcStore,
        if (offer.vcUrl != null) offer.vcUrl!,
      ].join(' · ');
      if (_source.text.length > 200) {
        _source.text = _source.text.substring(0, 200);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final draft = MaterialDraft(
        vcName: _name.text.trim(),
        vcPackage: _package.text.trim().isEmpty ? null : _package.text.trim(),
        vlPackagePrice: Numbers.parse(_price.text) ?? 0,
        qtYield: Numbers.parse(_yield.text) ?? 1,
        vcUnit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        pcWaste: Numbers.parse(_waste.text) ?? 0,
        itPriceSource: _priceSource,
        vcPriceSource: _source.text.trim().isEmpty ? null : _source.text.trim(),
        itStatus: _isEdit ? (_active ? 1 : 90) : null,
      );
      final controller = ref.read(materialsProvider.notifier);
      if (_isEdit) {
        await controller.updateMaterial(_m!.nrMaterial, draft);
      } else {
        await controller.create(draft);
      }
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
    final title = widget.readOnly
        ? Strings.materialName
        : (_isEdit ? Strings.editMaterial : Strings.newMaterial);

    /// Dois campos lado a lado no desktop, empilhados no mobile.
    Widget pair(Widget a, Widget b) => isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: AppSpacing.md),
              b,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: b),
            ],
          );

    final pad = isMobile ? AppSpacing.md : AppSpacing.xl;
    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: Strings.materialName,
                        controller: _name,
                        maxLength: 80,
                        autofocus: !_isEdit,
                        enabled: _canEdit,
                        prefixIcon: Icons.inventory_2_outlined,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.required(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: Strings.package,
                        hint: Strings.packageHint,
                        controller: _package,
                        maxLength: 40,
                        enabled: _canEdit,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      pair(
                        AppNumberField(
                          label: Strings.packagePrice,
                          controller: _price,
                          prefixText: 'R\$ ',
                          enabled: _canEdit,
                          onChanged: (_) => setState(() {}),
                        ),
                        AppNumberField(
                          label: Strings.yieldLabel,
                          controller: _yield,
                          decimals: 3,
                          enabled: _canEdit,
                          required: true,
                          positive: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        Strings.yieldHelp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      pair(
                        AppTextField(
                          label: Strings.unit,
                          hint: Strings.unitHint,
                          controller: _unit,
                          maxLength: 20,
                          enabled: _canEdit,
                        ),
                        AppNumberField(
                          label: Strings.waste,
                          controller: _waste,
                          suffixText: '%',
                          helper: Strings.wasteHelp,
                          enabled: _canEdit,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = Numbers.parse(v) ?? 0;
                            return n >= 100 ? Strings.invalidNumber : null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calculate_outlined,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Text(Strings.unitCostPreview),
                            ),
                            Text(
                              '${Numbers.money(_unitCost, unit: true)}'
                              '${_unit.text.trim().isEmpty ? '' : ' / ${_unit.text.trim()}'}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        Strings.priceSource,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: PriceSource.manual,
                                label: Text(Strings.priceSourceManual),
                                icon: Icon(Icons.edit_note_rounded),
                              ),
                              ButtonSegment(
                                value: PriceSource.market,
                                label: Text(Strings.priceSourceMarket),
                                icon: Icon(Icons.travel_explore_rounded),
                              ),
                            ],
                            selected: {_priceSource},
                            onSelectionChanged: _canEdit
                                ? (s) => setState(() => _priceSource = s.first)
                                : null,
                          ),
                          AppButton(
                            label: Strings.lookupPrice,
                            icon: Icons.travel_explore_rounded,
                            variant: AppButtonVariant.secondary,
                            expanded: false,
                            onPressed: _canEdit ? _lookup : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: Strings.priceSourceText,
                        controller: _source,
                        maxLength: 200,
                        enabled: _canEdit,
                        prefixIcon: Icons.link_rounded,
                      ),
                      if (_isEdit) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(Strings.materialActive),
                          value: _active,
                          onChanged: _canEdit
                              ? (v) => setState(() => _active = v)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // rodape fixo: Salvar sempre visivel, sem rolar o formulario
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  AppSpacing.md,
                  pad,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: widget.readOnly ? Strings.close : Strings.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    if (!widget.readOnly) ...[
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
