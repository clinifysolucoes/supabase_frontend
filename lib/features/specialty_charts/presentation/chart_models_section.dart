import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/chart_repository.dart';
import '../domain/chart_models.dart';

/// Configuracoes > Prontuario: modelos de ficha por especialidade.
class ChartModelsSection extends ConsumerWidget {
  const ChartModelsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(chartModelsProvider(true));
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
                          Strings.chartModels,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          Strings.chartModelsHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (list.canUpdate)
                    AppButton(
                      expanded: false,
                      label: Strings.newModel,
                      icon: Icons.add_rounded,
                      onPressed: () => ChartModelDialog.show(context),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final m in list.models)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.fact_check_outlined,
                    color: m.isActive ? AppColors.primary : AppColors.muted,
                  ),
                  title: Text(m.vcName),
                  subtitle: Text(
                    [
                      Strings.fieldCount(
                        m.fields
                            .where((f) => f.type != ChartFieldType.section)
                            .length,
                      ),
                      if (m.idPerTooth) Strings.chartPerTooth,
                      if (!m.isActive) Strings.statusInactive,
                    ].join(' · '),
                  ),
                  trailing: list.canUpdate
                      ? const Icon(Icons.edit_outlined)
                      : null,
                  onTap: list.canUpdate
                      ? () => ChartModelDialog.show(context, model: m)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow {
  _FieldRow(ChartField f)
    : label = TextEditingController(text: f.vcLabel),
      options = TextEditingController(text: f.options.join(' | ')),
      unit = TextEditingController(text: f.vcUnit ?? ''),
      type = f.type,
      required = f.idRequired;

  final TextEditingController label;
  final TextEditingController options;
  final TextEditingController unit;
  ChartFieldType type;
  bool required;
  final key = UniqueKey();

  void dispose() {
    label.dispose();
    options.dispose();
    unit.dispose();
  }

  List<String> get optionList => options.text
      .split(RegExp(r'[|\n]'))
      .map((o) => o.trim())
      .where((o) => o.isNotEmpty)
      .toList();

  Map<String, dynamic> toJson() => ChartField(
    nrField: 0,
    vcLabel: label.text.trim(),
    type: type,
    options: optionList,
    vcUnit: unit.text.trim(),
    idRequired: required && type != ChartFieldType.section,
  ).toJson();
}

/// Novo modelo ou edicao: nome, por dente, situacao e campos.
class ChartModelDialog extends ConsumerStatefulWidget {
  const ChartModelDialog({super.key, this.model});

  final ChartModel? model;

  static Future<void> show(BuildContext context, {ChartModel? model}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChartModelDialog(model: model),
      );

  @override
  ConsumerState<ChartModelDialog> createState() => _ChartModelDialogState();
}

class _ChartModelDialogState extends ConsumerState<ChartModelDialog> {
  late final _name = TextEditingController(text: widget.model?.vcName ?? '');
  late bool _perTooth = widget.model?.idPerTooth ?? false;
  late bool _active = widget.model?.isActive ?? true;
  late final List<_FieldRow> _rows = [
    for (final f
        in widget.model?.fields ??
            const [
              ChartField(
                nrField: 1,
                vcLabel: '',
                type: ChartFieldType.shortText,
              ),
            ])
      _FieldRow(f),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppSnack.error(context, Strings.chartModelNameRequired);
      return;
    }
    final rows = [
      for (final r in _rows)
        if (r.label.text.trim().isNotEmpty) r,
    ];
    if (rows.isEmpty) {
      AppSnack.error(context, Strings.chartFieldsRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(chartRepositoryProvider).saveModel(widget.model?.nrModel, {
        'vc_name': _name.text.trim(),
        'id_per_tooth': _perTooth,
        if (widget.model != null) 'it_status': _active ? 1 : 90,
        'fields': [for (final r in rows) r.toJson()],
      });
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

  Widget _row(int i) {
    final r = _rows[i];
    return Card(
      key: r.key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: Strings.chartFieldLabel,
                    controller: r.label,
                    maxLength: 120,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<ChartFieldType>(
                    isExpanded: true,
                    initialValue: r.type,
                    decoration: const InputDecoration(
                      labelText: Strings.chartFieldType,
                      isDense: true,
                    ),
                    items: [
                      for (final t in ChartFieldType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (t) => setState(() => r.type = t ?? r.type),
                  ),
                ),
                IconButton(
                  tooltip: Strings.moveUp,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: i == 0
                      ? null
                      : () => setState(() {
                          _rows.insert(i - 1, _rows.removeAt(i));
                        }),
                ),
                IconButton(
                  tooltip: Strings.remove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: _rows.length == 1
                      ? null
                      : () => setState(() => _rows.removeAt(i).dispose()),
                ),
              ],
            ),
            if (r.type == ChartFieldType.choice)
              AppTextField(
                label: Strings.chartFieldOptions,
                helperText: Strings.chartFieldOptionsHint,
                controller: r.options,
                maxLines: 2,
              ),
            if (r.type == ChartFieldType.number)
              SizedBox(
                width: 160,
                child: AppTextField(
                  label: Strings.chartFieldUnit,
                  controller: r.unit,
                  maxLength: 20,
                ),
              ),
            if (r.type != ChartFieldType.section)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(Strings.chartFieldRequired),
                value: r.required,
                onChanged: (v) => setState(() => r.required = v ?? false),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.model == null ? Strings.newModel : widget.model!.vcName),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: '${Strings.chartModelName} *',
              controller: _name,
              maxLength: 80,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.chartPerTooth),
              subtitle: const Text(Strings.chartPerToothHint),
              value: _perTooth,
              onChanged: (v) => setState(() => _perTooth = v),
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
              Strings.chartFields,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (widget.model != null)
              const Text(
                Strings.chartFieldsKeepHint,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _rows.length; i++) _row(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text(Strings.chartAddField),
                onPressed: () => setState(
                  () => _rows.add(
                    _FieldRow(
                      const ChartField(
                        nrField: 0,
                        vcLabel: '',
                        type: ChartFieldType.shortText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text(Strings.cancel),
      ),
      AppButton(
        label: Strings.save,
        expanded: false,
        loading: _saving,
        onPressed: _save,
      ),
    ],
  );
}
