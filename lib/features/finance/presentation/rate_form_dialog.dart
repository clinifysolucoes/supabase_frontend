import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import '../domain/receivable_models.dart';

/// Cadastro de taxa de recebimento (cartao, boleto, cheque). Devolve true
/// quando salvou.
class RateFormDialog extends ConsumerStatefulWidget {
  const RateFormDialog({
    super.key,
    required this.accounts,
    this.rate,
    this.readOnly = false,
  });

  final List<FinAccount> accounts;
  final FinRate? rate;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    required List<FinAccount> accounts,
    FinRate? rate,
    bool readOnly = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) =>
            RateFormDialog(accounts: accounts, rate: rate, readOnly: readOnly),
      ) ??
      false;

  @override
  ConsumerState<RateFormDialog> createState() => _RateFormDialogState();
}

class _RateFormDialogState extends ConsumerState<RateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.rate?.vcName ?? '');
  late final _min = TextEditingController(
    text: '${widget.rate?.qtInstallmentsMin ?? 1}',
  );
  late final _max = TextEditingController(
    text: '${widget.rate?.qtInstallmentsMax ?? 1}',
  );
  late final _pc = TextEditingController(
    text: Numbers.toField(widget.rate?.pcFee),
  );
  late final _fixed = TextEditingController(
    text: widget.rate == null || widget.rate!.vlFeeFixed == 0
        ? ''
        : Numbers.toField(widget.rate!.vlFeeFixed),
  );
  late final _days = TextEditingController(
    text: '${widget.rate?.qtDays ?? 30}',
  );
  late int _method = widget.rate?.itPaymentMethod ?? 3;
  late int? _account = widget.rate?.nrAccount ?? _firstBank(widget.accounts);
  late bool _active = widget.rate?.isActive ?? true;
  bool _saving = false;

  static int? _firstBank(List<FinAccount> accounts) {
    for (final a in accounts) {
      if (a.itType == AccountType.bank) return a.nrAccount;
    }
    return accounts.isEmpty ? null : accounts.first.nrAccount;
  }

  @override
  void dispose() {
    for (final c in [_name, _min, _max, _pc, _fixed, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final installments = RateMethod.installments(_method);
    try {
      await ref
          .read(financeActionsProvider)
          .saveRegister(
            rpc: 'fin_rate_save',
            key: 'nr_rate',
            id: widget.rate?.nrRate,
            fields: {
              'vc_name': _name.text.trim(),
              'it_payment_method': _method,
              'qt_installments_min': installments
                  ? int.tryParse(_min.text) ?? 1
                  : 1,
              'qt_installments_max': installments
                  ? int.tryParse(_max.text) ?? 1
                  : 1,
              'pc_fee': Numbers.parse(_pc.text) ?? 0,
              'vl_fee_fixed': Numbers.parse(_fixed.text) ?? 0,
              'qt_days': int.tryParse(_days.text) ?? 30,
              'nr_account': _account,
              if (widget.rate != null) 'it_status': _active ? 1 : 90,
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.readOnly && !_saving;
    final installments = RateMethod.installments(_method);
    return AlertDialog(
      title: Text(widget.rate?.vcName ?? Strings.rateNew),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: '${Strings.rateName} *',
                  controller: _name,
                  enabled: enabled,
                  maxLength: 60,
                  autofocus: widget.rate == null,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? Strings.required : null,
                ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: Strings.rateMethod,
                  ),
                  items: [
                    for (final m in RateMethod.all)
                      DropdownMenuItem(
                        value: m,
                        child: Text(PaymentMethod.label(m)),
                      ),
                  ],
                  onChanged: enabled
                      ? (v) => setState(() => _method = v ?? _method)
                      : null,
                ),
                if (installments) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppNumberField(
                          label: Strings.rateInstallmentsMin,
                          controller: _min,
                          decimals: 0,
                          enabled: enabled,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppNumberField(
                          label: Strings.rateInstallmentsMax,
                          controller: _max,
                          decimals: 0,
                          enabled: enabled,
                          required: true,
                          validator: (v) {
                            final max = int.tryParse(v ?? '') ?? 0;
                            final min = int.tryParse(_min.text) ?? 1;
                            return max < min || max > 24 ? '$min – 24' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppNumberField(
                        label: Strings.ratePercent,
                        controller: _pc,
                        suffixText: '%',
                        enabled: enabled,
                        validator: (v) {
                          final x = Numbers.parse(v) ?? 0;
                          return x < 0 || x > 100 ? '0 – 100' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppNumberField(
                        label: Strings.rateFixed,
                        controller: _fixed,
                        prefixText: 'R\$ ',
                        enabled: enabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppNumberField(
                        label: Strings.rateDays,
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
                        decoration: const InputDecoration(
                          labelText: Strings.rateAccount,
                        ),
                        items: [
                          for (final a in widget.accounts)
                            DropdownMenuItem(
                              value: a.nrAccount,
                              child: Text(a.vcName),
                            ),
                        ],
                        validator: (v) =>
                            v == null ? Strings.finChooseAccount : null,
                        onChanged: enabled
                            ? (v) => setState(() => _account = v)
                            : null,
                      ),
                    ),
                  ],
                ),
                if (widget.rate != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _active ? Strings.statusActive : Strings.statusInactive,
                    ),
                    value: _active,
                    onChanged: enabled
                        ? (v) => setState(() => _active = v)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.readOnly ? Strings.close : Strings.cancel),
        ),
        if (!widget.readOnly)
          AppButton(
            label: Strings.save,
            expanded: false,
            loading: _saving,
            onPressed: _save,
          ),
      ],
    );
  }
}
