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
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../../finance/domain/finance_models.dart';
import '../../pricing/application/pricing_controllers.dart';
import '../../pricing/domain/pricing_models.dart';
import '../application/budget_controllers.dart';
import '../domain/budget_models.dart';

/// Novo orcamento ou edicao (em aberto / aguardando). Devolve o nr_budget.
class BudgetFormDialog extends ConsumerStatefulWidget {
  const BudgetFormDialog({
    super.key,
    this.budget,
    this.nrPatient,
    this.vcPatient,
    this.pcMaxDiscount = 10,
  });

  final Budget? budget;
  final int? nrPatient;
  final String? vcPatient;
  final double pcMaxDiscount;

  static Future<int?> show(
    BuildContext context, {
    Budget? budget,
    int? nrPatient,
    String? vcPatient,
    double pcMaxDiscount = 10,
  }) => showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BudgetFormDialog(
      budget: budget,
      nrPatient: nrPatient,
      vcPatient: vcPatient,
      pcMaxDiscount: pcMaxDiscount,
    ),
  );

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int? _nrPatient = widget.budget?.nrPatient ?? widget.nrPatient;
  late String? _vcPatient = widget.budget?.vcPatient ?? widget.vcPatient;
  late int? _nrProfessional = widget.budget?.nrProfessional;
  late final _title = TextEditingController(text: widget.budget?.vcTitle ?? '');
  late final _date = TextEditingController(
    text: Dates.toField(widget.budget?.dtBudget ?? DateTime.now()),
  );
  late final _valid = TextEditingController(
    text: widget.budget == null ? '' : Dates.toField(widget.budget!.dtValid),
  );
  late final _discount = TextEditingController(
    text: widget.budget == null || widget.budget!.vlDiscount == 0
        ? ''
        : Numbers.toField(widget.budget!.vlDiscount),
  );
  late final _installments = TextEditingController(
    text: '${widget.budget?.qtInstallments ?? 1}',
  );
  late final _notes = TextEditingController(text: widget.budget?.vcNotes ?? '');
  late int? _method = widget.budget?.itPaymentMethod;
  bool _percent = false;
  late final List<BudgetItem> _items = [...?widget.budget?.items];
  late final List<Key> _keys = [for (final _ in _items) UniqueKey()];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _date, _valid, _discount, _installments, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _gross => _items.fold(0, (s, i) => s + i.vlTotal);
  double get _discountValue {
    final v = Numbers.parse(_discount.text) ?? 0;
    return _percent ? (_gross * v / 100 * 100).roundToDouble() / 100 : v;
  }

  double get _discountPercent =>
      _gross == 0 ? 0 : _discountValue / _gross * 100;

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null) {
      setState(() {
        _nrPatient = p.nrPatient;
        _vcPatient = p.vcName;
      });
    }
  }

  Future<void> _addProcedure(List<Procedure> procedures) async {
    final p = await showDialog<Procedure>(
      context: context,
      builder: (ctx) => _ProcedurePicker(procedures: procedures),
    );
    if (p == null) return;
    setState(() {
      _items.add(
        BudgetItem(
          nrProcedure: p.nrProcedure,
          vcDescription: p.vcName,
          vlUnit: p.vlCurrentPrice ?? p.pricing?.vlPrice ?? 0,
        ),
      );
      _keys.add(UniqueKey());
    });
  }

  void _addFree() => setState(() {
    _items.add(const BudgetItem(vcDescription: Strings.budgetFreeItem));
    _keys.add(UniqueKey());
  });

  Future<void> _save() async {
    if (_nrPatient == null) {
      AppSnack.error(context, Strings.budgetPatientRequired);
      return;
    }
    if (_items.isEmpty) {
      AppSnack.error(context, Strings.budgetItemsRequired);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final valid = Dates.parseField(_valid.text);
    final fields = <String, dynamic>{
      'nr_patient': _nrPatient,
      'nr_professional': _nrProfessional,
      'vc_title': _title.text.trim(),
      'dt_budget': Dates.toIso(Dates.parseField(_date.text) ?? DateTime.now()),
      if (valid != null) 'dt_valid': Dates.toIso(valid),
      'vl_discount': _discountValue,
      'qt_installments': int.tryParse(_installments.text.trim()) ?? 1,
      'it_payment_method': _method,
      'vc_notes': _notes.text.trim(),
      'items': [for (final i in _items) i.toJson()],
    };
    try {
      final b = await ref
          .read(budgetActionsProvider)
          .save(widget.budget?.nrBudget, fields);
      if (!mounted) return;
      if (b.itStatus == BudgetStatus.pending) {
        AppSnack.info(context, Strings.budgetPendingInfo);
      } else {
        AppSnack.success(context, Strings.budgetSaved);
      }
      Navigator.of(context).pop(b.nrBudget);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final procedures = ref
        .watch(proceduresProvider)
        .valueOrNull
        ?.procedures
        .where((p) => p.isActive)
        .toList();
    final professionals = ref.watch(agendaProfessionalsProvider).valueOrNull;
    final over = _discountPercent > widget.pcMaxDiscount + 0.005;
    Widget pair(Widget a, Widget b) => mobile
        ? Column(
            children: [
              a,
              const SizedBox(height: AppSpacing.sm),
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
    String? date(String? v) =>
        (v ?? '').trim().isEmpty || Dates.parseField(v) != null
        ? null
        : Strings.invalidDate;

    return Dialog(
      insetPadding: EdgeInsets.all(mobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  widget.budget == null
                      ? Strings.budgetNew
                      : Strings.budgetEdit(widget.budget!.nrBudget),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      pair(
                        InkWell(
                          onTap: widget.budget == null ? _pickPatient : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '${Strings.patient} *',
                              prefixIcon: Icon(Icons.person_search_outlined),
                            ),
                            child: Text(
                              _vcPatient ?? Strings.budgetChoosePatient,
                            ),
                          ),
                        ),
                        SearchableDropdown<Choice<int>>(
                          label: Strings.professional,
                          items: [
                            const Choice<int>(
                              value: null,
                              label: Strings.notInformed,
                            ),
                            for (final p in professionals ?? const [])
                              Choice<int>(
                                value: p.nrProfessional,
                                label: p.vcName,
                              ),
                          ],
                          value: Choice<int>(
                            value: _nrProfessional,
                            label:
                                professionals
                                    ?.where(
                                      (p) =>
                                          p.nrProfessional == _nrProfessional,
                                    )
                                    .firstOrNull
                                    ?.vcName ??
                                (widget.budget?.vcProfessional ??
                                    Strings.notInformed),
                          ),
                          itemLabel: (c) => c.label,
                          onChanged: (c) =>
                              setState(() => _nrProfessional = c.value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: Strings.budgetTitle,
                        hint: Strings.budgetTitleHint,
                        controller: _title,
                        maxLength: 80,
                      ),
                      pair(
                        AppTextField(
                          label: Strings.budgetDate,
                          controller: _date,
                          mask: MaskType.date,
                          keyboardType: TextInputType.number,
                          validator: date,
                        ),
                        AppTextField(
                          label: Strings.budgetValid,
                          hint: Strings.budgetValidHint,
                          controller: _valid,
                          mask: MaskType.date,
                          keyboardType: TextInputType.number,
                          validator: date,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              Strings.budgetItems,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: procedures == null
                                ? null
                                : () => _addProcedure(procedures),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(Strings.budgetAddProcedure),
                          ),
                          TextButton(
                            onPressed: _addFree,
                            child: const Text(Strings.budgetAddFree),
                          ),
                        ],
                      ),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Text(
                            Strings.budgetNoItems,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      for (var i = 0; i < _items.length; i++)
                        _ItemRow(
                          key: _keys[i],
                          item: _items[i],
                          onChanged: (it) => setState(() => _items[i] = it),
                          onRemove: () => setState(() {
                            _items.removeAt(i);
                            _keys.removeAt(i);
                          }),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      pair(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppNumberField(
                                label: Strings.budgetDiscount,
                                controller: _discount,
                                prefixText: _percent ? null : 'R\$ ',
                                suffixText: _percent ? '%' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('R\$')),
                                ButtonSegment(value: true, label: Text('%')),
                              ],
                              selected: {_percent},
                              onSelectionChanged: (s) => setState(() {
                                _percent = s.first;
                                _discount.clear();
                              }),
                            ),
                          ],
                        ),
                        pair(
                          AppNumberField(
                            label: Strings.budgetInstallments,
                            controller: _installments,
                            decimals: 0,
                            validator: (v) {
                              final n = int.tryParse(v ?? '') ?? 0;
                              return n < 1 || n > 24 ? '1 – 24' : null;
                            },
                          ),
                          DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _method,
                            decoration: const InputDecoration(
                              labelText: Strings.finPaymentMethod,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('-'),
                              ),
                              for (final m in PaymentMethod.all)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(PaymentMethod.label(m)),
                                ),
                            ],
                            onChanged: (v) => setState(() => _method = v),
                          ),
                        ),
                      ),
                      if (over)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            Strings.budgetOverMax(
                              Numbers.percent(widget.pcMaxDiscount),
                            ),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: Strings.notes,
                        controller: _notes,
                        maxLength: 1000,
                        maxLines: 3,
                        minLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      '${Strings.budgetSubtotal}: ${Numbers.money(_gross)}'
                      '${_discountValue > 0 ? '  ·  ${Strings.budgetDiscount}: ${Numbers.money(_discountValue)} (${Numbers.percent(_discountPercent)})' : ''}'
                      '  ·  ${Strings.budgetTotal}: ${Numbers.money(_gross - _discountValue)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(Strings.cancel),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: Strings.save,
                          expanded: false,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ],
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

class _ItemRow extends StatefulWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final BudgetItem item;
  final ValueChanged<BudgetItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final _desc = TextEditingController(text: widget.item.vcDescription);
  late final _tooth = TextEditingController(text: widget.item.vcTooth ?? '');
  late final _qty = TextEditingController(
    text: Numbers.qty(widget.item.qtQuantity),
  );
  late final _unit = TextEditingController(
    text: Numbers.toField(widget.item.vlUnit),
  );
  BudgetItem _current() => widget.item.copyWith(
    vcDescription: _desc.text.trim(),
    vcTooth: _tooth.text.trim(),
    qtQuantity: Numbers.parse(_qty.text) ?? 1,
    vlUnit: Numbers.parse(_unit.text) ?? 0,
  );

  @override
  void dispose() {
    for (final c in [_desc, _tooth, _qty, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void changed(_) => widget.onChanged(_current());
    final mobile = context.isMobile;
    final fields = [
      Expanded(
        flex: 4,
        child: AppTextField(
          label: Strings.budgetItemDescription,
          controller: _desc,
          maxLength: 120,
          onChanged: changed,
          validator: (v) => (v ?? '').trim().isEmpty ? Strings.required : null,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        flex: 2,
        child: AppTextField(
          label: Strings.budgetTooth,
          controller: _tooth,
          maxLength: 40,
          onChanged: changed,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: AppNumberField(
          label: Strings.budgetQty,
          controller: _qty,
          onChanged: changed,
          positive: true,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        flex: 2,
        child: AppNumberField(
          label: Strings.budgetUnit,
          controller: _unit,
          prefixText: 'R\$ ',
          onChanged: changed,
        ),
      ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, 0, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mobile)
              Expanded(
                child: Column(
                  children: [
                    Row(children: fields.sublist(0, 3)),
                    Row(children: fields.sublist(4)),
                  ],
                ),
              )
            else
              ...fields,
            SizedBox(
              width: 96,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  Numbers.money(widget.item.vlTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: Strings.remove,
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Busca de procedimento da precificacao (nome, codigo ou especialidade).
class _ProcedurePicker extends StatefulWidget {
  const _ProcedurePicker({required this.procedures});

  final List<Procedure> procedures;

  @override
  State<_ProcedurePicker> createState() => _ProcedurePickerState();
}

class _ProcedurePickerState extends State<_ProcedurePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = [
      for (final p in widget.procedures)
        if (q.isEmpty ||
            p.vcName.toLowerCase().contains(q) ||
            (p.vcCode ?? '').toLowerCase().contains(q) ||
            (p.vcSpecialty ?? '').toLowerCase().contains(q))
          p,
    ];
    return AlertDialog(
      title: const Text(Strings.budgetAddProcedure),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            AppTextField(
              label: Strings.search,
              prefixIcon: Icons.search_rounded,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text(Strings.budgetNoProcedures))
                  : ListView(
                      children: [
                        for (final p in list)
                          ListTile(
                            dense: true,
                            title: Text(p.displayName),
                            subtitle: Text(p.vcSpecialty ?? ''),
                            trailing: Text(
                              Numbers.money(
                                p.vlCurrentPrice ?? p.pricing?.vlPrice ?? 0,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(p),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
      ],
    );
  }
}
