import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/clinical_record_controllers.dart';
import '../domain/clinical_record_models.dart';
import 'record_common.dart';

/// Cor da situacao no odontograma.
Color situationColor(ToothSituation s) => switch (s) {
  ToothSituation.existing => AppColors.primary,
  ToothSituation.toTreat => AppColors.danger,
  ToothSituation.done => AppColors.success,
};

/// Aba Odontograma: arcadas permanente/decidua (FDI); clicar no dente abre
/// as marcacoes dele.
class OdontogramTab extends ConsumerStatefulWidget {
  const OdontogramTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  ConsumerState<OdontogramTab> createState() => _OdontogramTabState();
}

class _OdontogramTabState extends ConsumerState<OdontogramTab> {
  bool _deciduous = false;

  @override
  Widget build(BuildContext context) => RecordLoader(
    nrPatient: widget.nrPatient,
    builder: (context, r) {
      void open(String tooth) => ToothDialog.show(
        context,
        nrPatient: widget.nrPatient,
        tooth: tooth,
        marks: r.marksOf(tooth),
        canCreate: r.canCreate,
        canUpdate: r.canUpdate,
      );
      final upper = _deciduous ? Teeth.deciduousUpper : Teeth.permanentUpper;
      final lower = _deciduous ? Teeth.deciduousLower : Teeth.permanentLower;
      return ListView(
        children: [
          RecordAlerts(alerts: r.alerts),
          Row(
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text(Strings.permanent)),
                  ButtonSegment(value: true, label: Text(Strings.deciduous)),
                ],
                selected: {_deciduous},
                onSelectionChanged: (s) => setState(() => _deciduous = s.first),
              ),
              const Spacer(),
              const _Legend(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    _Arch(teeth: upper, record: r, onTap: open),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: SizedBox(width: 600, child: Divider()),
                    ),
                    _Arch(teeth: lower, record: r, onTap: open),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const RecordSectionTitle(title: Strings.odontogramMarks),
          if (r.marks.isEmpty)
            const Text(
              Strings.noToothMarks,
              style: TextStyle(color: AppColors.muted),
            ),
          if (r.marks.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (final m in r.marks)
                    ListTile(
                      dense: true,
                      onTap: () => open(m.vcTooth),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: situationColor(m.situation),
                        child: Text(
                          m.vcTooth,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(markTitle(m)),
                      subtitle: Text(
                        [
                          m.situation.label,
                          Dates.format(m.dtMark),
                          if (m.vcNotes != null) m.vcNotes!,
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

String markTitle(ToothMark m) => m.vcFaces == null || m.vcFaces!.isEmpty
    ? m.condition.label
    : '${m.condition.label} (${m.vcFaces})';

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    children: [
      for (final s in ToothSituation.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 5, backgroundColor: situationColor(s)),
            const SizedBox(width: 4),
            Text(s.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ],
  );
}

class _Arch extends StatelessWidget {
  const _Arch({required this.teeth, required this.record, required this.onTap});

  final List<String> teeth;
  final PatientClinicalRecord record;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, t) in teeth.indexed) ...[
        if (i == teeth.length ~/ 2) const SizedBox(width: AppSpacing.md),
        _ToothButton(tooth: t, marks: record.marksOf(t), onTap: () => onTap(t)),
      ],
    ],
  );
}

class _ToothButton extends StatelessWidget {
  const _ToothButton({
    required this.tooth,
    required this.marks,
    required this.onTap,
  });

  final String tooth;
  final List<ToothMark> marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = marks.any(
      (m) =>
          m.condition == ToothCondition.missing &&
          m.situation != ToothSituation.toTreat,
    );
    final toTreat = marks.any((m) => m.situation == ToothSituation.toTreat);
    final border = toTreat
        ? AppColors.danger
        : (marks.isEmpty ? AppColors.line : AppColors.primary);
    return Tooltip(
      message: marks.isEmpty
          ? '${Strings.tooth} $tooth'
          : '${Strings.tooth} $tooth: ${marks.map(markTitle).join(', ')}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 36,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: missing ? AppColors.surface : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: border, width: marks.isEmpty ? 1 : 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tooth,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: missing ? AppColors.muted : AppColors.ink,
                  decoration: missing ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in marks.take(4))
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: situationColor(m.situation),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marcacoes de um dente: lista (alterar situacao / remover) e nova marcacao.
class ToothDialog extends ConsumerStatefulWidget {
  const ToothDialog({
    super.key,
    required this.nrPatient,
    required this.tooth,
    required this.marks,
    required this.canCreate,
    required this.canUpdate,
  });

  final int nrPatient;
  final String tooth;
  final List<ToothMark> marks;
  final bool canCreate;
  final bool canUpdate;

  static Future<void> show(
    BuildContext context, {
    required int nrPatient,
    required String tooth,
    required List<ToothMark> marks,
    required bool canCreate,
    required bool canUpdate,
  }) => showDialog(
    context: context,
    builder: (_) => ToothDialog(
      nrPatient: nrPatient,
      tooth: tooth,
      marks: marks,
      canCreate: canCreate,
      canUpdate: canUpdate,
    ),
  );

  @override
  ConsumerState<ToothDialog> createState() => _ToothDialogState();
}

class _ToothDialogState extends ConsumerState<ToothDialog> {
  ToothCondition _condition = ToothCondition.caries;
  ToothSituation _situation = ToothSituation.toTreat;
  final Set<String> _faces = {};
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _call(Future<void> Function() f, String ok) async {
    setState(() => _saving = true);
    try {
      await f();
      if (!mounted) return;
      AppSnack.success(context, ok);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  ClinicalRecordActions get _actions => ref.read(clinicalRecordActionsProvider);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${Strings.tooth} ${widget.tooth}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.marks.isEmpty)
                const Text(
                  Strings.noToothMarks,
                  style: TextStyle(color: AppColors.muted),
                ),
              for (final m in widget.marks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: situationColor(m.situation),
                  ),
                  title: Text(markTitle(m)),
                  subtitle: Text(
                    [
                      m.situation.label,
                      Dates.format(m.dtMark),
                      if (m.vcNotes != null) m.vcNotes!,
                    ].join(' · '),
                  ),
                  trailing: widget.canUpdate
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.situation != ToothSituation.done)
                              IconButton(
                                tooltip: Strings.markDone,
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => _call(
                                        () => _actions.saveMark(
                                          widget.nrPatient,
                                          nrMark: m.nrMark,
                                          fields: {
                                            'it_situation':
                                                ToothSituation.done.code,
                                          },
                                        ),
                                        Strings.savedSuccess,
                                      ),
                              ),
                            IconButton(
                              tooltip: Strings.remove,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: _saving
                                  ? null
                                  : () => _call(
                                      () => _actions.saveMark(
                                        widget.nrPatient,
                                        nrMark: m.nrMark,
                                        delete: true,
                                      ),
                                      Strings.toothMarkRemoved,
                                    ),
                            ),
                          ],
                        )
                      : null,
                ),
              if (widget.canCreate) ...[
                const Divider(),
                Text(
                  Strings.newToothMark,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<ToothCondition>(
                  initialValue: _condition,
                  decoration: const InputDecoration(
                    labelText: Strings.toothCondition,
                  ),
                  items: [
                    for (final c in ToothCondition.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) => setState(() => _condition = v!),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(Strings.toothFaces, style: theme.textTheme.bodySmall),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final f in Teeth.faces)
                      FilterChip(
                        label: Text(f),
                        tooltip: Strings.faceName(f),
                        selected: _faces.contains(f),
                        onSelected: (s) => setState(
                          () => s ? _faces.add(f) : _faces.remove(f),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ToothSituation>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in ToothSituation.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_situation},
                  onSelectionChanged: (s) =>
                      setState(() => _situation = s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.notes,
                  controller: _notes,
                  maxLength: 300,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: Strings.close,
          variant: AppButtonVariant.text,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        if (widget.canCreate)
          AppButton(
            label: Strings.addMark,
            loading: _saving,
            onPressed: () => _call(
              () => _actions.saveMark(
                widget.nrPatient,
                fields: {
                  'vc_tooth': widget.tooth,
                  'it_condition': _condition.code,
                  'vc_faces': [
                    for (final f in Teeth.faces)
                      if (_faces.contains(f)) f,
                  ].join(),
                  'it_situation': _situation.code,
                  'vc_notes': _notes.text.trim(),
                },
              ),
              Strings.toothMarkSaved,
            ),
          ),
      ],
    );
  }
}
