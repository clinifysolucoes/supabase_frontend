import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_autocomplete_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/pricing_controllers.dart';
import '../data/pricing_repository.dart';
import '../domain/pricing_calculator.dart';
import '../domain/pricing_models.dart';
import 'factor_edit_dialog.dart';
import 'pricing_breakdown.dart';
import 'procedure_materials_dialog.dart';

/// Novo procedimento (procedure = null) ou edicao: dados, especialidade,
/// materiais x quantidade e a simulacao do preco ao vivo (PricingCalculator)
/// com a escolha PF / PJ e o alerta do valor cobrado hoje x custo. Cada fator
/// da simulacao e clicavel e pode ser alterado na hora (parametros da filial
/// ou valor so deste procedimento). [initialSpecialty] ja vem escolhida no
/// procedimento novo (botao dentro de uma especialidade). No procedimento
/// novo, o nome tem auto complete: catalogo da planilha da especialidade
/// (preenche tempo, material, laboratorio e valor cobrado) e procedimentos ja
/// cadastrados (copia os valores e os materiais).
/// Devolve true quando salvou.
class ProcedureFormDialog extends ConsumerStatefulWidget {
  const ProcedureFormDialog({
    super.key,
    this.procedure,
    required this.params,
    required this.summary,
    this.readOnly = false,
    this.initialSpecialty,
  });

  final Procedure? procedure;
  final PricingParams params;
  final PricingSummary summary;
  final bool readOnly;
  final int? initialSpecialty;

  static Future<bool> show(
    BuildContext context, {
    Procedure? procedure,
    required PricingParams params,
    required PricingSummary summary,
    bool readOnly = false,
    int? initialSpecialty,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProcedureFormDialog(
        procedure: procedure,
        params: params,
        summary: summary,
        readOnly: readOnly,
        initialSpecialty: initialSpecialty,
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<ProcedureFormDialog> createState() =>
      _ProcedureFormDialogState();
}

class _ProcedureFormDialogState extends ConsumerState<ProcedureFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: _p?.vcCode ?? '');
  late final _name = TextEditingController(text: _p?.vcName ?? '');
  late int? _nrSpecialty = _p?.nrSpecialty ?? widget.initialSpecialty;
  late final _minutes = TextEditingController(
    text: Numbers.toField(_p?.qtMinutes ?? 0, decimals: 0),
  );
  late final _lab = TextEditingController(text: Numbers.toField(_p?.vlLabCost));
  late final _other = TextEditingController(
    text: Numbers.toField(_p?.vlMaterialOther),
  );
  late final _current = TextEditingController(
    text: Numbers.toField(_p?.vlCurrentPrice),
  );
  late final _commission = TextEditingController(
    text: Numbers.toField(_p?.pcCommission),
  );
  late final _profit = TextEditingController(
    text: Numbers.toField(_p?.pcProfit),
  );
  late List<ProcedureMaterial> _materials = [...?_p?.materials];
  final Map<int, TextEditingController> _qty = {};
  late bool _active = _p?.isActive ?? true;

  /// Parametros da filial em vigor na simulacao (atualizados pela edicao inline).
  late PricingParams _params = widget.params;
  late PricingSummary _summary = widget.summary;
  late int _regime = widget.summary.itTaxRegime ?? widget.params.itTaxRegime;
  bool _saving = false;

  Procedure? get _p => widget.procedure;
  bool get _isEdit => _p != null;
  bool get _canEdit => !widget.readOnly && !_saving;

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
    for (final c in [
      _code,
      _name,
      _minutes,
      _lab,
      _other,
      _current,
      _commission,
      _profit,
      ..._qty.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => Numbers.parse(c.text) ?? 0;

  double? _numOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : Numbers.parse(c.text);

  double get _materialsCost => _materials.fold<double>(
    0,
    (s, m) => s + PricingCalculator.round2(m.qtUsed * m.vlUnitCost),
  );

  /// Lucro padrao: o da especialidade escolhida ou, sem ele, o da filial.
  double _defaultProfit(List<Specialty> specialties) {
    for (final s in specialties) {
      if (s.nrSpecialty == _nrSpecialty) return s.pcProfit ?? _params.pcProfit;
    }
    return _params.pcProfit;
  }

  PricingResult _result(double defaultProfit) => PricingCalculator.calculate(
    PricingInput(
      vlMaterial: _materialsCost + _num(_other),
      vlLab: _num(_lab),
      qtMinutes: _num(_minutes),
      vlStructureHour: _summary.vlStructureHour,
      vlProfessionalHour: _params.vlProfessionalHour,
      pcCard: _params.pcCard,
      pcCommission: _numOrNull(_commission) ?? _params.pcCommission,
      pcFees: _summary.pcFees,
      itTaxRegime: _regime,
      pcTax: _params.pcTaxFor(_regime),
      pcProfit: _numOrNull(_profit) ?? defaultProfit,
      vlCurrentPrice: _numOrNull(_current),
    ),
  );

  /// Lista nova vinda da janela de materiais (ver ou adicionar).
  void _replaceMaterials(List<ProcedureMaterial> list) {
    setState(() {
      for (final c in _qty.values) {
        c.dispose();
      }
      _qty.clear();
      _materials = [...list];
      for (final m in _materials) {
        _qty[m.nrMaterial] = TextEditingController(
          text: Numbers.toField(m.qtUsed, decimals: 3),
        );
      }
    });
  }

  Future<void> _openMaterials({required bool adding}) async {
    final list = await ProcedureMaterialsPicker.show(
      context,
      materials: _materials,
      title: _name.text.trim(),
      adding: adding,
      readOnly: !_canEdit,
    );
    if (list != null && mounted) _replaceMaterials(list);
  }

  /// Escolheu uma sugestao do auto complete: preenche o formulario.
  void _applySuggestion(ProcedureSuggestion s) {
    setState(() {
      if (s.isTemplate) {
        _name.text = s.vcName;
        if (s.vcCode != null) _code.text = s.vcCode!;
      } else {
        // copia de um cadastrado: o nome precisa ser outro
        _name.text = '${s.vcName} ${Strings.copySuffix}';
        _commission.text = Numbers.toField(s.pcCommission);
        _profit.text = Numbers.toField(s.pcProfit);
        for (final c in _qty.values) {
          c.dispose();
        }
        _qty.clear();
        _materials = [...s.materials];
        for (final m in _materials) {
          _qty[m.nrMaterial] = TextEditingController(
            text: Numbers.toField(m.qtUsed, decimals: 3),
          );
        }
      }
      _minutes.text = Numbers.toField(s.qtMinutes, decimals: 0);
      _other.text = Numbers.toField(s.vlMaterialOther);
      _lab.text = Numbers.toField(s.vlLabCost);
      _current.text = Numbers.toField(s.vlPrice);
    });
    AppSnack.info(
      context,
      s.isTemplate
          ? Strings.suggestionFilledFromSheet
          : Strings.suggestionCopied(s.vcName),
    );
  }

  /// Edicao inline de um fator: parametros da filial (salvos na hora) e, para
  /// comissao/lucro, o valor so deste procedimento (vai no Salvar).
  Future<void> _editFactor(PricingFactor factor) async {
    final override = switch (factor) {
      PricingFactor.commission => _numOrNull(_commission),
      PricingFactor.profit => _numOrNull(_profit),
      _ => null,
    };
    final result = await FactorEditDialog.show(
      context,
      factor: factor,
      overrideValue: override,
      withOverride: _canEdit && factor.hasOverride,
    );
    if (result == null || !mounted) return;
    setState(() {
      _params = result.data.params;
      _summary = result.data.summary;
      if (factor == PricingFactor.tax) _regime = _params.itTaxRegime;
      if (result.overrideChanged) {
        final c = factor == PricingFactor.commission ? _commission : _profit;
        c.text = Numbers.toField(result.overrideValue);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_materials.any((m) => m.qtUsed <= 0)) {
      AppSnack.error(context, Strings.mustBePositive);
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = ProcedureDraft(
        vcCode: _code.text.trim().isEmpty ? null : _code.text.trim(),
        vcName: _name.text.trim(),
        nrSpecialty: _nrSpecialty,
        qtMinutes: _num(_minutes),
        vlLabCost: _num(_lab),
        vlMaterialOther: _num(_other),
        vlCurrentPrice: _numOrNull(_current),
        pcCommission: _numOrNull(_commission),
        pcProfit: _numOrNull(_profit),
        itStatus: _isEdit ? (_active ? 1 : 90) : null,
        materials: _materials,
      );
      final controller = ref.read(proceduresProvider.notifier);
      if (_isEdit) {
        await controller.updateProcedure(_p!.nrProcedure, draft);
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

  String _suggestionSubtitle(ProcedureSuggestion s) => [
    s.isTemplate ? Strings.suggestionFromSheet : Strings.suggestionExisting,
    if (s.vcSpecialty != null && _nrSpecialty == null) s.vcSpecialty!,
    Numbers.minutes(s.qtMinutes),
    if (s.vlMaterialOther > 0)
      '${Strings.materialsCost} ${Numbers.money(s.vlMaterialOther)}',
    if (s.vlPrice != null) '${Strings.current} ${Numbers.money(s.vlPrice)}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final specialties =
        ref.watch(specialtyCatalogProvider).valueOrNull ?? const <Specialty>[];
    // especialidade inativa ligada ao procedimento continua visivel no combo
    final specialtyChoices = [
      const Choice<int>(value: null, label: Strings.noSpecialty),
      for (final s in specialties)
        Choice<int>(value: s.nrSpecialty, label: s.vcName),
      if (_p?.nrSpecialty != null &&
          !specialties.any((s) => s.nrSpecialty == _p!.nrSpecialty))
        Choice<int>(value: _p!.nrSpecialty, label: _p!.vcSpecialty ?? '-'),
    ];
    Specialty? selectedSpecialty;
    for (final s in specialties) {
      if (s.nrSpecialty == _nrSpecialty) selectedSpecialty = s;
    }
    final defaultProfit = _defaultProfit(specialties);
    final suggestions = _isEdit
        ? const ProcedureSuggestions()
        : ref.watch(procedureSuggestionsProvider(_nrSpecialty)).valueOrNull ??
              const ProcedureSuggestions();
    final canUpdateParams =
        ref.watch(canUpdateProvider(ScreenCodes.pricing)) ||
        (ref.watch(canCreateProvider(ScreenCodes.pricing)) && !_params.idSaved);
    final title = widget.readOnly
        ? Strings.viewProcedure
        : (_isEdit ? Strings.editProcedure : Strings.newProcedure);

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

    final form = Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isMobile ? 96 : 120,
                child: AppTextField(
                  label: Strings.procedureCode,
                  controller: _code,
                  maxLength: 10,
                  enabled: _canEdit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _isEdit
                    ? AppTextField(
                        label: Strings.procedureName,
                        controller: _name,
                        maxLength: 80,
                        enabled: _canEdit,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.required(),
                      )
                    : AppAutocompleteField<ProcedureSuggestion>(
                        label: Strings.procedureName,
                        hint: Strings.procedureNameSuggestHint,
                        controller: _name,
                        maxLength: 80,
                        autofocus: true,
                        enabled: _canEdit,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.required(),
                        suggestions: suggestions.search,
                        optionTitle: (s) => s.displayName,
                        optionSubtitle: _suggestionSubtitle,
                        optionIcon: (s) => s.isTemplate
                            ? Icons.table_view_rounded
                            : Icons.content_copy_rounded,
                        onSelected: _applySuggestion,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SearchableDropdown<Choice<int>>(
            label: Strings.specialty,
            items: specialtyChoices,
            value: specialtyChoices.firstWhere(
              (c) => c.value == _nrSpecialty,
              orElse: () => specialtyChoices.first,
            ),
            itemLabel: (c) => c.label,
            prefixIcon: Icons.category_outlined,
            enabled: _canEdit,
            onChanged: (c) => setState(() => _nrSpecialty = c.value),
          ),
          const SizedBox(height: AppSpacing.md),
          pair(
            AppNumberField(
              label: Strings.minutes,
              controller: _minutes,
              decimals: 0,
              suffixText: 'min',
              helper: Strings.minutesHelp,
              enabled: _canEdit,
              required: true,
              onChanged: (_) => setState(() {}),
            ),
            AppNumberField(
              label: Strings.labCost,
              controller: _lab,
              prefixText: 'R\$ ',
              enabled: _canEdit,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          pair(
            AppNumberField(
              label: Strings.materialOther,
              controller: _other,
              prefixText: 'R\$ ',
              helper: Strings.materialOtherHelp,
              enabled: _canEdit,
              onChanged: (_) => setState(() {}),
            ),
            AppNumberField(
              label: Strings.currentPrice,
              controller: _current,
              prefixText: 'R\$ ',
              helper: Strings.currentPriceHelp,
              enabled: _canEdit,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          pair(
            AppNumberField(
              label: Strings.commissionOverride,
              controller: _commission,
              suffixText: '%',
              helper: Strings.defaultValue(
                Numbers.percent(_params.pcCommission, decimals: 2),
              ),
              enabled: _canEdit,
              onChanged: (_) => setState(() {}),
            ),
            AppNumberField(
              label: Strings.profitOverride,
              controller: _profit,
              suffixText: '%',
              helper: selectedSpecialty?.pcProfit != null
                  ? Strings.defaultSpecialtyValue(
                      selectedSpecialty!.vcName,
                      Numbers.percent(defaultProfit, decimals: 2),
                    )
                  : Strings.defaultValue(
                      Numbers.percent(_params.pcProfit, decimals: 2),
                    ),
              enabled: _canEdit,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            Strings.materialsUsed,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _materials.isEmpty
                ? Strings.noMaterialsInProcedure
                : Strings.materialsSummary(
                    _materials.length,
                    Numbers.money(_materialsCost),
                  ),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: Strings.viewMaterials(_materials.length),
                icon: Icons.inventory_2_outlined,
                variant: AppButtonVariant.secondary,
                expanded: false,
                onPressed: () => _openMaterials(adding: false),
              ),
              if (_canEdit)
                AppButton(
                  label: Strings.addMaterials,
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.secondary,
                  expanded: false,
                  onPressed: () => _openMaterials(adding: true),
                ),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.procedureActive),
              value: _active,
              onChanged: _canEdit ? (v) => setState(() => _active = v) : null,
            ),
          ],
        ],
      ),
    );

    final result = _ResultPanel(
      result: _result(defaultProfit),
      regime: _regime,
      currentPrice: _numOrNull(_current),
      params: _params,
      summary: _summary,
      pcCommission: _numOrNull(_commission) ?? _params.pcCommission,
      pcProfit: _numOrNull(_profit) ?? defaultProfit,
      onRegime: (r) => setState(() => _regime = r),
      onEditFactor: canUpdateParams && !_saving ? _editFactor : null,
    );

    final pad = isMobile ? AppSpacing.md : AppSpacing.xl;
    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
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
                    if (isMobile) ...[
                      form,
                      const SizedBox(height: AppSpacing.lg),
                      result,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 2, child: result),
                        ],
                      ),
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
    );
  }
}

/// Linha de material: nome + custo unitario, quantidade e custo da linha.
/// No mobile (compact) fica em duas linhas.
class ProcedureMaterialRow extends StatelessWidget {
  const ProcedureMaterialRow({
    super.key,
    required this.material,
    required this.controller,
    required this.enabled,
    required this.compact,
    required this.onChanged,
    required this.onRemove,
  });

  final ProcedureMaterial material;
  final TextEditingController controller;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          m.vcName,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${Numbers.money(m.vlUnitCost, unit: true)} / ${m.vcUnit ?? Strings.unit.toLowerCase()}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final qty = AppNumberField(
      label: Strings.quantityUsed,
      controller: controller,
      decimals: 3,
      dense: true,
      enabled: enabled,
      onChanged: onChanged,
    );
    final cost = Text(
      Numbers.money(PricingCalculator.round2(m.qtUsed * m.vlUnitCost)),
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    final remove = IconButton(
      tooltip: Strings.remove,
      icon: const Icon(Icons.close_rounded, size: 20),
      onPressed: enabled ? onRemove : null,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: name),
                remove,
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                SizedBox(width: 140, child: qty),
                const Spacer(),
                cost,
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: name),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: 104, child: qty),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: 92, child: cost),
          remove,
        ],
      ),
    );
  }
}

/// Simulacao ao vivo com a escolha do regime e os fatores clicaveis.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.regime,
    required this.currentPrice,
    required this.params,
    required this.summary,
    required this.pcCommission,
    required this.pcProfit,
    required this.onRegime,
    this.onEditFactor,
  });

  final PricingResult result;
  final int regime;
  final double? currentPrice;
  final PricingParams params;
  final PricingSummary summary;
  final double pcCommission;
  final double pcProfit;
  final ValueChanged<int> onRegime;
  final ValueChanged<PricingFactor>? onEditFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Strings.simulation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: TaxRegime.pf,
                    label: Text(Strings.taxRegimePfShort),
                  ),
                  ButtonSegment(
                    value: TaxRegime.pj,
                    label: Text(Strings.taxRegimePjShort),
                  ),
                ],
                selected: {regime},
                onSelectionChanged: (s) => onRegime(s.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            regime == TaxRegime.pj
                ? Strings.taxRegimePjHelp
                : Strings.taxRegimePfHelp,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (onEditFactor != null)
            Text(
              Strings.factorsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Divider(height: AppSpacing.lg),
          PricingBreakdown(
            result: result,
            currentPrice: currentPrice,
            pcCard: params.pcCard,
            pcCommission: pcCommission,
            pcFees: summary.pcFees,
            pcTax: params.pcTaxFor(regime),
            pcProfit: pcProfit,
            onEditFactor: onEditFactor,
          ),
        ],
      ),
    );
  }
}
