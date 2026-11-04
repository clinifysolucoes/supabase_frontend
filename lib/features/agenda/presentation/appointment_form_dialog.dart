import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../application/agenda_controllers.dart';
import '../data/agenda_repository.dart';
import '../domain/agenda_models.dart';
import 'patient_picker_dialog.dart';

/// Nova consulta / novo compromisso (appointment = null) ou edicao.
///   Consulta:     paciente (busca), profissional, data, inicio, duracao,
///                 motivo, observacoes e encaixe.
///   Compromisso:  titulo, profissional ou clinica toda, data, dia inteiro ou
///                 inicio e duracao, observacoes.
/// Devolve true quando salvou.
class AppointmentFormDialog extends ConsumerStatefulWidget {
  const AppointmentFormDialog({
    super.key,
    this.appointment,
    required this.professionals,
    this.itType = AppointmentType.consultation,
    this.day,
    this.startMinute,
    this.nrProfessional,
  });

  final Appointment? appointment;
  final List<Professional> professionals;
  final int itType;

  /// Valores iniciais do novo agendamento (clique num horario vazio da grade).
  final DateTime? day;
  final int? startMinute;
  final int? nrProfessional;

  static Future<bool> show(
    BuildContext context, {
    Appointment? appointment,
    required List<Professional> professionals,
    int itType = AppointmentType.consultation,
    DateTime? day,
    int? startMinute,
    int? nrProfessional,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AppointmentFormDialog(
        appointment: appointment,
        professionals: professionals,
        itType: itType,
        day: day,
        startMinute: startMinute,
        nrProfessional: nrProfessional,
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<AppointmentFormDialog> createState() =>
      _AppointmentFormDialogState();
}

/// Duracoes oferecidas (minutos).
const _durations = [10, 15, 20, 30, 40, 45, 60, 90, 120, 150, 180, 240];

class _AppointmentFormDialogState extends ConsumerState<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _type = _a?.itType ?? widget.itType;
  late int? _nrPatient = _a?.nrPatient;
  late String? _patientName = _a?.vcPatientName;
  late int? _nrProfessional =
      _a?.nrProfessional ??
      widget.nrProfessional ??
      (widget.professionals.length == 1
          ? widget.professionals.first.nrProfessional
          : null);
  late bool _clinicWide = _a?.isClinicWide ?? false;
  late DateTime _day = _a == null
      ? (widget.day ?? DateTime.now())
      : DateTime(_a!.dhStart.year, _a!.dhStart.month, _a!.dhStart.day);
  late int _start = _a?.startMinute ?? widget.startMinute ?? _defaultStart();
  late int _duration = _a?.durationMinutes ?? _defaultDuration();
  late bool _allDay = _a?.idAllDay ?? false;
  late bool _fitIn = _a?.idFitIn ?? false;
  late final _title = TextEditingController(text: _a?.vcTitle ?? '');
  late final _notes = TextEditingController(text: _a?.vcNotes ?? '');
  bool _saving = false;

  Appointment? get _a => widget.appointment;
  bool get _isEdit => _a != null;
  bool get _isConsultation => _type == AppointmentType.consultation;

  Professional? get _professional {
    for (final p in widget.professionals) {
      if (p.nrProfessional == _nrProfessional) return p;
    }
    return null;
  }

  /// Proximo horario cheio a partir de agora (ou 08:00).
  int _defaultStart() {
    final now = DateTime.now();
    final m = (now.hour + 1) * 60;
    return m >= 1440 || m < 420 ? 480 : m;
  }

  int _defaultDuration() {
    for (final p in widget.professionals) {
      if (p.nrProfessional == widget.nrProfessional) return p.qtSlotMinutes;
    }
    return 30;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null && mounted) {
      setState(() {
        _nrPatient = p.nrPatient;
        _patientName = p.vcName;
      });
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _start = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isConsultation && _nrPatient == null) {
      AppSnack.error(context, Strings.choosePatient);
      return;
    }
    if ((_isConsultation || !_clinicWide) && _nrProfessional == null) {
      AppSnack.error(context, Strings.chooseProfessional);
      return;
    }
    final dayStart = DateTime(_day.year, _day.month, _day.day);
    final allDay = !_isConsultation && _allDay;
    final start = allDay ? dayStart : dayStart.add(Duration(minutes: _start));
    final end = allDay
        ? dayStart.add(const Duration(days: 1))
        : start.add(Duration(minutes: _duration));
    final draft = AppointmentDraft(
      itType: _type,
      dhStart: start,
      dhEnd: end,
      nrPatient: _isConsultation ? _nrPatient : null,
      nrProfessional: !_isConsultation && _clinicWide ? null : _nrProfessional,
      nrProcedure: _a?.nrProcedure,
      vcTitle: _title.text.trim().isEmpty ? null : _title.text.trim(),
      vcNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      idAllDay: allDay,
      idFitIn: _isConsultation && _fitIn,
    );
    setState(() => _saving = true);
    try {
      final controller = ref.read(appointmentsProvider.notifier);
      if (_isEdit) {
        await controller.change(_a!.nrAppointment, draft.toJson());
      } else {
        await controller.create(draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final pad = isMobile ? AppSpacing.md : AppSpacing.xl;
    final title = _isEdit
        ? (_isConsultation ? Strings.editConsultation : Strings.editCommitment)
        : (_isConsultation ? Strings.newConsultation : Strings.newCommitment);

    final profChoices = [
      for (final p in widget.professionals)
        Choice<int>(value: p.nrProfessional, label: p.vcName),
      if (_a?.nrProfessional != null &&
          !widget.professionals.any(
            (p) => p.nrProfessional == _a!.nrProfessional,
          ))
        Choice<int>(
          value: _a!.nrProfessional,
          label: _a!.vcProfessionalName ?? '-',
        ),
    ];
    final durChoices = [
      for (final d in {..._durations, _duration}.toList()..sort())
        Choice<int>(
          value: d,
          label: d < 60
              ? '$d min'
              : '${d ~/ 60} h${d % 60 == 0 ? '' : ' ${d % 60} min'}',
        ),
    ];

    Widget pair(Widget a, Widget b) => isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: b),
            ],
          );

    Widget pickerTile({
      required String label,
      required String value,
      required IconData icon,
      required VoidCallback? onTap,
      bool empty = false,
    }) => InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: _saving ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: empty ? const TextStyle(color: AppColors.muted) : null,
        ),
      ),
    );

    final professionalField = SearchableDropdown<Choice<int>>(
      label: Strings.professional,
      items: profChoices,
      value: profChoices.where((c) => c.value == _nrProfessional).firstOrNull,
      itemLabel: (c) => c.label,
      prefixIcon: Icons.badge_outlined,
      enabled: !_saving,
      onChanged: (c) => setState(() {
        _nrProfessional = c.value;
        if (!_isEdit) _duration = _professional?.qtSlotMinutes ?? _duration;
      }),
    );

    final fields = <Widget>[
      Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (!_isEdit) ...[
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: AppointmentType.consultation,
              label: Text(Strings.consultation),
              icon: Icon(Icons.event_available_rounded),
            ),
            ButtonSegment(
              value: AppointmentType.commitment,
              label: Text(Strings.commitment),
              icon: Icon(Icons.event_busy_rounded),
            ),
          ],
          selected: {_type},
          onSelectionChanged: _saving
              ? null
              : (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (_isConsultation) ...[
        pickerTile(
          label: Strings.patient,
          value: _patientName ?? Strings.choosePatient,
          icon: Icons.person_search_rounded,
          onTap: _pickPatient,
          empty: _patientName == null,
        ),
        const SizedBox(height: AppSpacing.md),
        professionalField,
      ] else ...[
        AppTextField(
          label: Strings.commitmentTitle,
          hint: Strings.commitmentTitleHint,
          controller: _title,
          maxLength: 80,
          enabled: !_saving,
          prefixIcon: Icons.title_rounded,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? Strings.commitmentTitle : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text(Strings.forProfessional),
              selected: !_clinicWide,
              onSelected: (_) => setState(() => _clinicWide = false),
            ),
            ChoiceChip(
              label: const Text(Strings.forWholeClinic),
              selected: _clinicWide,
              onSelected: (_) => setState(() => _clinicWide = true),
            ),
          ],
        ),
        if (!_clinicWide) ...[
          const SizedBox(height: AppSpacing.md),
          professionalField,
        ],
      ],
      const SizedBox(height: AppSpacing.md),
      pair(
        pickerTile(
          label: Strings.date,
          value: Dates.format(_day),
          icon: Icons.event_rounded,
          onTap: _pickDay,
        ),
        _allDay && !_isConsultation
            ? const SizedBox.shrink()
            : pickerTile(
                label: Strings.startTime,
                value: DayMinutes.format(_start),
                icon: Icons.schedule_rounded,
                onTap: _pickStart,
              ),
      ),
      if (!(_allDay && !_isConsultation)) ...[
        const SizedBox(height: AppSpacing.md),
        SearchableDropdown<Choice<int>>(
          label: Strings.duration,
          items: durChoices,
          value: durChoices.where((c) => c.value == _duration).firstOrNull,
          itemLabel: (c) =>
              '${c.label}  (${DayMinutes.range(_start, (_start + (c.value ?? 0)).clamp(0, 1440))})',
          prefixIcon: Icons.timelapse_rounded,
          enabled: !_saving,
          onChanged: (c) => setState(() => _duration = c.value ?? _duration),
        ),
      ],
      if (!_isConsultation)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.allDay),
          value: _allDay,
          onChanged: _saving ? null : (v) => setState(() => _allDay = v),
        ),
      if (_isConsultation) ...[
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: Strings.consultationReason,
          controller: _title,
          maxLength: 80,
          enabled: !_saving,
          prefixIcon: Icons.short_text_rounded,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: Strings.notes,
        controller: _notes,
        enabled: !_saving,
        maxLines: 3,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      if (_isConsultation)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(Strings.fitIn),
          value: _fitIn,
          onChanged: _saving
              ? null
              : (v) => setState(() => _fitIn = v ?? false),
        ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  AppSpacing.md,
                  pad,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: Strings.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: Strings.save,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
