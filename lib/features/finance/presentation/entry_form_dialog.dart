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
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../application/finance_controllers.dart';
import '../data/finance_repository.dart';
import '../domain/finance_models.dart';

enum _Repeat { once, installments, monthly }

/// Cadastro (unica, parcelada ou mensal; pode nascer paga) e alteracao de
/// uma conta a pagar ou a receber. Devolve true quando salvou.
class EntryFormDialog extends ConsumerStatefulWidget {
  const EntryFormDialog({
    super.key,
    required this.kind,
    required this.catalog,
    this.entry,
    this.readOnly = false,
  });

  final int kind;
  final FinCatalog catalog;
  final FinEntry? entry;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    required int kind,
    required FinCatalog catalog,
    FinEntry? entry,
    bool readOnly = false,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntryFormDialog(
        kind: kind,
        catalog: catalog,
        entry: entry,
        readOnly: readOnly,
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends ConsumerState<EntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _due;
  late final TextEditingController _paidOn;
  late final TextEditingController _count;
  late final TextEditingController _notes;
  int? _category;
  int? _account;
  int? _supplier;
  int? _patient;
  String? _patientName;
  int? _method;
  _Repeat _repeat = _Repeat.once;
  bool _paid = false;
  bool _saving = false;

  bool get _isNew => widget.entry == null;
  bool get _receivable => widget.kind == EntryKind.receivable;

  /// Pago: so descricao, categoria e observacoes mudam.
  bool get _valuesLocked => widget.readOnly || (widget.entry?.isPaid ?? false);

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _description = TextEditingController(text: e?.vcDescription ?? '');
    _amount = TextEditingController(text: Numbers.toField(e?.vlAmount));
    _due = TextEditingController(
      text: Dates.toField(e?.dtDue ?? DateTime.now()),
    );
    _paidOn = TextEditingController(text: Dates.toField(DateTime.now()));
    _count = TextEditingController(text: '2');
    _notes = TextEditingController(text: e?.vcNotes ?? '');
    _category = e?.nrCategory;
    _account = e?.nrAccount;
    _supplier = e?.nrSupplier;
    _patient = e?.nrPatient;
    _patientName = e?.vcPatient;
    _method = e?.itPaymentMethod;
    _amount.addListener(_refresh);
    _count.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _due.dispose();
    _paidOn.dispose();
    _count.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      AppSnack.error(context, Strings.finChooseCategory);
      return;
    }
    if (_isNew && _paid && _account == null) {
      AppSnack.error(context, Strings.finChooseAccount);
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(financeActionsProvider);
    try {
      if (_isNew) {
        final count = int.tryParse(_count.text) ?? 1;
        final qt = await actions.createEntry(
          EntryDraft(
            itKind: widget.kind,
            nrCategory: _category!,
            vcDescription: _description.text.trim(),
            vlAmount: Numbers.parse(_amount.text) ?? 0,
            dtDue: Dates.parseField(_due.text)!,
            nrAccount: _account,
            nrSupplier: _receivable ? null : _supplier,
            nrPatient: _receivable ? _patient : null,
            itPaymentMethod: _method,
            vcNotes: _nullIfEmpty(_notes.text),
            qtInstallments: _repeat == _Repeat.installments ? count : 1,
            idRecurring: _repeat == _Repeat.monthly,
            qtRepeat: count,
            idPaid: _repeat == _Repeat.once && _paid,
            dtPaid: Dates.parseField(_paidOn.text),
          ),
        );
        if (mounted) AppSnack.success(context, Strings.finCreated(qt));
      } else {
        await actions.updateEntry(widget.entry!.nrEntry, {
          'vc_description': _description.text.trim(),
          'nr_category': _category,
          'vc_notes': _nullIfEmpty(_notes.text),
          if (!_valuesLocked) ...{
            'vl_amount': Numbers.parse(_amount.text),
            'dt_due': Dates.toIso(Dates.parseField(_due.text)!),
            'nr_account': _account,
            if (_receivable)
              'nr_patient': _patient
            else
              'nr_supplier': _supplier,
            'it_payment_method': _method,
          },
        });
        if (mounted) AppSnack.success(context, Strings.savedSuccess);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null) {
      setState(() {
        _patient = p.nrPatient;
        _patientName = p.vcName;
      });
    }
  }

  String? _dateValidator(String? v) =>
      Dates.parseField(v) == null ? Strings.invalidDate : null;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final pad = isMobile ? AppSpacing.md : AppSpacing.lg;
    final c = widget.catalog;
    final e = widget.entry;
    final categories = [
      for (final x in c.categoriesOf(widget.kind))
        if (x.isActive || x.nrCategory == _category) x,
    ];
    final accounts = [
      for (final a in c.accounts)
        if (a.isActive || a.nrAccount == _account) a,
    ];
    final suppliers = [
      for (final s in c.suppliers)
        if (s.isActive || s.nrSupplier == _supplier) s,
    ];
    FinCategory? category;
    for (final x in categories) {
      if (x.nrCategory == _category) category = x;
    }
    FinSupplier? supplier;
    for (final s in suppliers) {
      if (s.nrSupplier == _supplier) supplier = s;
    }
    final count = int.tryParse(_count.text) ?? 0;
    final amount = Numbers.parse(_amount.text) ?? 0;
    final title = _isNew
        ? (_receivable ? Strings.newReceivable : Strings.newPayable)
        : (_receivable ? Strings.editReceivable : Strings.editPayable);
    final enabled = !widget.readOnly && !_saving;
    final valuesEnabled = enabled && !_valuesLocked;

    Widget row(List<Widget> children) => isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                children[i],
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: children[i]),
              ],
            ],
          );

    final fields = <Widget>[
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      if (e != null && e.isGrouped) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          Strings.finInstallmentOf(e.nrInstallment, e.qtInstallments),
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
      if (e != null && e.isPaid) ...[
        const SizedBox(height: AppSpacing.sm),
        const Text(
          Strings.finPaidLockedHint,
          style: TextStyle(color: AppColors.warning),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: '${Strings.finDescription} *',
        controller: _description,
        enabled: enabled,
        maxLength: 140,
        textCapitalization: TextCapitalization.sentences,
        validator: (v) => (v ?? '').trim().isEmpty ? Strings.required : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      SearchableDropdown<FinCategory>(
        label: '${Strings.finCategory} *',
        items: categories,
        value: category,
        enabled: enabled,
        itemLabel: (x) => x.vcName,
        itemSubtitle: (x) =>
            x.itCostType == null ? null : CostType.label(x.itCostType),
        onChanged: (x) => setState(() => _category = x.nrCategory),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_isNew) ...[
        SegmentedButton<_Repeat>(
          segments: const [
            ButtonSegment(
              value: _Repeat.once,
              label: Text(Strings.finRepeatOnce),
            ),
            ButtonSegment(
              value: _Repeat.installments,
              label: Text(Strings.finRepeatInstallments),
            ),
            ButtonSegment(
              value: _Repeat.monthly,
              label: Text(Strings.finRepeatMonthly),
            ),
          ],
          selected: {_repeat},
          onSelectionChanged: enabled
              ? (s) => setState(() {
                  _repeat = s.first;
                  if (_repeat == _Repeat.monthly && count < 2) {
                    _count.text = '12';
                  }
                })
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      row([
        AppNumberField(
          label:
              '${_repeat == _Repeat.installments ? Strings.finTotalAmount : (_repeat == _Repeat.monthly ? Strings.finAmountEach : Strings.finAmount)} *',
          controller: _amount,
          prefixText: 'R\$ ',
          enabled: valuesEnabled,
          required: true,
          positive: true,
        ),
        AppTextField(
          label:
              '${_repeat == _Repeat.once ? Strings.finDue : Strings.finFirstDue} *',
          controller: _due,
          mask: MaskType.date,
          enabled: valuesEnabled,
          keyboardType: TextInputType.number,
          validator: _dateValidator,
        ),
        if (_isNew && _repeat != _Repeat.once)
          AppNumberField(
            label: _repeat == _Repeat.installments
                ? Strings.finInstallments
                : Strings.finMonths,
            controller: _count,
            decimals: 0,
            enabled: enabled,
            required: true,
            positive: true,
          ),
      ]),
      if (_isNew && _repeat != _Repeat.once && count > 0 && amount > 0) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          _repeat == _Repeat.installments
              ? Strings.finInstallmentsPreview(
                  count,
                  Numbers.money((amount / count * 100).floorToDouble() / 100),
                )
              : Strings.finRepeatPreview(count),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      row([
        if (_receivable)
          InputDecorator(
            decoration: InputDecoration(
              labelText: Strings.finPatient,
              enabled: valuesEnabled,
              suffixIcon: _patient == null || !valuesEnabled
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _patient = null;
                        _patientName = null;
                      }),
                    ),
            ),
            child: InkWell(
              onTap: valuesEnabled ? _pickPatient : null,
              child: Text(
                _patientName ?? Strings.finChoosePatient,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _patientName == null ? AppColors.muted : null,
                ),
              ),
            ),
          )
        else
          SearchableDropdown<FinSupplier>(
            label: Strings.finSupplier,
            items: suppliers,
            value: supplier,
            enabled: valuesEnabled,
            hint: Strings.finNoSupplier,
            itemLabel: (s) => s.vcName,
            onChanged: (s) => setState(() => _supplier = s.nrSupplier),
          ),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: _method,
          decoration: const InputDecoration(
            labelText: Strings.finPaymentMethod,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('-')),
            for (final m in PaymentMethod.all)
              DropdownMenuItem(value: m, child: Text(PaymentMethod.label(m))),
          ],
          onChanged: valuesEnabled ? (v) => setState(() => _method = v) : null,
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<int?>(
        isExpanded: true,
        initialValue: _account,
        decoration: InputDecoration(
          labelText: _paid ? '${Strings.finAccount} *' : Strings.finAccount,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('-')),
          for (final a in accounts)
            DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
        ],
        onChanged: valuesEnabled ? (v) => setState(() => _account = v) : null,
      ),
      if (_isNew && _repeat == _Repeat.once) ...[
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            _receivable ? Strings.finAlreadyReceived : Strings.finAlreadyPaid,
          ),
          value: _paid,
          onChanged: enabled ? (v) => setState(() => _paid = v ?? false) : null,
        ),
        if (_paid)
          AppTextField(
            label: _receivable ? Strings.finReceivedOn : Strings.finPaidOn,
            controller: _paidOn,
            mask: MaskType.date,
            keyboardType: TextInputType.number,
            enabled: enabled,
            validator: _dateValidator,
          ),
      ],
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: Strings.notes,
        controller: _notes,
        enabled: enabled,
        maxLength: 500,
        maxLines: 3,
        minLines: 2,
      ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
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
                    children: fields,
                  ),
                ),
              ),
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
