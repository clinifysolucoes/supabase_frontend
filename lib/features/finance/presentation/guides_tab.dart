import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/health_models.dart';
import 'finance_widgets.dart';

/// Guias de convenio do mes: lancar, faturar (varias de uma vez), registrar o
/// pagamento com glosa, desfazer e cancelar.
class GuidesTab extends ConsumerStatefulWidget {
  const GuidesTab({super.key});

  @override
  ConsumerState<GuidesTab> createState() => _GuidesTabState();
}

class _GuidesTabState extends ConsumerState<GuidesTab> {
  final _selected = <int>{};

  Future<void> _run(
    String action,
    List<int> guides, [
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      await ref.read(financeActionsProvider).cash('health_guide_settle', {
        'vc_action': action,
        'nr_guides': guides,
        ...extra,
      });
      if (mounted) {
        setState(() => _selected.clear());
        AppSnack.success(context, Strings.guideDone);
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _open(PlanCatalog catalog, [HealthGuide? g]) async {
    final saved = await GuideFormDialog.show(
      context,
      catalog: catalog,
      guide: g,
    );
    if (saved && mounted) AppSnack.success(context, Strings.savedSuccess);
  }

  Future<void> _pay(HealthGuide g) async {
    final extra = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PayGuideDialog(guide: g),
    );
    if (extra != null) await _run('PAY', [g.nrGuide], extra);
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(guidesMonthProvider);
    final filter = ref.watch(guidesFilterProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));
    final catalog = ref.watch(healthPlansProvider).valueOrNull;
    final async = ref.watch(guidesProvider);
    const labels = {
      GuideFilter.all: Strings.guideFilterAll,
      GuideFilter.open: Strings.guideFilterOpen,
      GuideFilter.invoiced: Strings.guideFilterInvoiced,
      GuideFilter.paid: Strings.guideFilterPaid,
      GuideFilter.cancelled: Strings.guideFilterCancelled,
    };
    final hasPlans = (catalog?.activePlans ?? const []).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonthSwitcher(
              month: month,
              onChanged: (m) {
                _selected.clear();
                ref.read(guidesMonthProvider.notifier).state = m;
              },
            ),
            for (final f in GuideFilter.values)
              ChoiceChip(
                label: Text(labels[f]!),
                selected: filter == f,
                onSelected: (_) {
                  _selected.clear();
                  ref.read(guidesFilterProvider.notifier).state = f;
                },
              ),
            if (canCreate && catalog != null && hasPlans)
              AppButton(
                label: Strings.guideNew,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () => _open(catalog),
              ),
            if (canUpdate && _selected.isNotEmpty)
              AppButton(
                label: Strings.guideInvoiceSelected(_selected.length),
                icon: Icons.send_rounded,
                variant: AppButtonVariant.secondary,
                expanded: false,
                onPressed: () => _run('INVOICE', _selected.toList()),
              ),
          ],
        ),
        if (catalog != null && !hasPlans)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              Strings.guideNoPlans,
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(guidesProvider),
            ),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    FinKpiCard(label: Strings.guideTotalsOpen, value: d.vlOpen),
                    FinKpiCard(
                      label: Strings.guideTotalsInvoiced,
                      value: d.vlInvoiced,
                      color: AppColors.warning,
                    ),
                    FinKpiCard(
                      label: Strings.guideTotalsPaid,
                      value: d.vlPaid,
                      color: AppColors.success,
                    ),
                    FinKpiCard(
                      label: Strings.guideTotalsDenied,
                      value: d.vlDenied,
                      color: AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: d.guides.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.assignment_outlined,
                          title: Strings.guideNone,
                        )
                      : ListView.separated(
                          itemCount: d.guides.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final g = d.guides[i];
                            return _GuideCard(
                              guide: g,
                              selected: _selected.contains(g.nrGuide),
                              onSelect: canUpdate && g.isOpen
                                  ? (v) => setState(
                                      () => v
                                          ? _selected.add(g.nrGuide)
                                          : _selected.remove(g.nrGuide),
                                    )
                                  : null,
                              actions: [
                                if (g.isOpen && canUpdate && catalog != null)
                                  TextButton(
                                    onPressed: () => _open(catalog, g),
                                    child: const Text(Strings.edit),
                                  ),
                                if (g.isOpen && canUpdate)
                                  TextButton(
                                    onPressed: () =>
                                        _run('INVOICE', [g.nrGuide]),
                                    child: const Text(Strings.guideInvoice),
                                  ),
                                if (g.isOpen && canUpdate)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                    ),
                                    onPressed: () async {
                                      if (await AppConfirmDialog.show(
                                        context,
                                        title: Strings.guideCancel,
                                        message: Strings.guideCancelConfirm,
                                      )) {
                                        await _run('CANCEL', [g.nrGuide]);
                                      }
                                    },
                                    child: const Text(Strings.guideCancel),
                                  ),
                                if (g.isInvoiced && canUpdate) ...[
                                  TextButton(
                                    onPressed: () =>
                                        _run('UNINVOICE', [g.nrGuide]),
                                    child: const Text(Strings.guideUninvoice),
                                  ),
                                  FilledButton(
                                    onPressed: () => _pay(g),
                                    child: const Text(Strings.guidePay),
                                  ),
                                ],
                                if (g.isPaid && canUpdate)
                                  TextButton(
                                    onPressed: () => _run('UNPAY', [g.nrGuide]),
                                    child: const Text(Strings.guideUnpay),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.guide,
    required this.selected,
    required this.onSelect,
    required this.actions,
  });

  final HealthGuide guide;
  final bool selected;
  final ValueChanged<bool>? onSelect;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final g = guide;
    final color = switch (g.itStatus) {
      GuideStatus.paid => AppColors.success,
      GuideStatus.invoiced => AppColors.warning,
      GuideStatus.cancelled => AppColors.muted,
      _ => AppColors.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onSelect != null)
                  Checkbox(
                    value: selected,
                    onChanged: (v) => onSelect!(v ?? false),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${g.vcPatient} · ${g.vcPlan}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          Dates.format(g.dtService),
                          if (g.vcGuideNumber != null)
                            '${Strings.guideNumber} ${g.vcGuideNumber}',
                          ?g.vcProfessional,
                          if (g.dtDue != null && g.isInvoiced)
                            Strings.guideDue(Dates.format(g.dtDue)),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        g.items
                            .map(
                              (i) =>
                                  '${i.qtQuantity}× ${i.vcProcedure}'
                                  '${i.vcTooth == null ? '' : ' (${i.vcTooth})'}',
                            )
                            .join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Numbers.money(g.vlTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      GuideStatus.label(g.itStatus),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (g.isPaid && (g.vlDenied ?? 0) > 0)
                      Text(
                        '${Strings.guideDenied} ${Numbers.money(g.vlDenied)}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: AppSpacing.xs, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}

class _PayGuideDialog extends StatefulWidget {
  const _PayGuideDialog({required this.guide});

  final HealthGuide guide;

  @override
  State<_PayGuideDialog> createState() => _PayGuideDialogState();
}

class _PayGuideDialogState extends State<_PayGuideDialog> {
  final _date = TextEditingController(text: Dates.toField(DateTime.now()));
  late final _denied = [
    for (final _ in widget.guide.items) TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _denied) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _date.dispose();
    for (final c in _denied) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    var denied = 0.0;
    for (var i = 0; i < g.items.length; i++) {
      denied += (Numbers.parse(_denied[i].text) ?? 0).clamp(
        0,
        g.items[i].vlTotal,
      );
    }
    final paid = g.vlTotal - denied;
    final dt = Dates.parseField(_date.text);
    return AlertDialog(
      title: const Text(Strings.guidePayTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${g.vcPatient} · ${g.vcPlan} · ${Numbers.money(g.vlTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                Strings.guidePayHint,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.finPaidOn,
                controller: _date,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < g.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${g.items[i].qtQuantity}× ${g.items[i].vcProcedure}'
                          ' · ${Numbers.money(g.items[i].vlTotal)}',
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: AppNumberField(
                          label: Strings.guideDenied,
                          controller: _denied[i],
                          prefixText: 'R\$ ',
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Text(
                '${Strings.guidePaidValue}: ${Numbers.money(paid)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: dt == null
              ? null
              : () => Navigator.of(context).pop({
                  'dt_paid': Dates.toIso(dt),
                  'denials': [
                    for (var i = 0; i < g.items.length; i++)
                      if ((Numbers.parse(_denied[i].text) ?? 0) > 0)
                        {
                          'nr_item': g.items[i].nrItem,
                          'vl_denied': Numbers.parse(_denied[i].text),
                        },
                  ],
                }),
          child: const Text(Strings.confirm),
        ),
      ],
    );
  }
}

class _ItemRow {
  _ItemRow(this.nrProcedure, {double? unit, int qty = 1, String? tooth})
    : unit = TextEditingController(text: Numbers.toField(unit)),
      qty = TextEditingController(text: '$qty'),
      tooth = TextEditingController(text: tooth ?? '');

  final int nrProcedure;
  final TextEditingController unit;
  final TextEditingController qty;
  final TextEditingController tooth;

  void dispose() {
    unit.dispose();
    qty.dispose();
    tooth.dispose();
  }
}

/// Cadastro / alteracao de guia aberta. Devolve true quando salvou.
class GuideFormDialog extends ConsumerStatefulWidget {
  const GuideFormDialog({super.key, required this.catalog, this.guide});

  final PlanCatalog catalog;
  final HealthGuide? guide;

  static Future<bool> show(
    BuildContext context, {
    required PlanCatalog catalog,
    HealthGuide? guide,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GuideFormDialog(catalog: catalog, guide: guide),
      ) ??
      false;

  @override
  ConsumerState<GuideFormDialog> createState() => _GuideFormDialogState();
}

class _GuideFormDialogState extends ConsumerState<GuideFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int? _plan =
      widget.guide?.nrPlan ??
      (widget.catalog.activePlans.isEmpty
          ? null
          : widget.catalog.activePlans.first.nrPlan);
  late int? _patient = widget.guide?.nrPatient;
  late String? _patientName = widget.guide?.vcPatient;
  late int? _professional = widget.guide?.nrProfessional;
  late final _number = TextEditingController(
    text: widget.guide?.vcGuideNumber ?? '',
  );
  late final _card = TextEditingController(
    text: widget.guide?.vcCardNumber ?? '',
  );
  late final _date = TextEditingController(
    text: Dates.toField(widget.guide?.dtService ?? DateTime.now()),
  );
  late final List<_ItemRow> _items = [
    for (final i in widget.guide?.items ?? const <GuideItem>[])
      _ItemRow(
        i.nrProcedure,
        unit: i.vlUnit,
        qty: i.qtQuantity,
        tooth: i.vcTooth,
      ),
  ];
  bool _saving = false;

  HealthPlan? get _planObj {
    for (final p in widget.catalog.plans) {
      if (p.nrPlan == _plan) return p;
    }
    return null;
  }

  String _procName(int nr) {
    for (final p in widget.catalog.procedures) {
      if (p.nr == nr) return p.name;
    }
    return '#$nr';
  }

  @override
  void dispose() {
    _number.dispose();
    _card.dispose();
    _date.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_patient == null) {
      AppSnack.error(context, Strings.choosePatient);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(financeActionsProvider).cash('health_guide_save', {
        'vc_action': widget.guide == null ? 'I' : 'U',
        'nr_guide': ?widget.guide?.nrGuide,
        'nr_plan': _plan,
        'nr_patient': _patient,
        'nr_professional': _professional,
        'vc_guide_number': _number.text.trim(),
        'vc_card_number': _card.text.trim(),
        'dt_service': Dates.toIso(Dates.parseField(_date.text)!),
        'items': [
          for (final r in _items)
            {
              'nr_procedure': r.nrProcedure,
              'qt_quantity': int.tryParse(r.qty.text) ?? 1,
              'vl_unit': Numbers.parse(r.unit.text),
              'vc_tooth': r.tooth.text.trim(),
            },
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final pad = isMobile ? AppSpacing.md : AppSpacing.lg;
    final plan = _planObj;
    var total = 0.0;
    for (final r in _items) {
      total +=
          (Numbers.parse(r.unit.text) ?? 0) * (int.tryParse(r.qty.text) ?? 0);
    }
    final fields = <Widget>[
      Text(
        Strings.guideTitle,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<int?>(
        isExpanded: true,
        initialValue: _plan,
        decoration: const InputDecoration(labelText: '${Strings.guidePlan} *'),
        items: [
          for (final p in widget.catalog.plans)
            if (p.isActive || p.nrPlan == _plan)
              DropdownMenuItem(value: p.nrPlan, child: Text(p.vcName)),
        ],
        validator: (v) => v == null ? Strings.required : null,
        onChanged: _saving ? null : (v) => setState(() => _plan = v),
      ),
      const SizedBox(height: AppSpacing.md),
      InputDecorator(
        decoration: const InputDecoration(labelText: '${Strings.finPatient} *'),
        child: InkWell(
          onTap: _saving
              ? null
              : () async {
                  final p = await PatientPickerDialog.show(context);
                  if (p != null) {
                    setState(() {
                      _patient = p.nrPatient;
                      _patientName = p.vcName;
                    });
                  }
                },
          child: Text(
            _patientName ?? Strings.finChoosePatient,
            style: TextStyle(
              color: _patientName == null ? AppColors.muted : null,
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              label: '${Strings.guideDate} *',
              controller: _date,
              mask: MaskType.date,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  Dates.parseField(v) == null ? Strings.invalidDate : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _professional,
              decoration: const InputDecoration(
                labelText: Strings.professional,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final p in widget.catalog.professionals)
                  DropdownMenuItem(value: p.nr, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _professional = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              label: Strings.guideNumber,
              controller: _number,
              maxLength: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppTextField(
              label: Strings.guideCard,
              controller: _card,
              maxLength: 30,
            ),
          ),
        ],
      ),
      Row(
        children: [
          const Expanded(
            child: Text(
              Strings.guideItems,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 260,
            child: SearchableDropdown<({int nr, String name})>(
              label: Strings.guideAddItem,
              items: widget.catalog.procedures,
              itemLabel: (p) => p.name,
              itemSubtitle: (p) {
                final v = plan?.priceOf(p.nr);
                return v == null ? null : Numbers.money(v);
              },
              prefixIcon: Icons.add_rounded,
              onChanged: (p) => setState(
                () => _items.add(_ItemRow(p.nr, unit: plan?.priceOf(p.nr))),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final r in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _procName(r.nrProcedure),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 90,
                child: AppTextField(
                  label: Strings.guideTooth,
                  controller: r.tooth,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 70,
                child: AppNumberField(
                  label: Strings.guideQty,
                  controller: r.qty,
                  decimals: 0,
                  required: true,
                  positive: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 130,
                child: AppNumberField(
                  label: Strings.guideUnit,
                  controller: r.unit,
                  prefixText: 'R\$ ',
                  required: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: Strings.remove,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _items.remove(r);
                  r.dispose();
                }),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '${Strings.guideTotal}: ${Numbers.money(total)}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                    children: fields,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: Strings.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: Strings.save,
                        loading: _saving,
                        onPressed: _items.isEmpty ? null : _save,
                      ),
                    ),
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
