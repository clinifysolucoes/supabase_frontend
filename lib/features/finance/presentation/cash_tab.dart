import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/cash_models.dart';
import '../domain/finance_models.dart';
import 'finance_widgets.dart';

/// Caixa do dia: o meu caixa (abrir, resumo, sangria/suprimento, fechar), os
/// caixas da filial e os ultimos fechamentos.
class CashTab extends ConsumerWidget {
  const CashTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashStatusProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(cashStatusProvider),
      ),
      data: (s) {
        final mine = _MyCash(status: s, canCreate: canCreate);
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CashAccounts(accounts: s.accounts),
            const SizedBox(height: AppSpacing.md),
            _History(
              sessions: [
                for (final x in s.sessions)
                  if (!x.isOpen) x,
              ],
            ),
          ],
        );
        return SingleChildScrollView(
          child: context.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mine,
                    const SizedBox(height: AppSpacing.md),
                    side,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mine),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: side),
                  ],
                ),
        );
      },
    );
  }
}

class _MyCash extends ConsumerWidget {
  const _MyCash({required this.status, required this.canCreate});

  final CashStatus status;
  final bool canCreate;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final free = [
      for (final a in status.accounts)
        if (a.isFree) a,
    ];
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OpenCashDialog(accounts: free),
    );
    if (r == null || !context.mounted) return;
    try {
      await ref.read(financeActionsProvider).cash('fin_cash_open', r);
      if (context.mounted) AppSnack.success(context, Strings.cashOpened);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    CashSession s,
  ) async {
    final counted = await showDialog<double>(
      context: context,
      builder: (_) => _CloseCashDialog(session: s),
    );
    if (counted == null || !context.mounted) return;
    try {
      final r = await ref.read(financeActionsProvider).cash('fin_cash_close', {
        'nr_session': s.nrSession,
        'vl_counted': counted,
      });
      if (context.mounted) {
        AppSnack.success(
          context,
          Strings.cashClosedDiff(Numbers.money(r['vl_difference'] as num?)),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref, int type) async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!context.mounted) return;
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TransferDialog(
        accounts: [
          for (final a in catalog.accounts)
            if (a.isActive) a,
        ],
        type: type,
        cashAccount: status.mine?.nrAccount,
      ),
    );
    if (r == null || !context.mounted) return;
    try {
      await ref.read(financeActionsProvider).cash('fin_transfer_save', r);
      if (context.mounted) AppSnack.success(context, Strings.cashMoved);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = status.mine;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSectionTitle(
              Strings.cashMine,
              trailing: canCreate
                  ? TextButton.icon(
                      onPressed: () =>
                          _move(context, ref, TransferType.transfer),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text(Strings.cashTransfer),
                    )
                  : null,
            ),
            if (s == null) ...[
              Text(
                status.accounts.isEmpty
                    ? Strings.cashNoCashAccount
                    : Strings.cashClosed,
                style: const TextStyle(color: AppColors.muted),
              ),
              if (canCreate && status.accounts.any((a) => a.isFree)) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: Strings.cashOpenAction,
                    icon: Icons.lock_open_rounded,
                    expanded: false,
                    onPressed: () => _open(context, ref),
                  ),
                ),
              ],
            ] else ...[
              Text(
                '${s.vcAccount} · '
                '${Strings.cashOpenedAt(Dates.formatTime(s.dhOpen))}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              _SessionSummary(session: s),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (canCreate) ...[
                    AppButton(
                      label: Strings.cashWithdrawal,
                      icon: Icons.north_east_rounded,
                      variant: AppButtonVariant.secondary,
                      expanded: false,
                      onPressed: () =>
                          _move(context, ref, TransferType.withdrawal),
                    ),
                    AppButton(
                      label: Strings.cashSupply,
                      icon: Icons.south_west_rounded,
                      variant: AppButtonVariant.secondary,
                      expanded: false,
                      onPressed: () => _move(context, ref, TransferType.supply),
                    ),
                    AppButton(
                      label: Strings.cashCloseAction,
                      icon: Icons.lock_rounded,
                      expanded: false,
                      onPressed: () => _close(context, ref, s),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resumo de uma sessao: abertura, entradas (por forma), saidas, sangrias e
/// suprimentos, esperado e (fechada) contado e diferenca.
class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    Widget line(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    final methods = s.byMethod.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(Strings.cashOpening, Numbers.money(s.vlOpen)),
        line(Strings.cashIn, Numbers.money(s.vlIn), color: AppColors.success),
        for (final m in methods)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: line(
              m.key == 0 ? Strings.cashNoMethod : PaymentMethod.label(m.key),
              Numbers.money(m.value),
              color: AppColors.muted,
            ),
          ),
        line(Strings.cashOut, Numbers.money(s.vlOut), color: AppColors.danger),
        line(
          Strings.cashMoves,
          Numbers.money(s.vlTransferIn - s.vlTransferOut),
        ),
        const Divider(),
        line(Strings.cashExpected, Numbers.money(s.vlExpected), bold: true),
        if (s.vlCounted != null) ...[
          line(Strings.cashCounted, Numbers.money(s.vlCounted)),
          line(
            Strings.cashDifference,
            Numbers.money(s.vlDifference),
            bold: true,
            color: (s.vlDifference ?? 0) == 0
                ? AppColors.success
                : AppColors.danger,
          ),
        ],
      ],
    );
  }
}

class _CashAccounts extends StatelessWidget {
  const _CashAccounts({required this.accounts});

  final List<CashAccount> accounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinSectionTitle(Strings.cashAccounts),
            if (accounts.isEmpty)
              const Text(
                Strings.cashNoCashAccount,
                style: TextStyle(color: AppColors.muted),
              ),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  a.isFree ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: a.isFree ? AppColors.muted : AppColors.success,
                ),
                title: Text(
                  a.vcName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  a.isFree
                      ? Strings.cashFree
                      : Strings.cashWith(a.vcUser ?? ''),
                ),
                trailing: Text(
                  Numbers.money(a.vlBalance),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.sessions});

  final List<CashSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinSectionTitle(Strings.cashHistory),
            if (sessions.isEmpty)
              const Text(
                Strings.cashNoHistory,
                style: TextStyle(color: AppColors.muted),
              ),
            for (final s in sessions)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${s.vcAccount} · ${s.vcUser}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  Strings.cashClosedAt(Dates.formatTime(s.dhClose)),
                ),
                trailing: Text(
                  Numbers.money(s.vlDifference),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: (s.vlDifference ?? 0) == 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                children: [_SessionSummary(session: s)],
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenCashDialog extends StatefulWidget {
  const _OpenCashDialog({required this.accounts});

  final List<CashAccount> accounts;

  @override
  State<_OpenCashDialog> createState() => _OpenCashDialogState();
}

class _OpenCashDialogState extends State<_OpenCashDialog> {
  final _value = TextEditingController();
  late int? _account = widget.accounts.isEmpty
      ? null
      : widget.accounts.first.nrAccount;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.cashOpenTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _account,
              decoration: const InputDecoration(labelText: Strings.cashAccount),
              items: [
                for (final a in widget.accounts)
                  DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
              ],
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppNumberField(
              label: Strings.cashOpenValue,
              controller: _value,
              prefixText: 'R\$ ',
              helper: Strings.cashOpenValueHelper,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _account == null
              ? null
              : () => Navigator.of(context).pop({
                  'nr_account': _account,
                  'vl_open': ?Numbers.parse(_value.text),
                }),
          child: const Text(Strings.cashOpenAction),
        ),
      ],
    );
  }
}

class _CloseCashDialog extends StatefulWidget {
  const _CloseCashDialog({required this.session});

  final CashSession session;

  @override
  State<_CloseCashDialog> createState() => _CloseCashDialogState();
}

class _CloseCashDialogState extends State<_CloseCashDialog> {
  late final _counted = TextEditingController(
    text: Numbers.toField(widget.session.vlExpected),
  );

  @override
  void initState() {
    super.initState();
    _counted.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counted = Numbers.parse(_counted.text);
    final diff = counted == null ? null : counted - widget.session.vlExpected;
    return AlertDialog(
      title: const Text(Strings.cashCloseTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${Strings.cashExpected}: '
              '${Numbers.money(widget.session.vlExpected)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            AppNumberField(
              label: Strings.cashCounted,
              controller: _counted,
              prefixText: 'R\$ ',
              autofocus: true,
            ),
            if (diff != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${Strings.cashDifference}: ${Numbers.money(diff)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: diff.abs() < 0.005
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: counted == null || counted < 0
              ? null
              : () => Navigator.of(context).pop(counted),
          child: const Text(Strings.cashCloseAction),
        ),
      ],
    );
  }
}

/// Transferencia, sangria ou suprimento. Devolve o JSON de fin_transfer_save.
class TransferDialog extends StatefulWidget {
  const TransferDialog({
    super.key,
    required this.accounts,
    required this.type,
    this.cashAccount,
  });

  final List<FinAccount> accounts;
  final int type;

  /// Conta do meu caixa aberto (origem da sangria / destino do suprimento).
  final int? cashAccount;

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final _amount = TextEditingController();
  int? _from;
  int? _to;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    final others = [
      for (final a in widget.accounts)
        if (a.nrAccount != widget.cashAccount) a.nrAccount,
    ];
    final other = others.isEmpty ? null : others.first;
    switch (widget.type) {
      case TransferType.withdrawal:
        _from = widget.cashAccount;
        _to = other;
      case TransferType.supply:
        _from = other;
        _to = widget.cashAccount;
      default:
        _from = widget.accounts.isEmpty
            ? null
            : widget.accounts.first.nrAccount;
        _to = widget.accounts.length > 1 ? widget.accounts[1].nrAccount : null;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Widget _account(String label, int? value, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int?>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final a in widget.accounts)
            DropdownMenuItem(
              value: a.nrAccount,
              child: Text('${a.vcName} · ${AccountType.label(a.itType)}'),
            ),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final amount = Numbers.parse(_amount.text);
    final ok =
        _from != null && _to != null && _from != _to && (amount ?? 0) > 0;
    return AlertDialog(
      title: Text(
        widget.type == TransferType.transfer
            ? Strings.cashMoveTitle
            : TransferType.label(widget.type),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.cashMoveHint,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            _account(Strings.cashFrom, _from, (v) => setState(() => _from = v)),
            const SizedBox(height: AppSpacing.md),
            _account(Strings.cashTo, _to, (v) => setState(() => _to = v)),
            const SizedBox(height: AppSpacing.md),
            AppNumberField(
              label: Strings.finAmount,
              controller: _amount,
              prefixText: 'R\$ ',
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: ok
              ? () => Navigator.of(context).pop({
                  'vc_action': 'I',
                  'it_type': widget.type,
                  'nr_account_from': _from,
                  'nr_account_to': _to,
                  'vl_amount': amount,
                })
              : null,
          child: const Text(Strings.confirm),
        ),
      ],
    );
  }
}
