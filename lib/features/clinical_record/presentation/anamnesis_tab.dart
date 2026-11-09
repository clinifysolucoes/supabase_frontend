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
import '../application/clinical_record_controllers.dart';
import '../domain/clinical_record_models.dart';
import 'record_common.dart';

/// Aba Anamnese: alertas, preencher a partir de um modelo e historico.
class AnamnesisTab extends ConsumerWidget {
  const AnamnesisTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RecordLoader(
    nrPatient: nrPatient,
    builder: (context, r) => ListView(
      children: [
        RecordAlerts(alerts: r.alerts),
        RecordSectionTitle(
          title: Strings.anamnesisHistory,
          action: r.canCreate
              ? AppButton(
                  expanded: false,
                  label: Strings.fillAnamnesis,
                  icon: Icons.assignment_add,
                  onPressed: () => AnamnesisFillDialog.show(context, nrPatient),
                )
              : null,
        ),
        if (r.anamneses.isEmpty)
          const AppEmptyState(
            icon: Icons.assignment_outlined,
            title: Strings.noAnamnesis,
            subtitle: Strings.noAnamnesisHint,
          ),
        for (final (i, a) in r.anamneses.indexed)
          _AnamnesisCard(
            anamnesis: a,
            initiallyExpanded: i == 0,
            onDelete: r.canUpdate
                ? () async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      title: Strings.deleteAnamnesis,
                      message: Strings.deleteAnamnesisConfirm,
                      confirmLabel: Strings.remove,
                    );
                    if (!ok || !context.mounted) return;
                    await runRecordAction(
                      context,
                      () => ref
                          .read(clinicalRecordActionsProvider)
                          .deleteAnamnesis(nrPatient, a.nrAnamnesis),
                      Strings.anamnesisDeleted,
                    );
                  }
                : null,
          ),
      ],
    ),
  );
}

class _AnamnesisCard extends StatelessWidget {
  const _AnamnesisCard({
    required this.anamnesis,
    required this.initiallyExpanded,
    this.onDelete,
  });

  final PatientAnamnesis anamnesis;
  final bool initiallyExpanded;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final a = anamnesis;
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        title: Text(
          a.vcModel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            Dates.format(a.dtFilled),
            if (a.vcUser != null) a.vcUser!,
            if (a.alertCount > 0) Strings.alertCount(a.alertCount),
          ].join(' · '),
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                tooltip: Strings.remove,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (final q in a.answers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    q.idAlert
                        ? Icons.warning_amber_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: q.idAlert ? AppColors.danger : AppColors.muted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(q.vcQuestion)),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      _answerText(q),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: q.idAlert
                            ? AppColors.danger
                            : (q.isAnswered ? AppColors.ink : AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (a.vcNotes != null && a.vcNotes!.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${Strings.notes}: ${a.vcNotes}'),
            ),
          ],
        ],
      ),
    );
  }

  static String _answerText(AnamnesisAnswer q) {
    final yn = q.idYes == null ? null : (q.idYes! ? Strings.yes : Strings.no);
    final parts = [
      ?yn,
      if (q.vcText != null && q.vcText!.isNotEmpty) q.vcText!,
    ];
    return parts.isEmpty ? Strings.notAnswered : parts.join(' · ');
  }
}

/// Preenche uma anamnese: escolhe o modelo e responde as perguntas.
class AnamnesisFillDialog extends ConsumerStatefulWidget {
  const AnamnesisFillDialog({super.key, required this.nrPatient});

  final int nrPatient;

  static Future<void> show(BuildContext context, int nrPatient) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AnamnesisFillDialog(nrPatient: nrPatient),
  );

  @override
  ConsumerState<AnamnesisFillDialog> createState() =>
      _AnamnesisFillDialogState();
}

class _AnamnesisFillDialogState extends ConsumerState<AnamnesisFillDialog> {
  AnamnesisModel? _model;
  final Map<int, bool?> _yes = {};
  final Map<int, TextEditingController> _text = {};
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  TextEditingController _ctl(int q) =>
      _text.putIfAbsent(q, TextEditingController.new);

  Future<void> _save() async {
    final m = _model;
    if (m == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(clinicalRecordActionsProvider).fillAnamnesis(
        widget.nrPatient,
        {
          'nr_model': m.nrModel,
          'vc_notes': _notes.text.trim(),
          'answers': [
            for (final q in m.questions)
              {
                'nr_question': q.nrQuestion,
                'id_yes': _yes[q.nrQuestion],
                'vc_text': _text[q.nrQuestion]?.text.trim(),
              },
          ],
        },
      );
      if (!mounted) return;
      AppSnack.success(context, Strings.anamnesisSaved);
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
    final models = ref.watch(anamnesisModelsProvider(false));
    return AlertDialog(
      title: const Text(Strings.fillAnamnesis),
      content: SizedBox(
        width: 640,
        child: models.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(describeError(e)),
          data: (list) {
            _model ??= list.models.firstOrNull;
            final m = _model;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: m?.nrModel,
                    decoration: const InputDecoration(
                      labelText: Strings.anamnesisModel,
                    ),
                    items: [
                      for (final x in list.models)
                        DropdownMenuItem(
                          value: x.nrModel,
                          child: Text(x.vcName),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _model = list.models.firstWhere((x) => x.nrModel == v);
                      _yes.clear();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (m != null)
                    for (final q in m.questions) _question(q),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.notes,
                    controller: _notes,
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 2000,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        AppButton(
          expanded: false,
          label: Strings.cancel,
          variant: AppButtonVariant.text,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          expanded: false,
          label: Strings.save,
          loading: _saving,
          onPressed: _model == null ? null : _save,
        ),
      ],
    );
  }

  Widget _question(AnamnesisQuestion q) {
    final yes = _yes[q.nrQuestion];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (q.idAlert)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                ),
              Expanded(
                child: Text(
                  q.vcQuestion,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (q.type.hasYesNo)
                SegmentedButton<bool>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text(Strings.yes)),
                    ButtonSegment(value: false, label: Text(Strings.no)),
                  ],
                  selected: {?yes},
                  onSelectionChanged: (s) =>
                      setState(() => _yes[q.nrQuestion] = s.firstOrNull),
                ),
            ],
          ),
          if (q.type == QuestionType.text ||
              (q.type == QuestionType.yesNoDetail && yes == true))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: AppTextField(
                label: q.type == QuestionType.text
                    ? Strings.answer
                    : Strings.answerDetail,
                controller: _ctl(q.nrQuestion),
                maxLength: 1000,
              ),
            ),
        ],
      ),
    );
  }
}
