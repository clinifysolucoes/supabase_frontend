import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../application/agenda_controllers.dart';
import '../data/agenda_repository.dart';
import '../domain/agenda_models.dart';

/// Novo profissional (professional = null) ou edicao: nome, conselho, cor na
/// agenda, intervalo dos horarios, usuario do sistema vinculado e horario de
/// atendimento por dia da semana (varias faixas por dia). Devolve true
/// quando salvou.
class ProfessionalFormDialog extends ConsumerStatefulWidget {
  const ProfessionalFormDialog({
    super.key,
    this.professional,
    required this.users,
    this.readOnly = false,
  });

  final Professional? professional;
  final List<AgendaUser> users;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    Professional? professional,
    required List<AgendaUser> users,
    bool readOnly = false,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProfessionalFormDialog(
        professional: professional,
        users: users,
        readOnly: readOnly,
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<ProfessionalFormDialog> createState() =>
      _ProfessionalFormDialogState();
}

/// Intervalos oferecidos no combo (minutos).
const _slots = [10, 15, 20, 30, 40, 45, 60];

class _ProfessionalFormDialogState
    extends ConsumerState<ProfessionalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _p?.vcName ?? '');
  late final _council = TextEditingController(text: _p?.vcCouncil ?? '');
  late String? _color = _p?.vcColor;
  late int _slot = _p?.qtSlotMinutes ?? 30;
  late int? _nrUser = _p?.nrUser;
  late bool _active = _p?.isActive ?? true;
  late List<ScheduleRange> _schedules = [...?_p?.schedules];
  bool _saving = false;

  Professional? get _p => widget.professional;
  bool get _isEdit => _p != null;
  bool get _canEdit => !widget.readOnly && !_saving;

  @override
  void dispose() {
    _name.dispose();
    _council.dispose();
    super.dispose();
  }

  List<ScheduleRange> _rangesOf(int day) => [
    for (final s in _schedules)
      if (s.itWeekday == day) s,
  ]..sort((a, b) => a.qtMinuteStart.compareTo(b.qtMinuteStart));

  /// Nova faixa no dia: manha (08-12) ou, se ja houver, 1 h depois da ultima.
  void _addRange(int day) {
    final ranges = _rangesOf(day);
    final start = ranges.isEmpty ? 480 : ranges.last.qtMinuteEnd + 60;
    if (start >= 1440) return;
    final end = (start + 240).clamp(start + _slot, 1440);
    setState(() {
      _schedules = [
        ..._schedules,
        ScheduleRange(itWeekday: day, qtMinuteStart: start, qtMinuteEnd: end),
      ];
    });
  }

  void _removeRange(ScheduleRange r) =>
      setState(() => _schedules = [..._schedules]..remove(r));

  /// Copia o horario de segunda para terca a sexta.
  void _copyMondayToWeekdays() {
    final monday = _rangesOf(1);
    setState(() {
      _schedules = [
        for (final s in _schedules)
          if (s.itWeekday < 2 || s.itWeekday > 5) s,
        for (final day in const [2, 3, 4, 5])
          for (final r in monday) r.copyWith(itWeekday: day),
      ];
    });
  }

  Future<int?> _pickTime(int minutes, String help) async {
    final picked = await showTimePicker(
      context: context,
      helpText: help,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _editRange(ScheduleRange r) async {
    final start = await _pickTime(r.qtMinuteStart, Strings.scheduleStart);
    if (start == null || !mounted) return;
    final end = await _pickTime(r.qtMinuteEnd, Strings.scheduleEnd);
    if (end == null || !mounted) return;
    if (start >= end) {
      AppSnack.error(context, Strings.scheduleInvalid);
      return;
    }
    setState(() {
      _schedules = [
        for (final s in _schedules)
          if (identical(s, r))
            r.copyWith(qtMinuteStart: start, qtMinuteEnd: end)
          else
            s,
      ];
    });
  }

  /// Primeiro dia com faixas sobrepostas (null = ok).
  int? get _overlapDay {
    for (var i = 0; i < _schedules.length; i++) {
      for (var j = i + 1; j < _schedules.length; j++) {
        if (_schedules[i].overlaps(_schedules[j])) {
          return _schedules[i].itWeekday;
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final overlap = _overlapDay;
    if (overlap != null) {
      AppSnack.error(context, Strings.scheduleOverlap(Weekday.label(overlap)));
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = ProfessionalDraft(
        vcName: _name.text.trim(),
        vcCouncil: _council.text.trim().isEmpty ? null : _council.text.trim(),
        vcColor: _color,
        qtSlotMinutes: _slot,
        nrUser: _nrUser,
        itStatus: _isEdit ? (_active ? 1 : 90) : null,
        schedules: _schedules,
      );
      final controller = ref.read(professionalsProvider.notifier);
      if (_isEdit) {
        await controller.updateProfessional(_p!.nrProfessional, draft);
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
    final title = widget.readOnly
        ? Strings.professional
        : (_isEdit ? Strings.editProfessional : Strings.newProfessional);

    final slotChoices = [
      for (final s in _slots) Choice<int>(value: s, label: '$s min'),
    ];
    final userChoices = [
      const Choice<int>(value: null, label: Strings.noLinkedUser),
      for (final u in widget.users)
        Choice<int>(value: u.nrUser, label: u.vcName, subtitle: u.vcEmail),
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

    final fields = <Widget>[
      Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      pair(
        AppTextField(
          label: Strings.professionalName,
          hint: Strings.professionalNameHint,
          controller: _name,
          maxLength: 80,
          autofocus: !_isEdit,
          enabled: _canEdit,
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          validator: Validators.required(),
        ),
        AppTextField(
          label: Strings.professionalCouncil,
          hint: Strings.professionalCouncilHint,
          controller: _council,
          maxLength: 30,
          enabled: _canEdit,
          prefixIcon: Icons.verified_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      pair(
        SearchableDropdown<Choice<int>>(
          label: Strings.slotMinutes,
          items: slotChoices,
          value: slotChoices.firstWhere(
            (c) => c.value == _slot,
            orElse: () => Choice<int>(value: _slot, label: '$_slot min'),
          ),
          itemLabel: (c) => c.label,
          prefixIcon: Icons.timelapse_rounded,
          enabled: _canEdit,
          onChanged: (c) => setState(() => _slot = c.value ?? 30),
        ),
        SearchableDropdown<Choice<int>>(
          label: Strings.linkedUser,
          items: userChoices,
          value: userChoices.firstWhere(
            (c) => c.value == _nrUser,
            orElse: () => userChoices.first,
          ),
          itemLabel: (c) => c.label,
          itemSubtitle: (c) => c.subtitle,
          prefixIcon: Icons.link_rounded,
          enabled: _canEdit,
          onChanged: (c) => setState(() => _nrUser = c.value),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        Strings.agendaColor,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      _ColorPicker(
        value: _color ?? AgendaColors.palette.first,
        enabled: _canEdit,
        onChanged: (c) => setState(() => _color = c),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(
            child: Text(
              Strings.workingHours,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_canEdit && _rangesOf(1).isNotEmpty)
            TextButton.icon(
              onPressed: _copyMondayToWeekdays,
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text(Strings.copyMondayToWeekdays),
            ),
        ],
      ),
      Text(
        Strings.workingHoursHelp,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.sm),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            for (var i = 0; i < Weekday.all.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _DayRow(
                day: Weekday.all[i],
                ranges: _rangesOf(Weekday.all[i]),
                enabled: _canEdit,
                compact: isMobile,
                onAdd: () => _addRange(Weekday.all[i]),
                onEdit: _editRange,
                onRemove: _removeRange,
              ),
            ],
          ],
        ),
      ),
      if (_isEdit) ...[
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.professionalActive),
          value: _active,
          onChanged: _canEdit ? (v) => setState(() => _active = v) : null,
        ),
      ],
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
              // rodape fixo: Salvar sempre visivel, sem rolar o formulario
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
                        label: widget.readOnly ? Strings.close : Strings.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: Strings.save,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
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

/// Bolinhas com as cores da paleta da agenda.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final hex in AgendaColors.palette)
          Semantics(
            button: true,
            selected: hex == value,
            label: hex,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? () => onChanged(hex) : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(AgendaColors.argb(hex)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hex == value ? AppColors.ink : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: hex == value
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Um dia da semana: faixas (clique para alterar, x para remover) e "+ faixa".
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.ranges,
    required this.enabled,
    required this.compact,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final int day;
  final List<ScheduleRange> ranges;
  final bool enabled;
  final bool compact;
  final VoidCallback onAdd;
  final ValueChanged<ScheduleRange> onEdit;
  final ValueChanged<ScheduleRange> onRemove;

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (ranges.isEmpty)
          const Text(Strings.dayOff, style: TextStyle(color: AppColors.muted)),
        for (final r in ranges)
          InputChip(
            label: Text(DayMinutes.range(r.qtMinuteStart, r.qtMinuteEnd)),
            onPressed: enabled ? () => onEdit(r) : null,
            onDeleted: enabled ? () => onRemove(r) : null,
            deleteButtonTooltipMessage: Strings.remove,
          ),
        if (enabled)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text(Strings.addRange),
            onPressed: onAdd,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Weekday.label(day),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                chips,
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    Weekday.label(day),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: chips),
              ],
            ),
    );
  }
}
