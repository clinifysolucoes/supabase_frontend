import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../../settings/application/settings_controller.dart';
import '../application/finance_controllers.dart';
import '../data/receipt_pdf.dart';
import '../domain/receipt_models.dart';
import '../domain/finance_models.dart';
import 'attachments_section.dart';
import 'entry_form_dialog.dart';
import 'payment_details_fields.dart';
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
    final canCreate = ref.read(canCreateProvider(ScreenCodes.finance));
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _EntryDetailsDialog(
        entry: entry,
        canUpdate: canUpdate,
        canCreate: canCreate,
      ),
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
        final methods = entry.itKind == EntryKind.receivable
            ? await loadAcceptedPaymentMethods(ref)
            : PaymentMethod.all;
        if (!context.mounted) return;
        final extra = await SettleDialog.show(
          context,
          entry,
          catalog,
          methods: methods,
        );
        if (extra != null && context.mounted) {
          final ok = await _run(
            context,
            ref,
            entry,
            'PAY',
            Strings.finSettled,
            extra,
          );
          // recebido: oferece o recibo na hora
          if (ok &&
              context.mounted &&
              canCreate &&
              entry.itKind == EntryKind.receivable) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              SnackBar(
                content: const Text(Strings.finSettled),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: Strings.receiptIssue,
                  onPressed: () => issueReceipt(context, ref, entry),
                ),
              ),
            );
          } else if (ok && context.mounted) {
            AppSnack.success(context, Strings.finSettled);
          }
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
      case 'RECEIPT_ISSUE':
        await issueReceipt(context, ref, entry);
      case 'RECEIPT_PDF':
        await _receiptPdf(context, ref, entry);
      case 'RECEIPT_CANCEL':
        await _cancelReceipt(context, ref, entry);
    }
  }

  /// Dialogo do pagador e emissao do recibo; baixa o PDF.
  static Future<void> issueReceipt(
    BuildContext context,
    WidgetRef ref,
    FinEntry entry,
  ) async {
    final input = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => _ReceiptIssueDialog(entry: entry),
    );
    if (input == null || !context.mounted) return;
    try {
      final doc = await ref
          .read(financeActionsProvider)
          .issueReceipt(
            entry.nrEntry,
            payerName: input.$1,
            payerDocument: input.$2,
            description: input.$3,
          );
      await _savePdf(doc);
      if (context.mounted) {
        AppSnack.success(
          context,
          doc.idExisting
              ? Strings.receiptAlready(doc.receipt.vcNumber)
              : Strings.receiptIssued(doc.receipt.vcNumber),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  static Future<void> _savePdf(ReceiptDoc doc) async {
    final bytes = await ReceiptPdf.build(doc);
    await FileDownload.savePdf(
      name: ReceiptPdf.fileName(doc.receipt),
      bytes: bytes,
    );
  }

  static Future<void> _receiptPdf(
    BuildContext context,
    WidgetRef ref,
    FinEntry entry,
  ) async {
    try {
      final doc = await ref
          .read(financeActionsProvider)
          .receiptOf(entry.nrEntry);
      await _savePdf(doc);
      if (context.mounted) AppSnack.success(context, Strings.receiptDownloaded);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  static Future<void> _cancelReceipt(
    BuildContext context,
    WidgetRef ref,
    FinEntry entry,
  ) async {
    final nr = entry.nrReceipt;
    if (nr == null) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Strings.receiptCancelTitle(entry.vcReceiptNumber ?? '')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(Strings.receiptCancelHint),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.receiptCancelReason,
                controller: reason,
                maxLength: 200,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(Strings.receiptCancel),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true || !context.mounted) return;
    if (text.isEmpty) {
      AppSnack.error(context, Strings.receiptCancelReasonRequired);
      return;
    }
    try {
      await ref.read(financeActionsProvider).cancelReceipt(nr, text);
      if (context.mounted) AppSnack.success(context, Strings.receiptCancelled);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  static Future<bool> _run(
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
      // a baixa (PAY) avisa no chamador, que oferece o recibo
      if (context.mounted && action != 'PAY') AppSnack.success(context, done);
      return true;
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
      return false;
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
  const _EntryDetailsDialog({
    required this.entry,
    required this.canUpdate,
    this.canCreate = false,
  });

  final FinEntry entry;
  final bool canUpdate;
  final bool canCreate;

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
        child: SingleChildScrollView(
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
                  receivable
                      ? Strings.finReceivedAmount
                      : Strings.finPaidAmount,
                  Numbers.money(e.vlPaid),
                ),
              ],
              if (receivable && e.isPaid)
                info(Strings.receipt, e.vcReceiptNumber ?? Strings.receiptNone),
              info(Strings.notes, e.vcNotes),
              AttachmentsSection(entry: e, canUpdate: canUpdate),
            ],
          ),
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
        if (receivable && e.isPaid && e.nrReceipt != null && canUpdate)
          TextButton(
            onPressed: () => pop('RECEIPT_CANCEL'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(Strings.receiptCancel),
          ),
        if (receivable && e.isPaid && e.nrReceipt != null)
          OutlinedButton.icon(
            onPressed: () => pop('RECEIPT_PDF'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text(Strings.receiptDownload),
          ),
        if (receivable && e.isPaid && e.nrReceipt == null && canCreate)
          OutlinedButton.icon(
            onPressed: () => pop('RECEIPT_ISSUE'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text(Strings.receiptIssue),
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
  const SettleDialog({
    super.key,
    required this.entry,
    required this.catalog,
    this.methods = PaymentMethod.all,
  });

  final FinEntry entry;
  final FinCatalog catalog;

  /// Formas oferecidas (a receber: as aceitas pela filial).
  final List<int> methods;

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    FinEntry entry,
    FinCatalog catalog, {
    List<int> methods = PaymentMethod.all,
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        SettleDialog(entry: entry, catalog: catalog, methods: methods),
  );

  @override
  State<SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<SettleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _date;
  late final TextEditingController _amount;
  final _cardInstallments = TextEditingController(text: '1');
  final _details = PaymentDetailsController();
  int? _account;
  int? _method;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = TextEditingController(text: Dates.toField(DateTime.now()));
    // a receber vencida: ja com multa e juros ate hoje
    _amount = TextEditingController(
      text: Numbers.toField(e.vlAmount + e.vlLateTotal),
    );
    final active = widget.catalog.payableAccounts;
    _account = e.nrAccount ?? (active.isEmpty ? null : active.first.nrAccount);
    _method = widget.methods.contains(e.itPaymentMethod)
        ? e.itPaymentMethod
        : null;
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _cardInstallments.dispose();
    _details.dispose();
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
      if (widget.entry.itKind == EntryKind.receivable &&
          widget.catalog.hasRate(_method))
        ..._details.value(_method).toJson(),
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
                helper: widget.entry.vlLateTotal > 0
                    ? Strings.finLateIncluded(
                        Numbers.money(widget.entry.vlLateFee),
                        Numbers.money(widget.entry.vlLateInterest),
                      )
                    : null,
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
                  for (final m in widget.methods)
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
                PaymentDetailsFields(controller: _details, method: _method),
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

/// Pagador e "referente a" do recibo. Devolve (nome, documento, descricao);
/// vazios usam o padrao do banco (paciente da conta e descricao da conta).
class _ReceiptIssueDialog extends StatefulWidget {
  const _ReceiptIssueDialog({required this.entry});

  final FinEntry entry;

  @override
  State<_ReceiptIssueDialog> createState() => _ReceiptIssueDialogState();
}

class _ReceiptIssueDialogState extends State<_ReceiptIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.entry.vcPatient ?? '');
  final _doc = TextEditingController();
  late final _desc = TextEditingController(text: widget.entry.vcDescription);

  @override
  void dispose() {
    _name.dispose();
    _doc.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPatient = widget.entry.vcPatient != null;
    return AlertDialog(
      title: const Text(Strings.receiptIssueTitle),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.entry.vcDescription} · ${Numbers.money(widget.entry.vlPaid ?? widget.entry.vlAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: '${Strings.receiptPayer} *',
                controller: _name,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? Strings.receiptPayerRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.receiptPayerDocument,
                hint: hasPatient ? Strings.receiptPayerDocumentHint : null,
                controller: _doc,
                mask: MaskType.cpfCnpj,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.receiptDescription,
                controller: _desc,
                maxLength: 200,
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
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final name = _name.text.trim();
            Navigator.of(context).pop((
              // nome do paciente sem alteracao: deixa o banco usar o cadastro
              hasPatient && name == widget.entry.vcPatient ? '' : name,
              Masks.unmask(_doc.text),
              _desc.text.trim(),
            ));
          },
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(Strings.receiptIssue),
        ),
      ],
    );
  }
}
