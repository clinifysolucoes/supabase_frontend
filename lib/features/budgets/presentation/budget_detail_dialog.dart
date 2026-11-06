import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../finance/domain/finance_models.dart';
import '../application/budget_controllers.dart';
import '../data/budget_pdf.dart';
import '../domain/budget_models.dart';
import 'budget_form_dialog.dart';

/// Cor da situacao do orcamento.
Color budgetStatusColor(int status, {bool expired = false}) {
  if (expired) return AppColors.muted;
  return switch (status) {
    BudgetStatus.pending => AppColors.warning,
    BudgetStatus.accepted => AppColors.success,
    BudgetStatus.refused || BudgetStatus.cancelled => AppColors.danger,
    _ => AppColors.primary,
  };
}

class BudgetStatusChip extends StatelessWidget {
  const BudgetStatusChip({
    super.key,
    required this.status,
    this.expired = false,
  });

  final int status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final color = budgetStatusColor(status, expired: expired);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        expired ? Strings.budgetExpired : BudgetStatus.label(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Detalhes do orcamento e as acoes da situacao (editar, aprovar desconto,
/// paciente aprovou, recusar, cancelar, reabrir, PDF).
class BudgetDetailDialog extends ConsumerStatefulWidget {
  const BudgetDetailDialog({super.key, required this.nrBudget});

  final int nrBudget;

  static Future<void> show(BuildContext context, int nrBudget) =>
      showDialog<void>(
        context: context,
        builder: (_) => BudgetDetailDialog(nrBudget: nrBudget),
      );

  @override
  ConsumerState<BudgetDetailDialog> createState() => _BudgetDetailDialogState();
}

class _BudgetDetailDialogState extends ConsumerState<BudgetDetailDialog> {
  Budget? _b;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref.read(budgetActionsProvider).get(widget.nrBudget);
      if (mounted) setState(() => (_b = b));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(
    String action,
    String done, [
    Map<String, dynamic> extra = const {},
  ]) async {
    setState(() => _busy = true);
    try {
      final b = await ref
          .read(budgetActionsProvider)
          .status(widget.nrBudget, action, extra);
      if (mounted) {
        setState(() => _b = b);
        AppSnack.success(context, done);
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Budget b) async {
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AcceptDialog(budget: b),
    );
    if (r != null) await _run('ACCEPT', Strings.budgetAcceptedDone, r);
  }

  Future<void> _confirm(
    String action,
    String title,
    String message,
    String done,
  ) async {
    if (await AppConfirmDialog.show(context, title: title, message: message) &&
        mounted) {
      await _run(action, done);
    }
  }

  Future<void> _edit(Budget b) async {
    final nr = await BudgetFormDialog.show(
      context,
      budget: b,
      pcMaxDiscount: b.pcMaxDiscount,
    );
    if (nr != null) await _load();
  }

  Future<void> _pdf(Budget b) async {
    try {
      await FileDownload.savePdf(
        name: BudgetPdf.fileName(b),
        bytes: await BudgetPdf.build(b),
      );
      if (mounted) AppSnack.success(context, Strings.budgetPdfDone);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) {
      return AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(describeError(_error!)),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    Widget info(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
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
    final can = b.canUpdate && !_busy;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(b.title)),
          BudgetStatusChip(status: b.itStatus, expired: b.idExpired),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Numbers.money(b.vlTotal),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              info(Strings.budgetNumberLabel, '${b.nrBudget}'),
              info(Strings.patient, b.vcPatient),
              info(Strings.professional, b.vcProfessional),
              info(Strings.budgetDate, Dates.format(b.dtBudget)),
              info(Strings.budgetValid, Dates.format(b.dtValid)),
              if (b.vlDiscount > 0)
                info(
                  Strings.budgetDiscount,
                  '${Numbers.money(b.vlDiscount)} (${Numbers.percent(b.pcDiscount)})'
                  '${b.idDiscountApproved ? ' · ${Strings.budgetApprovedBy(b.vcUserDiscount ?? '')}' : ''}',
                ),
              if (b.qtInstallments != null || b.itPaymentMethod != null)
                info(
                  Strings.budgetTerms,
                  [
                    if (b.qtInstallments != null) '${b.qtInstallments}x',
                    if (b.itPaymentMethod != null)
                      PaymentMethod.label(b.itPaymentMethod),
                  ].join(' · '),
                ),
              info(Strings.notes, b.vcNotes),
              if (b.itStatus == BudgetStatus.pending)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    Strings.budgetPendingHint(Numbers.percent(b.pcMaxDiscount)),
                    style: const TextStyle(color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.budgetItems,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final i in b.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.vcDescription),
                  subtitle: Text(
                    [
                      if (i.vcTooth != null)
                        '${Strings.budgetTooth}: ${i.vcTooth}',
                      '${Numbers.qty(i.qtQuantity)} × ${Numbers.money(i.vlUnit)}',
                    ].join(' · '),
                  ),
                  trailing: Text(
                    Numbers.money(i.vlTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (b.entries.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Strings.budgetEntries,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final e in b.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.vcDescription),
                    subtitle: Text(
                      '${Strings.finDue} ${Dates.format(e.dtDue)} · '
                      '${switch (e.itStatus) {
                        2 => Strings.budgetEntryPaid,
                        90 => Strings.budgetCancelled,
                        _ => Strings.budgetEntryOpen,
                      }}',
                    ),
                    trailing: Text(Numbers.money(e.vlAmount)),
                  ),
              ],
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
        TextButton.icon(
          onPressed: () => _pdf(b),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text(Strings.budgetPdf),
        ),
        if (can && b.isEditable)
          TextButton(
            onPressed: () => _confirm(
              'REFUSE',
              Strings.budgetRefuse,
              Strings.budgetRefuseConfirm,
              Strings.budgetRefusedDone,
            ),
            child: const Text(Strings.budgetRefuse),
          ),
        if (can && b.itStatus != BudgetStatus.cancelled)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _confirm(
              'CANCEL',
              Strings.budgetCancel,
              b.itStatus == BudgetStatus.accepted
                  ? Strings.budgetCancelAcceptedConfirm
                  : Strings.budgetCancelConfirm,
              Strings.budgetCancelledDone,
            ),
            child: const Text(Strings.budgetCancel),
          ),
        if (can &&
            (b.itStatus == BudgetStatus.refused ||
                b.itStatus == BudgetStatus.cancelled))
          TextButton(
            onPressed: () => _run('REOPEN', Strings.budgetReopenedDone),
            child: const Text(Strings.budgetReopen),
          ),
        if (can && b.isEditable)
          OutlinedButton(
            onPressed: () => _edit(b),
            child: const Text(Strings.edit),
          ),
        if (can && b.itStatus == BudgetStatus.pending && b.canApproveDiscount)
          FilledButton.icon(
            onPressed: () =>
                _run('APPROVE_DISCOUNT', Strings.budgetDiscountApproved),
            icon: const Icon(Icons.verified_rounded),
            label: const Text(Strings.budgetApproveDiscount),
          ),
        if (can && b.itStatus == BudgetStatus.open)
          FilledButton.icon(
            onPressed: b.idExpired ? null : () => _accept(b),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text(Strings.budgetAccept),
          ),
      ],
    );
  }
}

/// Paciente aprovou: parcelas, primeiro vencimento e forma -> contas a receber.
class _AcceptDialog extends StatefulWidget {
  const _AcceptDialog({required this.budget});

  final Budget budget;

  @override
  State<_AcceptDialog> createState() => _AcceptDialogState();
}

class _AcceptDialogState extends State<_AcceptDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _n = TextEditingController(
    text: '${widget.budget.qtInstallments ?? 1}',
  );
  late final _first = TextEditingController(
    text: Dates.toField(DateTime.now()),
  );
  late int? _method = widget.budget.itPaymentMethod;

  @override
  void dispose() {
    _n.dispose();
    _first.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_n.text) ?? 1;
    return AlertDialog(
      title: const Text(Strings.budgetAccept),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.budgetAcceptHint(Numbers.money(widget.budget.vlTotal)),
              ),
              const SizedBox(height: AppSpacing.md),
              AppNumberField(
                label: Strings.budgetInstallments,
                controller: _n,
                decimals: 0,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final x = int.tryParse(v ?? '') ?? 0;
                  return x < 1 || x > 24 ? '1 – 24' : null;
                },
                helper: n > 1
                    ? Strings.budgetInstallmentOf(
                        Numbers.money(widget.budget.vlTotal / n),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.budgetFirstDue,
                controller: _first,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    Dates.parseField(v) == null ? Strings.invalidDate : null,
              ),
              const SizedBox(height: AppSpacing.sm),
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop({
              'qt_installments': int.tryParse(_n.text) ?? 1,
              'dt_first_due': Dates.toIso(Dates.parseField(_first.text)!),
              'it_payment_method': _method,
            });
          },
          child: const Text(Strings.budgetAcceptConfirm),
        ),
      ],
    );
  }
}
