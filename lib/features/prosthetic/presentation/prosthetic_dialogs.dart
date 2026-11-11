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
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../application/prosthetic_controllers.dart';
import '../domain/prosthetic_models.dart';

String? _dateValidator(String? v) =>
    (v ?? '').trim().isEmpty || Dates.parseField(v) != null
    ? null
    : Strings.invalidDate;

/// Laboratorio "sem cadastro" no seletor.
const _freeLab = -1;

/// Cadastro / alteracao de um trabalho protetico.
class ProstheticFormDialog extends ConsumerStatefulWidget {
  const ProstheticFormDialog({super.key, this.work, required this.labs});

  final ProstheticWork? work;
  final List<({int id, String name})> labs;

  static Future<bool?> show(
    BuildContext context, {
    ProstheticWork? work,
    required List<({int id, String name})> labs,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => ProstheticFormDialog(work: work, labs: labs),
  );

  @override
  ConsumerState<ProstheticFormDialog> createState() =>
      _ProstheticFormDialogState();
}

class _ProstheticFormDialogState extends ConsumerState<ProstheticFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int? _nrPatient = widget.work?.nrPatient;
  late String? _vcPatient = widget.work?.vcPatient;
  late int? _nrProfessional = widget.work?.nrProfessional;
  late int? _lab =
      widget.work?.nrSupplier ??
      ((widget.work?.vcLabFree ?? '').isEmpty ? null : _freeLab);
  late final _labFree = TextEditingController(
    text: widget.work?.vcLabFree ?? '',
  );
  late final _description = TextEditingController(
    text: widget.work?.vcDescription ?? '',
  );
  late final _tooth = TextEditingController(text: widget.work?.vcTooth ?? '');
  late final _shade = TextEditingController(text: widget.work?.vcShade ?? '');
  late final _expected = TextEditingController(
    text: Dates.toField(widget.work?.dtExpected),
  );
  late final _cost = TextEditingController(
    text: widget.work?.vlCost == null
        ? ''
        : Numbers.toField(widget.work!.vlCost),
  );
  late final _notes = TextEditingController(text: widget.work?.vcNotes ?? '');
  bool _saving = false;

  /// Com a conta a pagar gerada, custo e laboratorio nao mudam.
  bool get _locked => widget.work?.nrEntry != null;

  @override
  void dispose() {
    for (final c in [
      _labFree,
      _description,
      _tooth,
      _shade,
      _expected,
      _cost,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null) {
      setState(() {
        _nrPatient = p.nrPatient;
        _vcPatient = p.vcName;
      });
    }
  }

  Future<void> _save() async {
    if (_nrPatient == null) {
      AppSnack.error(context, Strings.budgetPatientRequired);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final expected = Dates.parseField(_expected.text);
    final fields = <String, dynamic>{
      if (widget.work == null) 'nr_patient': _nrPatient,
      'nr_professional': _nrProfessional,
      'vc_description': _description.text.trim(),
      'vc_tooth': _tooth.text.trim(),
      'vc_shade': _shade.text.trim(),
      'dt_expected': expected == null ? null : Dates.toIso(expected),
      'vc_notes': _notes.text.trim(),
      if (!_locked) ...{
        'nr_supplier': _lab == _freeLab ? null : _lab,
        'vc_lab': _lab == _freeLab ? _labFree.text.trim() : null,
        'vl_cost': Numbers.parse(_cost.text),
      },
    };
    try {
      await ref
          .read(prostheticActionsProvider)
          .save(widget.work?.nrWork, fields);
      if (!mounted) return;
      AppSnack.success(context, Strings.prosSaved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final professionals = ref.watch(agendaProfessionalsProvider).valueOrNull;
    Widget pair(Widget a, Widget b) => mobile
        ? Column(
            children: [
              a,
              const SizedBox(height: AppSpacing.sm),
              b,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: b),
            ],
          );
    return AlertDialog(
      insetPadding: EdgeInsets.all(mobile ? AppSpacing.sm : AppSpacing.xl),
      title: Text(
        widget.work == null
            ? Strings.prosNew
            : Strings.prosEdit(widget.work!.nrWork),
      ),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(
                  InkWell(
                    onTap: widget.work == null ? _pickPatient : null,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '${Strings.patient} *',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      child: Text(_vcPatient ?? Strings.budgetChoosePatient),
                    ),
                  ),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _nrProfessional,
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
                          child: Text(
                            p.vcName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_nrProfessional != null &&
                          !(professionals ?? const []).any(
                            (p) => p.nrProfessional == _nrProfessional,
                          ))
                        DropdownMenuItem(
                          value: _nrProfessional,
                          child: Text(widget.work?.vcProfessional ?? '-'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _nrProfessional = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: '${Strings.prosDescription} *',
                  hint: Strings.prosDescriptionHint,
                  controller: _description,
                  maxLength: 120,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? Strings.prosDescriptionRequired
                      : null,
                ),
                pair(
                  AppTextField(
                    label: Strings.prosTooth,
                    controller: _tooth,
                    maxLength: 40,
                  ),
                  AppTextField(
                    label: Strings.prosShade,
                    hint: Strings.prosShadeHint,
                    controller: _shade,
                    maxLength: 40,
                  ),
                ),
                pair(
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _lab,
                    decoration: InputDecoration(
                      labelText: Strings.prosLab,
                      helperText: _locked ? Strings.prosLockedHint : null,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(Strings.notInformed),
                      ),
                      for (final l in widget.labs)
                        DropdownMenuItem(
                          value: l.id,
                          child: Text(l.name, overflow: TextOverflow.ellipsis),
                        ),
                      if (_lab != null &&
                          _lab != _freeLab &&
                          !widget.labs.any((l) => l.id == _lab))
                        DropdownMenuItem(
                          value: _lab,
                          child: Text(widget.work?.vcLab ?? '-'),
                        ),
                      const DropdownMenuItem(
                        value: _freeLab,
                        child: Text(Strings.prosLabFree),
                      ),
                    ],
                    onChanged: _locked ? null : (v) => setState(() => _lab = v),
                  ),
                  AppTextField(
                    label: Strings.prosCost,
                    controller: _cost,
                    enabled: !_locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty || Numbers.parse(v) != null
                        ? null
                        : Strings.prosCostInvalid,
                  ),
                ),
                if (_lab == _freeLab) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.prosLabName,
                    helperText: Strings.prosLabFreeHint,
                    controller: _labFree,
                    enabled: !_locked,
                    maxLength: 120,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.prosExpected,
                  controller: _expected,
                  mask: MaskType.date,
                  keyboardType: TextInputType.number,
                  validator: _dateValidator,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.notes,
                  controller: _notes,
                  maxLength: 1000,
                  maxLines: 3,
                ),
              ],
            ),
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
}

/// Muda a etapa do trabalho (envio, prova, recebimento, instalacao...).
class ProstheticStageDialog extends ConsumerStatefulWidget {
  const ProstheticStageDialog({super.key, required this.work});

  final ProstheticWork work;

  static Future<bool?> show(BuildContext context, ProstheticWork work) =>
      showDialog<bool>(
        context: context,
        builder: (_) => ProstheticStageDialog(work: work),
      );

  @override
  ConsumerState<ProstheticStageDialog> createState() =>
      _ProstheticStageDialogState();
}

class _ProstheticStageDialogState extends ConsumerState<ProstheticStageDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _stage = ProstheticStage.next(widget.work.itStage);
  final _date = TextEditingController(text: Dates.toField(DateTime.now()));
  late final _expected = TextEditingController(
    text: Dates.toField(widget.work.dtExpected),
  );
  final _due = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_date, _expected, _due, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _receiving =>
      (_stage == ProstheticStage.received ||
          _stage == ProstheticStage.installed) &&
      widget.work.willCreatePayable;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final date = Dates.parseField(_date.text) ?? DateTime.now();
    final expected = Dates.parseField(_expected.text);
    final due = Dates.parseField(_due.text);
    try {
      final r = await ref
          .read(prostheticActionsProvider)
          .stage(widget.work.nrWork, {
            'it_stage': _stage,
            'dt_step': Dates.toIso(date),
            if (_stage == ProstheticStage.atLab && expected != null)
              'dt_expected': Dates.toIso(expected),
            if (_receiving && due != null) 'dt_due': Dates.toIso(due),
            if (_notes.text.trim().isNotEmpty) 'vc_notes': _notes.text.trim(),
          });
      if (!mounted) return;
      if (r.skipped) {
        AppSnack.info(context, Strings.prosPayableSkipped);
      } else {
        AppSnack.success(
          context,
          r.payable && _receiving
              ? Strings.prosPayableCreated
              : Strings.prosStageSaved,
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    return AlertDialog(
      title: Text(Strings.prosStageTitle(w.vcDescription)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${Strings.prosCurrentStage}: ${ProstheticStage.label(w.itStage)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in ProstheticStage.all)
                      if (s != w.itStage)
                        ChoiceChip(
                          avatar: Icon(
                            ProstheticStage.icon(s),
                            size: 16,
                            color: ProstheticStage.color(s),
                          ),
                          label: Text(ProstheticStage.label(s)),
                          selected: _stage == s,
                          onSelected: (_) => setState(() => _stage = s),
                        ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: Strings.prosStepDate,
                  controller: _date,
                  mask: MaskType.date,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final d = Dates.parseField(v);
                    if (d == null) return Strings.invalidDate;
                    return d.isAfter(DateTime.now())
                        ? Strings.prosFutureDate
                        : null;
                  },
                ),
                if (_stage == ProstheticStage.atLab) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.prosExpected,
                    controller: _expected,
                    mask: MaskType.date,
                    keyboardType: TextInputType.number,
                    validator: _dateValidator,
                  ),
                ],
                if (_receiving) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Strings.prosPayableInfo(
                        Numbers.money(w.vlCost),
                        w.vcLab ?? '',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.prosDue,
                    hint: Strings.prosDueHint,
                    controller: _due,
                    mask: MaskType.date,
                    keyboardType: TextInputType.number,
                    validator: _dateValidator,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.notes,
                  controller: _notes,
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.prosStageSave,
          expanded: false,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
