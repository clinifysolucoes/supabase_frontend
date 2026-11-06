import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_snack.dart';
import '../domain/agenda_models.dart';

/// Horario da semana em faixas por dia (profissional, clinica): adicionar,
/// mudar o horario (relogio), remover e copiar segunda para terca a sexta.
/// Devolve a lista nova em [onChanged].
class WeekScheduleEditor extends StatelessWidget {
  const WeekScheduleEditor({
    super.key,
    required this.ranges,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
    this.stepMinutes = 30,
  });

  final List<ScheduleRange> ranges;
  final ValueChanged<List<ScheduleRange>> onChanged;
  final bool enabled;
  final bool compact;

  /// Duracao minima de uma faixa nova.
  final int stepMinutes;

  List<ScheduleRange> _of(int day) => [
    for (final s in ranges)
      if (s.itWeekday == day) s,
  ]..sort((a, b) => a.qtMinuteStart.compareTo(b.qtMinuteStart));

  /// Primeiro dia com faixas sobrepostas (null = ok).
  static int? overlapDay(List<ScheduleRange> ranges) {
    for (var i = 0; i < ranges.length; i++) {
      for (var j = i + 1; j < ranges.length; j++) {
        if (ranges[i].overlaps(ranges[j])) return ranges[i].itWeekday;
      }
    }
    return null;
  }

  void _add(int day) {
    final list = _of(day);
    final start = list.isEmpty ? 480 : list.last.qtMinuteEnd + 60;
    if (start >= 1440) return;
    final end = (start + 240).clamp(start + stepMinutes, 1440);
    onChanged([
      ...ranges,
      ScheduleRange(itWeekday: day, qtMinuteStart: start, qtMinuteEnd: end),
    ]);
  }

  void _copyMonday() {
    final monday = _of(1);
    onChanged([
      for (final s in ranges)
        if (s.itWeekday < 2 || s.itWeekday > 5) s,
      for (final day in const [2, 3, 4, 5])
        for (final r in monday) r.copyWith(itWeekday: day),
    ]);
  }

  Future<int?> _pickTime(BuildContext context, int minutes, String help) async {
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

  Future<void> _edit(BuildContext context, ScheduleRange r) async {
    final start = await _pickTime(
      context,
      r.qtMinuteStart,
      Strings.scheduleStart,
    );
    if (start == null || !context.mounted) return;
    final end = await _pickTime(context, r.qtMinuteEnd, Strings.scheduleEnd);
    if (end == null || !context.mounted) return;
    if (start >= end) {
      AppSnack.error(context, Strings.scheduleInvalid);
      return;
    }
    onChanged([
      for (final s in ranges)
        if (identical(s, r))
          r.copyWith(qtMinuteStart: start, qtMinuteEnd: end)
        else
          s,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enabled && _of(1).isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyMonday,
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text(Strings.copyMondayToWeekdays),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              for (var i = 0; i < Weekday.all.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ScheduleDayRow(
                  day: Weekday.all[i],
                  ranges: _of(Weekday.all[i]),
                  enabled: enabled,
                  compact: compact,
                  onAdd: () => _add(Weekday.all[i]),
                  onEdit: (r) => _edit(context, r),
                  onRemove: (r) => onChanged([...ranges]..remove(r)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Um dia da semana: faixas (clique para alterar, x para remover) e "+ faixa".
class ScheduleDayRow extends StatelessWidget {
  const ScheduleDayRow({
    super.key,
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
