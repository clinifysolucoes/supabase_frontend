import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_pick.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/bank_models.dart';
import '../domain/finance_models.dart';
import 'finance_widgets.dart';

/// Conciliacao bancaria: importa o OFX do banco, mostra cada linha com as
/// sugestoes do sistema e concilia, lanca ou ignora.
class BankTab extends ConsumerWidget {
  const BankTab({super.key, this.pickOfx});

  /// Leitura do arquivo (os testes trocam).
  final Future<String?> Function()? pickOfx;

  Future<void> _import(BuildContext context, WidgetRef ref, int account) async {
    final text = await (pickOfx ?? () => FilePick.text(extensions: ['ofx']))();
    if (text == null || !context.mounted) return;
    final tx = OfxParser.parse(text);
    if (tx.isEmpty) {
      AppSnack.error(context, Strings.bankFileInvalid);
      return;
    }
    try {
      final r = await ref.read(financeActionsProvider).cash('fin_bank_import', {
        'nr_account': account,
        'lines': [for (final t in tx) t.toJson()],
      });
      if (context.mounted) {
        AppSnack.success(
          context,
          Strings.bankImported(
            (r['qt_new'] as num?)?.toInt() ?? 0,
            (r['qt_duplicated'] as num?)?.toInt() ?? 0,
            (r['qt_matched'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _reconcile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> fields,
  ) async {
    try {
      await ref.read(financeActionsProvider).cash('fin_bank_reconcile', fields);
      if (context.mounted) AppSnack.success(context, Strings.bankDone);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref, BankLine l) async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!context.mounted) return;
    final kind = l.vlAmount > 0 ? EntryKind.receivable : EntryKind.payable;
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CreateDialog(
        line: l,
        categories: [
          for (final c in catalog.categoriesOf(kind))
            if (c.isActive) c,
        ],
      ),
    );
    if (r == null || !context.mounted) return;
    await _reconcile(context, ref, {
      'vc_action': 'CREATE',
      'nr_line': l.nrLine,
      ...r,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref
        .watch(financeCatalogProvider)
        .valueOrNull
        ?.payableAccounts;
    final account = ref.watch(bankAccountProvider);
    final month = ref.watch(bankMonthProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));
    final async = ref.watch(bankLinesProvider);

    // primeira conta do tipo banco ja escolhida
    if (account == null && accounts != null && accounts.isNotEmpty) {
      final bank = accounts.firstWhere(
        (a) => a.itType == AccountType.bank,
        orElse: () => accounts.first,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(bankAccountProvider.notifier).state = bank.nrAccount,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: context.isMobile ? double.infinity : 240,
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: account,
                key: ValueKey(account),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: Strings.bankAccount,
                ),
                items: [
                  for (final a in accounts ?? const <FinAccount>[])
                    DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
                ],
                onChanged: (v) =>
                    ref.read(bankAccountProvider.notifier).state = v,
              ),
            ),
            MonthSwitcher(
              month: month,
              onChanged: (m) => ref.read(bankMonthProvider.notifier).state = m,
            ),
            if (canCreate && account != null)
              AppButton(
                label: Strings.bankImport,
                icon: Icons.upload_file_rounded,
                expanded: false,
                onPressed: () => _import(context, ref, account),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(bankLinesProvider),
            ),
            data: (d) {
              if (d == null) {
                return const AppEmptyState(
                  icon: Icons.account_balance_rounded,
                  title: Strings.bankChooseAccount,
                );
              }
              return ListView(
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      FinKpiCard(label: Strings.bankBalance, value: d.vlBank),
                      _CountCard(
                        label: Strings.bankPending,
                        count: d.qtPending,
                        color: AppColors.warning,
                      ),
                      _CountCard(
                        label: Strings.bankMatched,
                        count: d.qtMatched,
                        color: AppColors.success,
                      ),
                      FinKpiCard(
                        label: Strings.bankUnmatched,
                        value: d.vlSystemUnmatched,
                        color: AppColors.muted,
                        caption: '${d.unmatched.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (d.lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        Strings.bankNone,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  for (final l in d.lines)
                    _LineCard(
                      line: l,
                      canCreate: canCreate,
                      canUpdate: canUpdate,
                      onMatch: (c) => _reconcile(context, ref, {
                        'vc_action': 'MATCH',
                        'nr_line': l.nrLine,
                        ...c.matchKey,
                      }),
                      onCreate: () => _create(context, ref, l),
                      onIgnore: () => _reconcile(context, ref, {
                        'vc_action': 'IGNORE',
                        'nr_line': l.nrLine,
                      }),
                      onUndo: () => _reconcile(context, ref, {
                        'vc_action': 'UNDO',
                        'nr_line': l.nrLine,
                      }),
                    ),
                  if (d.unmatched.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const FinSectionTitle(Strings.bankUnmatched),
                    for (final u in d.unmatched)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          u.isTransfer
                              ? Icons.swap_horiz_rounded
                              : Icons.receipt_long_outlined,
                          color: AppColors.muted,
                        ),
                        title: Text(u.vcDescription),
                        subtitle: Text(Dates.format(u.dtRef)),
                        trailing: SignedMoney(u.vlValue),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.isMobile ? double.infinity : 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.canCreate,
    required this.canUpdate,
    required this.onMatch,
    required this.onCreate,
    required this.onIgnore,
    required this.onUndo,
  });

  final BankLine line;
  final bool canCreate;
  final bool canUpdate;
  final ValueChanged<BankCandidate> onMatch;
  final VoidCallback onCreate;
  final VoidCallback onIgnore;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final color = l.isMatched
        ? AppColors.success
        : (l.isPending ? AppColors.warning : AppColors.muted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  l.isMatched
                      ? Icons.check_circle_rounded
                      : (l.isPending
                            ? Icons.help_outline_rounded
                            : Icons.block_rounded),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.vcMemo ?? l.vcFitid,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          Dates.format(l.dtPosted),
                          if (l.isMatched && l.vcMatched != null)
                            '→ ${l.vcMatched}',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SignedMoney(l.vlAmount, bold: true),
              ],
            ),
            if (l.isPending) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (l.candidates.isEmpty)
                    const Text(
                      Strings.bankNoSuggestion,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  for (final c in l.candidates)
                    ActionChip(
                      avatar: Icon(
                        c.isTransfer
                            ? Icons.swap_horiz_rounded
                            : Icons.link_rounded,
                        size: 16,
                      ),
                      label: Text(
                        '${Strings.bankMatch}: ${c.vcDescription} · '
                        '${Strings.bankSuggestion(Dates.format(c.dtRef), c.qtDays)}',
                      ),
                      onPressed: canUpdate ? () => onMatch(c) : null,
                    ),
                  if (canCreate)
                    TextButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(Strings.bankCreate),
                    ),
                  if (canUpdate)
                    TextButton(
                      onPressed: onIgnore,
                      child: const Text(Strings.bankIgnore),
                    ),
                ],
              ),
            ] else if (canUpdate)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onUndo,
                  child: const Text(Strings.bankUndo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({required this.line, required this.categories});

  final BankLine line;
  final List<FinCategory> categories;

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  late final _desc = TextEditingController(text: widget.line.vcMemo ?? '');
  int? _category;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.bankCreateTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(Dates.format(widget.line.dtPosted))),
                SignedMoney(widget.line.vlAmount, bold: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: Strings.finDescription,
              controller: _desc,
              maxLength: 140,
            ),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: '${Strings.finCategory} *',
              ),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c.nrCategory, child: Text(c.vcName)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Numbers.money(widget.line.vlAmount.abs()),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
          onPressed: _category == null
              ? null
              : () => Navigator.of(context).pop({
                  'nr_category': _category,
                  'vc_description': _desc.text.trim(),
                }),
          child: const Text(Strings.bankCreate),
        ),
      ],
    );
  }
}
