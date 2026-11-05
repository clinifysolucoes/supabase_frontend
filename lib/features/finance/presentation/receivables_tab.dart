import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import '../domain/receivable_models.dart';
import 'finance_widgets.dart';

/// Recebiveis de cartao, boleto e cheque: previsao, bruto, taxa e liquido;
/// confirmar quando cair (ou desfazer).
class ReceivablesTab extends ConsumerWidget {
  const ReceivablesTab({super.key});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    Receivable r,
  ) async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!context.mounted) return;
    final extra = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _ConfirmDialog(receivable: r, accounts: catalog.payableAccounts),
    );
    if (extra == null || !context.mounted) return;
    try {
      await ref.read(financeActionsProvider).cash('fin_receivable_settle', {
        'nr_receivable': r.nrReceivable,
        'vc_action': 'CONFIRM',
        ...extra,
      });
      if (context.mounted) AppSnack.success(context, Strings.recvConfirmed);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, Receivable r) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.recvUndo,
      message: Strings.recvUndoConfirm,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(financeActionsProvider).cash('fin_receivable_settle', {
        'nr_receivable': r.nrReceivable,
        'vc_action': 'UNDO',
      });
      if (context.mounted) AppSnack.success(context, Strings.recvUndone);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(receivablesMonthProvider);
    final filter = ref.watch(receivablesFilterProvider);
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));
    final async = ref.watch(receivablesProvider);
    const labels = {
      ReceivableFilter.all: Strings.recvFilterAll,
      ReceivableFilter.pending: Strings.recvFilterPending,
      ReceivableFilter.overdue: Strings.recvFilterOverdue,
      ReceivableFilter.received: Strings.recvFilterReceived,
      ReceivableFilter.cancelled: Strings.recvFilterCancelled,
    };

    Widget actions(Receivable r) => !canUpdate
        ? const SizedBox.shrink()
        : r.isPending
        ? TextButton(
            onPressed: () => _confirm(context, ref, r),
            child: const Text(Strings.recvConfirm),
          )
        : r.isReceived
        ? TextButton(
            onPressed: () => _undo(context, ref, r),
            child: const Text(Strings.recvUndo),
          )
        : const SizedBox.shrink();

    Widget iconActions(Receivable r) => !canUpdate
        ? const SizedBox.shrink()
        : r.isPending
        ? IconButton(
            tooltip: Strings.recvConfirm,
            icon: const Icon(Icons.check_circle_outline_rounded),
            color: AppColors.success,
            onPressed: () => _confirm(context, ref, r),
          )
        : r.isReceived
        ? IconButton(
            tooltip: Strings.recvUndo,
            icon: const Icon(Icons.undo_rounded),
            onPressed: () => _undo(context, ref, r),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filter != ReceivableFilter.overdue)
              MonthSwitcher(
                month: month,
                onChanged: (m) =>
                    ref.read(receivablesMonthProvider.notifier).state = m,
              ),
            for (final f in ReceivableFilter.values)
              ChoiceChip(
                label: Text(labels[f]!),
                selected: filter == f,
                onSelected: (_) =>
                    ref.read(receivablesFilterProvider.notifier).state = f,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(receivablesProvider),
            ),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    FinKpiCard(label: Strings.recvGross, value: d.vlGross),
                    FinKpiCard(
                      label: Strings.recvFee,
                      value: d.vlFee,
                      color: AppColors.danger,
                    ),
                    FinKpiCard(
                      label: Strings.recvPendingTotal,
                      value: d.vlPending,
                      color: AppColors.warning,
                    ),
                    FinKpiCard(
                      label: Strings.recvReceivedTotal,
                      value: d.vlReceived,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: d.items.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.credit_card_outlined,
                          title: Strings.recvNone,
                          subtitle: Strings.recvNoneHint,
                        )
                      : context.isMobile
                      ? ListView.separated(
                          itemCount: d.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final r = d.items[i];
                            return Card(
                              child: ListTile(
                                title: Text(r.vcPatient ?? r.vcDescription),
                                subtitle: Text(
                                  [
                                    Dates.format(r.dtExpected),
                                    PaymentMethod.label(r.itPaymentMethod),
                                    '${r.nrInstallment}/${r.qtInstallments}',
                                    ReceivableStatus.label(
                                      r.itStatus,
                                      overdue: r.idOverdue,
                                    ),
                                  ].join(' · '),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Numbers.money(r.vlNet),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Flexible(child: actions(r)),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : AppTable(
                          minWidth: 960,
                          columns: const [
                            DataColumn(label: Text('')),
                            DataColumn(label: Text(Strings.recvExpected)),
                            DataColumn(label: Text(Strings.finPatient)),
                            DataColumn(label: Text(Strings.finPaymentMethod)),
                            DataColumn(
                              label: Text(Strings.recvGross),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(Strings.recvFee),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(Strings.recvNet),
                              numeric: true,
                            ),
                            DataColumn(label: Text(Strings.status)),
                            DataColumn(label: Text(Strings.finAccount)),
                          ],
                          rows: [
                            for (final r in d.items)
                              DataRow(
                                cells: [
                                  DataCell(iconActions(r)),
                                  DataCell(Text(Dates.format(r.dtExpected))),
                                  DataCell(
                                    Text(
                                      [
                                        r.vcPatient ?? r.vcDescription,
                                        ?r.vcReference,
                                      ].join(' · '),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${PaymentMethod.label(r.itPaymentMethod)}'
                                      ' ${r.nrInstallment}/${r.qtInstallments}',
                                    ),
                                  ),
                                  DataCell(Text(Numbers.money(r.vlGross))),
                                  DataCell(
                                    Text(
                                      Numbers.money(
                                        r.isReceived
                                            ? r.vlGross - (r.vlReceived ?? 0)
                                            : r.vlFee,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      Numbers.money(
                                        r.isReceived ? r.vlReceived : r.vlNet,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(_StatusText(r)),
                                  DataCell(Text(r.vcAccount ?? '-')),
                                ],
                              ),
                          ],
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

class _StatusText extends StatelessWidget {
  const _StatusText(this.r);

  final Receivable r;

  @override
  Widget build(BuildContext context) {
    final color = switch (r.itStatus) {
      ReceivableStatus.received => AppColors.success,
      ReceivableStatus.cancelled => AppColors.muted,
      _ => r.idOverdue ? AppColors.danger : AppColors.warning,
    };
    return Text(
      r.isReceived && r.dtReceived != null
          ? '${ReceivableStatus.label(r.itStatus)} ${Dates.format(r.dtReceived)}'
          : ReceivableStatus.label(r.itStatus, overdue: r.idOverdue),
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.receivable, required this.accounts});

  final Receivable receivable;
  final List<FinAccount> accounts;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _date = TextEditingController(
    text: Dates.toField(widget.receivable.dtExpected),
  );
  late final _value = TextEditingController(
    text: Numbers.toField(widget.receivable.vlNet),
  );
  late int? _account = widget.receivable.nrAccount;

  @override
  void dispose() {
    _date.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receivable;
    final accounts = widget.accounts;
    if (!accounts.any((a) => a.nrAccount == _account)) {
      _account = accounts.isEmpty ? null : accounts.first.nrAccount;
    }
    return AlertDialog(
      title: const Text(Strings.recvConfirmTitle),
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
                '${r.vcPatient ?? r.vcDescription} · '
                '${Strings.recvGross} ${Numbers.money(r.vlGross)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                Strings.recvConfirmHint,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.recvReceivedOn,
                controller: _date,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    Dates.parseField(v) == null ? Strings.invalidDate : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppNumberField(
                label: Strings.recvReceivedValue,
                controller: _value,
                prefixText: 'R\$ ',
                required: true,
                positive: true,
                validator: (v) => (Numbers.parse(v) ?? 0) > r.vlGross
                    ? Strings.errorMessage('FIN_RECEIVABLE_VALUE_INVALID', {})
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _account,
                decoration: const InputDecoration(
                  labelText: Strings.finAccount,
                ),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
                ],
                onChanged: (v) => setState(() => _account = v),
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
              'dt_received': Dates.toIso(Dates.parseField(_date.text)!),
              'vl_received': Numbers.parse(_value.text),
              'nr_account': _account,
            });
          },
          child: const Text(Strings.confirm),
        ),
      ],
    );
  }
}
