import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/clinical_record_controllers.dart';
import '../domain/clinical_record_models.dart';

/// Configuracoes > Prontuario: modelos de anamnese da filial.
class AnamnesisModelsSection extends ConsumerWidget {
  const AnamnesisModelsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(anamnesisModelsProvider(true));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(describeError(e)),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Strings.anamnesisModels,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          Strings.anamnesisModelsHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (list.canUpdate)
                    AppButton(
                      label: Strings.newModel,
                      icon: Icons.add_rounded,
                      onPressed: () => AnamnesisModelDialog.show(context),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final m in list.models)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.assignment_outlined,
                    color: m.isActive ? AppColors.primary : AppColors.muted,
                  ),
                  title: Text(m.vcName),
                  subtitle: Text(
                    [
                      Strings.questionCount(m.questions.length),
                      if (m.vcSpecialty != null) m.vcSpecialty!,
                      if (!m.isActive) Strings.statusInactive,
                    ].join(' · '),
                  ),
                  trailing: list.canUpdate
                      ? const Icon(Icons.edit_outlined)
                      : null,
                  onTap: list.canUpdate
                      ? () => AnamnesisModelDialog.show(context, model: m)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Novo modelo ou edicao: nome, situacao e perguntas.
class AnamnesisModelDialog extends ConsumerStatefulWidget {
  const AnamnesisModelDialog({super.key, this.model});

  final AnamnesisModel? model;

  static Future<void> show(BuildContext context, {AnamnesisModel? model}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AnamnesisModelDialog(model: model),
      );

  @override
  ConsumerState<AnamnesisModelDialog> createState() =>
      _AnamnesisModelDialogState();
}

class _Row {
  _Row(AnamnesisQuestion q)
    : text = TextEditingController(text: q.vcQuestion),
      type = q.type,
      alert = q.idAlert;

  final TextEditingController text;
  QuestionType type;
  bool alert;
}

class _AnamnesisModelDialogState extends ConsumerState<AnamnesisModelDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.model?.vcName ?? '');
  late bool _active = widget.model?.isActive ?? true;
  late final List<_Row> _rows = [
    for (final q in widget.model?.questions ?? const <AnamnesisQuestion>[])
      _Row(q),
    if (widget.model == null) _Row(const AnamnesisQuestion(vcQuestion: '')),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.text.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_rows.isEmpty) {
      AppSnack.error(context, Strings.questionsRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(clinicalRecordActionsProvider)
          .saveModel(
            nrModel: widget.model?.nrModel,
            fields: {
              'vc_name': _name.text.trim(),
              if (widget.model != null) 'it_status': _active ? 1 : 90,
              'questions': [
                for (final r in _rows)
                  AnamnesisQuestion(
                    vcQuestion: r.text.text.trim(),
                    type: r.type,
                    idAlert: r.alert,
                  ).toJson(),
              ],
            },
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.savedSuccess);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  void _move(int i, int d) => setState(() {
    final r = _rows.removeAt(i);
    _rows.insert(i + d, r);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.model == null ? Strings.newModel : Strings.editModel),
    content: SizedBox(
      width: 720,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: Strings.modelName,
                controller: _name,
                maxLength: 80,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? Strings.required : null,
              ),
              if (widget.model != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(Strings.statusActive),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.questions,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text('${i + 1}.'),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: AppTextField(
                          label: Strings.question,
                          controller: r.text,
                          maxLength: 200,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? Strings.required
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<QuestionType>(
                          initialValue: r.type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: Strings.answerType,
                          ),
                          items: [
                            for (final t in QuestionType.values)
                              DropdownMenuItem(
                                value: t,
                                child: Text(Strings.questionType(t.code)),
                              ),
                          ],
                          onChanged: (v) => setState(() => r.type = v!),
                        ),
                      ),
                      Tooltip(
                        message: Strings.questionAlertHint,
                        child: Checkbox(
                          value: r.alert && r.type.hasYesNo,
                          onChanged: r.type.hasYesNo
                              ? (v) => setState(() => r.alert = v ?? false)
                              : null,
                        ),
                      ),
                      IconButton(
                        tooltip: Strings.moveUp,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        onPressed: i == 0 ? null : () => _move(i, -1),
                      ),
                      IconButton(
                        tooltip: Strings.moveDown,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                        ),
                        onPressed: i == _rows.length - 1
                            ? null
                            : () => _move(i, 1),
                      ),
                      IconButton(
                        tooltip: Strings.remove,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _rows.removeAt(i).text.dispose()),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _rows.add(
                      _Row(const AnamnesisQuestion(vcQuestion: '')),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(Strings.addQuestion),
                ),
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
