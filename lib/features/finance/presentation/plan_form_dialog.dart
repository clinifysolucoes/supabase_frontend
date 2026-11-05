import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import '../domain/health_models.dart';

class _PriceRow {
  _PriceRow(this.nrProcedure, double? price, String? code)
    : price = TextEditingController(text: Numbers.toField(price)),
      code = TextEditingController(text: code ?? '');

  final int nrProcedure;
  final TextEditingController price;
  final TextEditingController code;

  void dispose() {
    price.dispose();
    code.dispose();
  }
}

/// Cadastro do convenio com a tabela de preco por procedimento. Devolve true
/// quando salvou.
class PlanFormDialog extends ConsumerStatefulWidget {
  const PlanFormDialog({
    super.key,
    required this.catalog,
    required this.accounts,
    this.plan,
    this.readOnly = false,
  });

  final PlanCatalog catalog;
  final List<FinAccount> accounts;
  final HealthPlan? plan;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    required PlanCatalog catalog,
    required List<FinAccount> accounts,
    HealthPlan? plan,
    bool readOnly = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PlanFormDialog(
          catalog: catalog,
          accounts: accounts,
          plan: plan,
          readOnly: readOnly,
        ),
      ) ??
      false;

  @override
  ConsumerState<PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends ConsumerState<PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plan?.vcName ?? '');
  late final _ans = TextEditingController(text: widget.plan?.vcAns ?? '');
  late final _doc = TextEditingController(
    text: widget.plan?.vcDocument == null
        ? ''
        : Masks.format(MaskType.cnpj, widget.plan!.vcDocument!),
  );
  late final _days = TextEditingController(
    text: '${widget.plan?.qtPaymentDays ?? 30}',
  );
  late final _notes = TextEditingController(text: widget.plan?.vcNotes ?? '');
  late int? _account = widget.plan?.nrAccount ?? _firstBank();
  late bool _active = widget.plan?.isActive ?? true;
  late final List<_PriceRow> _rows = [
    for (final p in widget.plan?.prices ?? const <PlanPrice>[])
      _PriceRow(p.nrProcedure, p.vlPrice, p.vcCode),
  ];
  bool _saving = false;

  int? _firstBank() {
    for (final a in widget.accounts) {
      if (a.itType == AccountType.bank) return a.nrAccount;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in [_name, _ans, _doc, _days, _notes]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _procName(int nr) {
    for (final p in widget.catalog.procedures) {
      if (p.nr == nr) return p.name;
    }
    return '#$nr';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeActionsProvider).cash('health_plan_save', {
        'vc_action': widget.plan == null ? 'I' : 'U',
        'nr_plan': ?widget.plan?.nrPlan,
        'vc_name': _name.text.trim(),
        'vc_ans': _ans.text.trim(),
        'vc_document': _doc.text.trim(),
        'qt_payment_days': int.tryParse(_days.text) ?? 30,
        'nr_account': _account,
        'vc_notes': _notes.text.trim(),
        if (widget.plan != null) 'it_status': _active ? 1 : 90,
        'prices': [
          for (final r in _rows)
            PlanPrice(
              nrProcedure: r.nrProcedure,
              vlPrice: Numbers.parse(r.price.text) ?? 0,
              vcCode: r.code.text.trim().isEmpty ? null : r.code.text.trim(),
            ).toJson(),
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
    final enabled = !widget.readOnly && !_saving;
    final used = {for (final r in _rows) r.nrProcedure};
    final available = [
      for (final p in widget.catalog.procedures)
        if (!used.contains(p.nr)) p,
    ];
    final private = {
      for (final p in widget.plan?.prices ?? const <PlanPrice>[])
        p.nrProcedure: p.vlPrivate,
    };

    final fields = <Widget>[
      Text(
        widget.plan?.vcName ?? Strings.planNew,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: '${Strings.name} *',
        controller: _name,
        enabled: enabled,
        maxLength: 80,
        validator: (v) => (v ?? '').trim().isEmpty ? Strings.required : null,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              label: Strings.planAns,
              controller: _ans,
              enabled: enabled,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppTextField(
              label: Strings.planDocument,
              controller: _doc,
              mask: MaskType.cnpj,
              enabled: enabled,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppNumberField(
              label: Strings.planDays,
              controller: _days,
              decimals: 0,
              enabled: enabled,
              required: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _account,
              decoration: const InputDecoration(labelText: Strings.planAccount),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final a in widget.accounts)
                  DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
              ],
              onChanged: enabled ? (v) => setState(() => _account = v) : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          const Expanded(
            child: Text(
              Strings.planPrices,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (enabled && available.isNotEmpty)
            SizedBox(
              width: 260,
              child: SearchableDropdown<({int nr, String name})>(
                label: Strings.planAddPrice,
                items: available,
                itemLabel: (p) => p.name,
                prefixIcon: Icons.add_rounded,
                onChanged: (p) =>
                    setState(() => _rows.add(_PriceRow(p.nr, null, null))),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final r in _rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _procName(r.nrProcedure),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (private[r.nrProcedure] != null)
                        Text(
                          Strings.planPrivate(
                            Numbers.money(private[r.nrProcedure]),
                          ),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: Strings.planCode,
                  controller: r.code,
                  enabled: enabled,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppNumberField(
                  label: Strings.planPrice,
                  controller: r.price,
                  prefixText: 'R\$ ',
                  enabled: enabled,
                  required: true,
                ),
              ),
              if (enabled)
                IconButton(
                  tooltip: Strings.remove,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _rows.remove(r);
                    r.dispose();
                  }),
                ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        label: Strings.notes,
        controller: _notes,
        enabled: enabled,
        maxLength: 500,
        maxLines: 3,
        minLines: 2,
      ),
      if (widget.plan != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_active ? Strings.statusActive : Strings.statusInactive),
          value: _active,
          onChanged: enabled ? (v) => setState(() => _active = v) : null,
        ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
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
