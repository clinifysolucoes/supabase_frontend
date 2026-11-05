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
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import '../domain/phase4_models.dart';

/// Contas recorrentes (regras) de A pagar ou A receber: lista, nova,
/// alterar e encerrar. Os lancamentos de cada mes o banco gera sozinho.
class RecurrencesDialog extends ConsumerStatefulWidget {
  const RecurrencesDialog({super.key, required this.kind});

  final int kind;

  static Future<void> show(BuildContext context, int kind) => showDialog<void>(
    context: context,
    builder: (_) => RecurrencesDialog(kind: kind),
  );

  @override
  ConsumerState<RecurrencesDialog> createState() => _RecurrencesDialogState();
}

class _RecurrencesDialogState extends ConsumerState<RecurrencesDialog> {
  bool _showEnded = false;

  Future<void> _open([FinRecurrence? r]) async {
    final catalog = await ref.read(financeCatalogProvider.future);
    if (!mounted) return;
    await RecurrenceFormDialog.show(
      context,
      kind: widget.kind,
      catalog: catalog,
      recurrence: r,
      readOnly:
          r != null &&
          (!r.isActive || !ref.read(canUpdateProvider(ScreenCodes.finance))),
    );
  }

  Future<void> _stop(FinRecurrence r) async {
    if (!await AppConfirmDialog.show(
          context,
          title: Strings.recurrenceStop,
          message: Strings.recurrenceStopConfirm,
        ) ||
        !mounted) {
      return;
    }
    try {
      await ref.read(financeActionsProvider).cash('fin_recurrence_save', {
        'vc_action': 'CANCEL',
        'nr_recurrence': r.nrRecurrence,
      });
      if (mounted) AppSnack.success(context, Strings.recurrenceStopped);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (kind: widget.kind, includeInactive: _showEnded);
    final async = ref.watch(recurrencesProvider(key));
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));
    return Dialog(
      insetPadding: EdgeInsets.all(
        context.isMobile ? AppSpacing.sm : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Strings.recurrences,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (canCreate)
                    AppButton(
                      label: Strings.recurrenceNew,
                      icon: Icons.add_rounded,
                      expanded: false,
                      onPressed: _open,
                    ),
                  FilterChip(
                    label: const Text(Strings.recurrenceShowEnded),
                    selected: _showEnded,
                    onSelected: (v) => setState(() => _showEnded = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppEmptyState.error(
                    message: describeError(e),
                    onRetry: () => ref.invalidate(recurrencesProvider(key)),
                  ),
                  data: (list) => list.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.event_repeat_rounded,
                          title: Strings.recurrenceNone,
                          subtitle: Strings.recurrenceNoneHint,
                        )
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => _RecurrenceTile(
                            recurrence: list[i],
                            onTap: () => _open(list[i]),
                            onStop: canUpdate && list[i].isActive
                                ? () => _stop(list[i])
                                : null,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceTile extends StatelessWidget {
  const _RecurrenceTile({
    required this.recurrence,
    required this.onTap,
    this.onStop,
  });

  final FinRecurrence recurrence;
  final VoidCallback onTap;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final r = recurrence;
    final when = [
      Strings.recurrenceSummary(
        r.itDay,
        r.dtNext == null ? null : Dates.format(r.dtNext),
      ),
      if (r.dtEnd != null) Strings.recurrenceEndsOn(Dates.format(r.dtEnd)),
      ?r.vcCategory,
      ?r.counterpart,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        Icons.event_repeat_rounded,
        color: r.isActive ? AppColors.primary : AppColors.muted,
      ),
      title: Text(
        r.vcDescription,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          decoration: r.isActive ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        r.isActive
            ? '$when\n${Strings.recurrenceCounts(r.qtOpen, r.qtPaid)}'
            : '$when\n${Strings.recurrenceEnded}',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Numbers.money(r.vlAmount),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (onStop != null)
            IconButton(
              tooltip: Strings.recurrenceStop,
              icon: const Icon(Icons.stop_circle_outlined),
              color: AppColors.danger,
              onPressed: onStop,
            ),
        ],
      ),
    );
  }
}

/// Nova conta recorrente ou alteracao (os futuros em aberto acompanham).
class RecurrenceFormDialog extends ConsumerStatefulWidget {
  const RecurrenceFormDialog({
    super.key,
    required this.kind,
    required this.catalog,
    this.recurrence,
    this.readOnly = false,
  });

  final int kind;
  final FinCatalog catalog;
  final FinRecurrence? recurrence;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    required int kind,
    required FinCatalog catalog,
    FinRecurrence? recurrence,
    bool readOnly = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => RecurrenceFormDialog(
          kind: kind,
          catalog: catalog,
          recurrence: recurrence,
          readOnly: readOnly,
        ),
      ) ??
      false;

  @override
  ConsumerState<RecurrenceFormDialog> createState() =>
      _RecurrenceFormDialogState();
}

class _RecurrenceFormDialogState extends ConsumerState<RecurrenceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final FinRecurrence? _r = widget.recurrence;
  late final _description = TextEditingController(text: _r?.vcDescription);
  late final _amount = TextEditingController(
    text: _r == null ? '' : Numbers.toField(_r.vlAmount),
  );
  late final _day = TextEditingController(
    text: '${_r?.itDay ?? DateTime.now().day}',
  );
  late final _start = TextEditingController(
    text: Dates.toField(_r?.dtStart ?? DateTime.now()),
  );
  late final _end = TextEditingController(
    text: _r?.dtEnd == null ? '' : Dates.toField(_r!.dtEnd!),
  );
  late final _notes = TextEditingController(text: _r?.vcNotes);
  late int? _category = _r?.nrCategory;
  late int? _account = _r?.nrAccount;
  late int? _supplier = _r?.nrSupplier;
  late int? _method = _r?.itPaymentMethod;
  late bool _noEnd = _r?.dtEnd == null;
  bool _saving = false;

  bool get _isNew => _r == null;

  @override
  void dispose() {
    for (final c in [_description, _amount, _day, _start, _end, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _dateValidator(String? v) =>
      Dates.parseField(v) == null ? Strings.invalidDate : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      AppSnack.error(context, Strings.finChooseCategory);
      return;
    }
    setState(() => _saving = true);
    final end = _noEnd ? null : Dates.parseField(_end.text);
    final notes = _notes.text.trim();
    try {
      final r = await ref
          .read(financeActionsProvider)
          .cash('fin_recurrence_save', {
            'vc_action': _isNew ? 'I' : 'U',
            if (!_isNew) 'nr_recurrence': _r!.nrRecurrence,
            if (_isNew) 'it_kind': widget.kind,
            if (_isNew) 'dt_start': Dates.toIso(Dates.parseField(_start.text)!),
            'nr_category': _category,
            'nr_account': _account,
            if (widget.kind == EntryKind.payable) 'nr_supplier': _supplier,
            'vc_description': _description.text.trim(),
            'vl_amount': Numbers.parse(_amount.text),
            'it_day': int.tryParse(_day.text),
            'it_payment_method': _method,
            'dt_end': end == null ? null : Dates.toIso(end),
            'vc_notes': notes.isEmpty ? null : notes,
          });
      if (!mounted) return;
      AppSnack.success(
        context,
        Strings.recurrenceSaved((r['qt_created'] as num?)?.toInt() ?? 0),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.catalog;
    final enabled = !widget.readOnly && !_saving;
    final categories = [
      for (final x in c.categories)
        if (x.itKind == widget.kind &&
            (x.isActive || x.nrCategory == _category))
          x,
    ];
    Widget pair(Widget a, Widget b) => context.isMobile
        ? Column(
            children: [
              a,
              const SizedBox(height: AppSpacing.md),
              b,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: b),
            ],
          );
    return AlertDialog(
      title: Text(_isNew ? Strings.recurrenceNew : Strings.recurrenceEdit),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isNew
                      ? Strings.recurrenceFormHint
                      : Strings.recurrenceChangedHint,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: '${Strings.finDescription} *',
                  controller: _description,
                  enabled: enabled,
                  maxLength: 140,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? Strings.required : null,
                ),
                pair(
                  AppNumberField(
                    label: '${Strings.finAmountEach} *',
                    controller: _amount,
                    prefixText: 'R\$ ',
                    enabled: enabled,
                    required: true,
                    positive: true,
                  ),
                  AppNumberField(
                    label: '${Strings.recurrenceDay} *',
                    controller: _day,
                    decimals: 0,
                    enabled: enabled,
                    validator: (v) {
                      final d = int.tryParse(v ?? '') ?? 0;
                      return d < 1 || d > 31 ? '1 – 31' : null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                pair(
                  AppTextField(
                    label: '${Strings.recurrenceStart} *',
                    controller: _start,
                    mask: MaskType.date,
                    enabled: enabled && _isNew,
                    keyboardType: TextInputType.number,
                    validator: _dateValidator,
                  ),
                  _noEnd
                      ? CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(Strings.recurrenceNoEnd),
                          value: true,
                          onChanged: enabled
                              ? (_) => setState(() => _noEnd = false)
                              : null,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: Strings.recurrenceEnd,
                                controller: _end,
                                mask: MaskType.date,
                                enabled: enabled,
                                keyboardType: TextInputType.number,
                                validator: _dateValidator,
                              ),
                            ),
                            IconButton(
                              tooltip: Strings.recurrenceNoEnd,
                              icon: const Icon(Icons.all_inclusive_rounded),
                              onPressed: enabled
                                  ? () => setState(() => _noEnd = true)
                                  : null,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: '${Strings.finCategory} *',
                  ),
                  items: [
                    for (final x in categories)
                      DropdownMenuItem(
                        value: x.nrCategory,
                        child: Text(x.vcName),
                      ),
                  ],
                  onChanged: enabled
                      ? (v) => setState(() => _category = v)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                pair(
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _account,
                    decoration: const InputDecoration(
                      labelText: Strings.finAccount,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-')),
                      for (final a in c.payableAccounts)
                        DropdownMenuItem(
                          value: a.nrAccount,
                          child: Text(a.vcName),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _account = v)
                        : null,
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
                        DropdownMenuItem(
                          value: m,
                          child: Text(PaymentMethod.label(m)),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _method = v)
                        : null,
                  ),
                ),
                if (widget.kind == EntryKind.payable) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _supplier,
                    decoration: const InputDecoration(
                      labelText: Strings.finSupplier,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-')),
                      for (final s in c.suppliers)
                        if (s.isActive || s.nrSupplier == _supplier)
                          DropdownMenuItem(
                            value: s.nrSupplier,
                            child: Text(s.vcName),
                          ),
                    ],
                    onChanged: enabled
                        ? (v) => setState(() => _supplier = v)
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: Strings.notes,
                  controller: _notes,
                  enabled: enabled,
                  maxLength: 500,
                  maxLines: 2,
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
