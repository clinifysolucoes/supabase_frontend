import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../application/clinical_record_controllers.dart';
import '../domain/clinical_record_models.dart';
import 'record_common.dart';

/// Aba Evolucao: tratamentos a fazer (orcamentos aprovados) e o historico
/// de atendimentos.
class EvolutionTab extends ConsumerWidget {
  const EvolutionTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RecordLoader(
    nrPatient: nrPatient,
    builder: (context, r) {
      Future<void> add([TreatmentItem? item]) => EvolutionDialog.show(
        context,
        nrPatient: nrPatient,
        pending: r.pendingItems,
        item: item,
      );
      return ListView(
        children: [
          RecordAlerts(alerts: r.alerts),
          if (r.pendingItems.isNotEmpty) ...[
            const RecordSectionTitle(title: Strings.treatmentToDo),
            Card(
              child: Column(
                children: [
                  for (final i in r.pendingItems)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.pending_actions_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(i.vcDescription),
                      subtitle: Text(
                        [
                          if (i.vcTooth != null && i.vcTooth!.isNotEmpty)
                            '${Strings.tooth} ${i.vcTooth}',
                          '${Strings.tabBudgets} ${i.nrBudget}',
                        ].join(' · '),
                      ),
                      trailing: r.canCreate
                          ? TextButton(
                              onPressed: () => add(i),
                              child: const Text(Strings.markDone),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          RecordSectionTitle(
            title: Strings.evolutionHistory,
            action: r.canCreate
                ? AppButton(
                    label: Strings.newEvolution,
                    icon: Icons.add_rounded,
                    onPressed: add,
                  )
                : null,
          ),
          if (r.evolutions.isEmpty)
            const AppEmptyState(
              icon: Icons.history_edu_rounded,
              title: Strings.noEvolution,
              subtitle: Strings.noEvolutionHint,
            ),
          for (final e in r.evolutions)
            _EvolutionCard(
              evolution: e,
              onDelete: r.canUpdate
                  ? () async {
                      final ok = await AppConfirmDialog.show(
                        context,
                        title: Strings.deleteEvolution,
                        message: Strings.deleteEvolutionConfirm,
                        confirmLabel: Strings.remove,
                      );
                      if (!ok || !context.mounted) return;
                      await runRecordAction(
                        context,
                        () => ref
                            .read(clinicalRecordActionsProvider)
                            .deleteEvolution(nrPatient, e.nrEvolution),
                        Strings.evolutionDeleted,
                      );
                    }
                  : null,
            ),
        ],
      );
    },
  );
}

class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.evolution, this.onDelete});

  final ClinicalEvolution evolution;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final e = evolution;
    final theme = Theme.of(context);
    final meta = [
      if (e.vcProfessional != null) e.vcProfessional!,
      if (e.vcTooth != null && e.vcTooth!.isNotEmpty)
        '${Strings.tooth} ${e.vcTooth}',
      if (e.vcProcedure != null) e.vcProcedure!,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  Dates.formatTime(e.dhEvolution),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (e.nrBudget != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    Strings.budgetItemDone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    tooltip: Strings.remove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (meta.isNotEmpty)
              Text(
                meta.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(e.vcText),
            if (e.vcUser != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '${Strings.recordedBy} ${e.vcUser}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nova evolucao (opcionalmente realizando um item de orcamento aprovado).
class EvolutionDialog extends ConsumerStatefulWidget {
  const EvolutionDialog({
    super.key,
    required this.nrPatient,
    required this.pending,
    this.item,
  });

  final int nrPatient;
  final List<TreatmentItem> pending;
  final TreatmentItem? item;

  static Future<void> show(
    BuildContext context, {
    required int nrPatient,
    required List<TreatmentItem> pending,
    TreatmentItem? item,
  }) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        EvolutionDialog(nrPatient: nrPatient, pending: pending, item: item),
  );

  @override
  ConsumerState<EvolutionDialog> createState() => _EvolutionDialogState();
}

class _EvolutionDialogState extends ConsumerState<EvolutionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  late final _tooth = TextEditingController(text: widget.item?.vcTooth ?? '');
  late TreatmentItem? _item = widget.item;
  int? _nrProfessional;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _tooth.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(clinicalRecordActionsProvider)
          .addEvolution(widget.nrPatient, {
            'vc_text': _text.text.trim(),
            'vc_tooth': _tooth.text.trim(),
            'nr_professional': ?_nrProfessional,
            'nr_budget': ?_item?.nrBudget,
            'nr_item': ?_item?.nrItem,
          });
      if (!mounted) return;
      AppSnack.success(context, Strings.evolutionSaved);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final professionals = ref
        .watch(professionalsProvider)
        .valueOrNull
        ?.professionals
        .where((p) => p.isActive)
        .toList();
    return AlertDialog(
      title: const Text(Strings.newEvolution),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.pending.isNotEmpty) ...[
                  DropdownButtonFormField<TreatmentItem?>(
                    initialValue: _item,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: Strings.budgetItemRealized,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(Strings.notInformed),
                      ),
                      for (final i in widget.pending)
                        DropdownMenuItem(
                          value: i,
                          child: Text(i.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _item = v;
                      if (v?.vcTooth != null && _tooth.text.isEmpty) {
                        _tooth.text = v!.vcTooth!;
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                DropdownButtonFormField<int?>(
                  initialValue: _nrProfessional,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: Strings.professional,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(Strings.notInformed),
                    ),
                    for (final p in professionals ?? const [])
                      DropdownMenuItem(
                        value: p.nrProfessional,
                        child: Text(p.vcName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _nrProfessional = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.toothOrRegion,
                  controller: _tooth,
                  maxLength: 40,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.evolutionText,
                  controller: _text,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 4000,
                  autofocus: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? Strings.required : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: Strings.cancel,
          variant: AppButtonVariant.text,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(label: Strings.save, loading: _saving, onPressed: _save),
      ],
    );
  }
}
