import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'entry_form_dialog.dart';
import 'finance_widgets.dart';

/// Detalhes de um lancamento e as acoes possiveis na situacao dele:
/// editar, pagar/receber, desfazer, cancelar e reabrir.
abstract final class EntryActions {
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    FinEntry entry,
  ) async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!context.mounted) return;
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.finance));
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _EntryDetailsDialog(entry: entry, canUpdate: canUpdate),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'EDIT':
        await EntryFormDialog.show(
          context,
          kind: entry.itKind,
          catalog: catalog,
          entry: entry,
          readOnly: !canUpdate || entry.isCancelled,
        );
      case 'PAY':
        final extra = await SettleDialog.show(context, entry, catalog);
        if (extra != null && context.mounted) {
          await _run(context, ref, entry, 'PAY', Strings.finSettled, extra);
        }
      case 'UNDO':
        if (await AppConfirmDialog.show(
              context,
              title: Strings.finUndoPayment,
              message: Strings.finUndoConfirm,
            ) &&
            context.mounted) {
          await _run(context, ref, entry, 'UNDO', Strings.finUndone);
        }
      case 'CANCEL':
        final following = await _confirmCancel(context, entry);
        if (following != null && context.mounted) {
          await _run(context, ref, entry, 'CANCEL', Strings.finCancelled, {
            'id_following': following,
          });
        }
      case 'REOPEN':
        await _run(context, ref, entry, 'REOPEN', Strings.finReopened);
    }
  }

  static Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    FinEntry entry,
    String action,
    String done, [
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      await ref
          .read(financeActionsProvider)
          .settle(entry.nrEntry, action, extra);
      if (context.mounted) AppSnack.success(context, done);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  /// null = desistiu; true/false = cancelar tambem as proximas.
  static Future<bool?> _confirmCancel(BuildContext context, FinEntry entry) {
    var following = false;
    final grouped = entry.isGrouped || entry.idRecurring;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(Strings.finCancelEntry),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.finCancelConfirm),
              if (grouped)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(Strings.finCancelFollowing),
                  value: following,
                  onChanged: (v) => setState(() => following = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(Strings.close),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(context).pop(following),
              child: const Text(Strings.finCancelEntry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailsDialog extends StatelessWidget {
  const _EntryDetailsDialog({required this.entry, required this.canUpdate});

  final FinEntry entry;
  final bool canUpdate;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final receivable = e.itKind == EntryKind.receivable;
    Widget info(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
    void pop(String action) => Navigator.of(context).pop(action);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(e.vcDescription)),
          EntryStatusChip(entry: e),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Numbers.money(e.vlAmount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: receivable ? AppColors.success : AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            info(Strings.finDue, Dates.format(e.dtDue)),
            info(Strings.finCategory, e.vcCategory),
            info(
              receivable ? Strings.finPatient : Strings.finSupplier,
              e.counterpart,
            ),
            info(Strings.finAccount, e.vcAccount),
            info(
              Strings.finPaymentMethod,
              e.itPaymentMethod == null
                  ? null
                  : PaymentMethod.label(e.itPaymentMethod),
            ),
            if (e.isGrouped)
              info(
                Strings.finRepeat,
                Strings.finInstallmentOf(e.nrInstallment, e.qtInstallments) +
                    (e.idRecurring ? ' · ${Strings.finRecurring}' : ''),
              ),
            if (e.isPaid) ...[
              info(
                receivable ? Strings.finReceivedOn : Strings.finPaidOn,
                Dates.format(e.dtPaid),
              ),
              info(
                receivable ? Strings.finReceivedAmount : Strings.finPaidAmount,
                Numbers.money(e.vlPaid),
              ),
            ],
            info(Strings.notes, e.vcNotes),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: AppSpacing.sm,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.close),
        ),
        if (canUpdate && e.isOpen)
          TextButton(
            onPressed: () => pop('CANCEL'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(Strings.finCancelEntry),
          ),
        if (canUpdate && e.isPaid)
          TextButton(
            onPressed: () => pop('UNDO'),
            child: const Text(Strings.finUndoPayment),
          ),
        if (canUpdate && e.isCancelled)
          TextButton(
            onPressed: () => pop('REOPEN'),
            child: const Text(Strings.finReopen),
          ),
        OutlinedButton(
          onPressed: () => pop('EDIT'),
          child: Text(
            canUpdate && !e.isCancelled ? Strings.edit : Strings.details,
          ),
        ),
        if (canUpdate && e.isOpen)
          FilledButton.icon(
            onPressed: () => pop('PAY'),
            icon: const Icon(Icons.check_rounded),
            label: Text(receivable ? Strings.finReceive : Strings.finPay),
          ),
      ],
    );
  }
}

/// Baixa: conta, data, valor e forma. Devolve o JSON extra do PAY ou null.
class SettleDialog extends StatefulWidget {
  const SettleDialog({super.key, required this.entry, required this.catalog});

  final FinEntry entry;
  final FinCatalog catalog;

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    FinEntry entry,
    FinCatalog catalog,
  ) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => SettleDialog(entry: entry, catalog: catalog),
  );

  @override
  State<SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<SettleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _date;
  late final TextEditingController _amount;
  final _cardInstallments = TextEditingController(text: '1');
  int? _account;
  int? _method;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = TextEditingController(text: Dates.toField(DateTime.now()));
    _amount = TextEditingController(text: Numbers.toField(e.vlAmount));
    final active = widget.catalog.payableAccounts;
    _account = e.nrAccount ?? (active.isEmpty ? null : active.first.nrAccount);
    _method = e.itPaymentMethod;
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _cardInstallments.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_account == null) {
      AppSnack.error(context, Strings.finChooseAccount);
      return;
    }
    Navigator.of(context).pop({
      'nr_account': _account,
      'dt_paid': Dates.toIso(Dates.parseField(_date.text)!),
      'vl_paid': Numbers.parse(_amount.text),
      'it_payment_method': _method,
      if (_method == 3 && (int.tryParse(_cardInstallments.text) ?? 1) > 1)
        'qt_card_installments': int.tryParse(_cardInstallments.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    final receivable = widget.entry.itKind == EntryKind.receivable;
    return AlertDialog(
      title: Text(receivable ? Strings.finReceiveTitle : Strings.finPayTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry.vcDescription,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _account,
                decoration: const InputDecoration(
                  labelText: '${Strings.finAccount} *',
                ),
                items: [
                  for (final a in widget.catalog.payableAccounts)
                    DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
                ],
                onChanged: (v) => setState(() => _account = v),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: receivable ? Strings.finReceivedOn : Strings.finPaidOn,
                controller: _date,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    Dates.parseField(v) == null ? Strings.invalidDate : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppNumberField(
                label: receivable
                    ? Strings.finReceivedAmount
                    : Strings.finPaidAmount,
                controller: _amount,
                prefixText: 'R\$ ',
                required: true,
                positive: true,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: Strings.finPaymentMethod,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-')),
                  for (final m in PaymentMethod.all)
                    DropdownMenuItem(
                      value: m,
                      child: Text(PaymentMethod.label(m)),
                    ),
                ],
                onChanged: (v) => setState(() => _method = v),
              ),
              if (receivable && _method == 3 && widget.catalog.hasRate(3)) ...[
                const SizedBox(height: AppSpacing.md),
                AppNumberField(
                  label: Strings.cardInstallments,
                  controller: _cardInstallments,
                  decimals: 0,
                  validator: (v) {
                    final n = int.tryParse(v ?? '') ?? 0;
                    return n < 1 || n > 24 ? '1 – 24' : null;
                  },
                ),
              ],
              if (receivable && widget.catalog.hasRate(_method)) ...[
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  Strings.cardRateHint,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
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
          onPressed: _confirm,
          child: Text(receivable ? Strings.finReceive : Strings.finPay),
        ),
      ],
    );
  }
}
