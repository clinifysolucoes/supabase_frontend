import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/agenda_controllers.dart';
import '../domain/agenda_models.dart';
import 'agenda_grid.dart';
import 'appointment_details_dialog.dart';
import 'appointment_form_dialog.dart';

/// Aba Agenda: navegacao por data, visao dia (colunas por profissional, fora
/// do horario hachurado), semana (colunas por dia) e mes; painel lateral com
/// calendario, filtro de profissionais e alertas de retorno. No celular, a
/// lista do dia.
class AgendaCalendarTab extends ConsumerWidget {
  const AgendaCalendarTab({super.key});

  static String title(AgendaView view, DateTime day) {
    switch (view) {
      case AgendaView.day:
        return '${Weekday.label(Weekday.fromDate(day))}, '
            '${day.day} de ${Strings.monthName(day.month)} de ${day.year}';
      case AgendaView.week:
        final r = agendaRange(view, day);
        return '${r.from.day}/${r.from.month} – ${r.to.day}/${r.to.month}/${r.to.year}';
      case AgendaView.month:
        final m = Strings.monthName(day.month);
        return '${m[0].toUpperCase()}${m.substring(1)} de ${day.year}';
    }
  }

  static DateTime shift(AgendaView view, DateTime day, int dir) =>
      switch (view) {
        AgendaView.day => day.add(Duration(days: dir)),
        AgendaView.week => day.add(Duration(days: 7 * dir)),
        AgendaView.month => DateTime(day.year, day.month + dir, 1),
      };

  Future<void> _new(
    BuildContext context,
    List<Professional> professionals, {
    int type = AppointmentType.consultation,
    DateTime? day,
    int? minute,
    int? nrProfessional,
  }) async {
    final saved = await AppointmentFormDialog.show(
      context,
      professionals: professionals,
      itType: type,
      day: day,
      startMinute: minute,
      nrProfessional: nrProfessional,
    );
    if (saved && context.mounted) {
      AppSnack.success(context, Strings.savedSuccess);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profAsync = ref.watch(agendaProfessionalsProvider);
    final async = ref.watch(appointmentsProvider);
    final day = ref.watch(agendaDayProvider);
    final view = context.isMobile
        ? AgendaView.day
        : ref.watch(agendaViewProvider);
    final hidden = ref.watch(agendaHiddenProfessionalsProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.agenda));
    final professionals = profAsync.valueOrNull ?? const <Professional>[];
    final visible = [
      for (final p in professionals)
        if (!hidden.contains(p.nrProfessional)) p,
    ];
    final data = async.valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    void setDay(DateTime d) => ref.read(agendaDayProvider.notifier).state =
        DateTime(d.year, d.month, d.day);

    final toolbar = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: Strings.previous,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => setDay(shift(view, day, -1)),
        ),
        AppButton(
          label: Strings.today,
          variant: AppButtonVariant.secondary,
          expanded: false,
          onPressed: () => setDay(DateTime.now()),
        ),
        IconButton(
          tooltip: Strings.next,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => setDay(shift(view, day, 1)),
        ),
        Text(
          title(view, day),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!context.isMobile)
          SegmentedButton<AgendaView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AgendaView.day,
                label: Text(Strings.viewDay),
              ),
              ButtonSegment(
                value: AgendaView.week,
                label: Text(Strings.viewWeek),
              ),
              ButtonSegment(
                value: AgendaView.month,
                label: Text(Strings.viewMonth),
              ),
            ],
            selected: {view},
            onSelectionChanged: (s) =>
                ref.read(agendaViewProvider.notifier).state = s.first,
          ),
        if (canCreate && professionals.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: Strings.newItem,
            onSelected: (type) => _new(
              context,
              professionals,
              type: type,
              day: day,
              nrProfessional: visible.length == 1
                  ? visible.first.nrProfessional
                  : null,
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AppointmentType.consultation,
                child: ListTile(
                  leading: Icon(Icons.event_available_rounded),
                  title: Text(Strings.newConsultation),
                ),
              ),
              PopupMenuItem(
                value: AppointmentType.commitment,
                child: ListTile(
                  leading: Icon(Icons.event_busy_rounded),
                  title: Text(Strings.newCommitment),
                ),
              ),
            ],
            child: IgnorePointer(
              child: AppButton(
                label: Strings.newItem,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () {},
              ),
            ),
          ),
      ],
    );

    Widget body() {
      if (profAsync.isLoading || (async.isLoading && data == null)) {
        return const Center(child: CircularProgressIndicator());
      }
      if (async.hasError) {
        return AppEmptyState.error(
          message: describeError(async.error!),
          onRetry: () => ref.invalidate(appointmentsProvider),
        );
      }
      if (professionals.isEmpty) {
        return const AppEmptyState(
          icon: Icons.badge_outlined,
          title: Strings.noActiveProfessionals,
        );
      }
      final appointments = data?.appointments ?? const <Appointment>[];
      void open(Appointment a) => AppointmentDetailsDialog.show(
        context,
        appointment: a,
        professionals: professionals,
      );

      if (context.isMobile) {
        return _DayList(
          appointments: [
            for (final a in appointments)
              if (a.occursOn(day) &&
                  (a.isClinicWide ||
                      visible.any((p) => p.nrProfessional == a.nrProfessional)))
                a,
          ],
          onTap: open,
        );
      }

      switch (view) {
        case AgendaView.day:
          final weekday = Weekday.fromDate(day);
          final dayItems = [
            for (final a in appointments)
              if (a.occursOn(day)) a,
          ];
          final win = TimeGrid.window([
            for (final p in visible) ...p.rangesOf(weekday),
          ], dayItems);
          return TimeGrid(
            minuteFrom: win.from,
            minuteTo: win.to,
            slotMinutes: visible.isEmpty
                ? 30
                : visible
                      .map((p) => p.qtSlotMinutes)
                      .reduce((a, b) => a < b ? a : b),
            columns: [
              for (final p in visible)
                GridColumn(
                  title: p.vcName,
                  subtitle: Strings.patientsCount(
                    dayItems
                        .where(
                          (a) =>
                              a.isConsultation &&
                              a.nrProfessional == p.nrProfessional,
                        )
                        .length,
                  ),
                  color: Color(AgendaColors.argb(p.vcColor)),
                  day: day,
                  nrProfessional: p.nrProfessional,
                  available: p.rangesOf(weekday),
                  appointments: [
                    for (final a in dayItems)
                      if (a.belongsTo(p.nrProfessional)) a,
                  ],
                ),
            ],
            onTapSlot: (c, m) => canCreate
                ? _new(
                    context,
                    professionals,
                    day: c.day,
                    minute: m,
                    nrProfessional: c.nrProfessional,
                  )
                : null,
            onTapAppointment: open,
          );
        case AgendaView.week:
          final range = agendaRange(view, day);
          final weekItems = [
            for (final a in appointments)
              if (a.isClinicWide ||
                  visible.any((p) => p.nrProfessional == a.nrProfessional))
                a,
          ];
          final single = visible.length == 1 ? visible.first : null;
          final win = TimeGrid.window([
            for (final p in visible) ...p.schedules,
          ], weekItems);
          final today = DateTime.now();
          return TimeGrid(
            minuteFrom: win.from,
            minuteTo: win.to,
            minColumnWidth: 120,
            columns: [
              for (var i = 0; i < 7; i++)
                () {
                  final d = range.from.add(Duration(days: i));
                  return GridColumn(
                    title:
                        '${Weekday.short(Weekday.fromDate(d))} ${d.day.toString().padLeft(2, '0')}',
                    day: d,
                    nrProfessional: single?.nrProfessional,
                    highlight:
                        d.year == today.year &&
                        d.month == today.month &&
                        d.day == today.day,
                    available: single?.rangesOf(Weekday.fromDate(d)),
                    appointments: [
                      for (final a in weekItems)
                        if (a.occursOn(d)) a,
                    ],
                  );
                }(),
            ],
            onTapSlot: (c, m) => canCreate
                ? _new(
                    context,
                    professionals,
                    day: c.day,
                    minute: m,
                    nrProfessional: c.nrProfessional,
                  )
                : null,
            onTapAppointment: open,
          );
        case AgendaView.month:
          final range = agendaRange(view, day);
          return MonthGrid(
            month: day,
            from: range.from,
            appointments: [
              for (final a in appointments)
                if (a.isClinicWide ||
                    visible.any((p) => p.nrProfessional == a.nrProfessional))
                  a,
            ],
            onTapDay: (d) {
              setDay(d);
              ref.read(agendaViewProvider.notifier).state = AgendaView.day;
            },
          );
      }
    }

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        if (context.isMobile && professionals.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _ProfessionalChips(professionals: professionals, hidden: hidden),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (async.isLoading && data != null) const LinearProgressIndicator(),
        Expanded(child: body()),
      ],
    );

    if (!wide) return main;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: _SidePanel(
            day: day,
            professionals: professionals,
            hidden: hidden,
            alerts: data?.returnAlerts ?? const [],
            onDay: setDay,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: main),
      ],
    );
  }
}

/// Painel lateral (desktop largo): calendario, profissionais e retornos.
class _SidePanel extends ConsumerWidget {
  const _SidePanel({
    required this.day,
    required this.professionals,
    required this.hidden,
    required this.alerts,
    required this.onDay,
  });

  final DateTime day;
  final List<Professional> professionals;
  final Set<int> hidden;
  final List<ReturnAlert> alerts;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    TextStyle? section() =>
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          CalendarDatePicker(
            key: ValueKey(day),
            initialDate: day,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: onDay,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(Strings.professionalsFilter, style: section()),
          ),
          for (final p in professionals)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Color(AgendaColors.argb(p.vcColor)),
              value: !hidden.contains(p.nrProfessional),
              title: Text(
                p.vcName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: (v) {
                final next = {...hidden};
                v == true
                    ? next.remove(p.nrProfessional)
                    : next.add(p.nrProfessional);
                ref.read(agendaHiddenProfessionalsProvider.notifier).state =
                    next;
              },
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(Strings.returnAlerts, style: section()),
          ),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text(
                Strings.noReturnAlerts,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          for (final r in alerts)
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.warning,
              ),
              title: Text(
                r.vcName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  Dates.format(r.dtReturnAlert),
                  if ((r.vcReturnAlert ?? '').isNotEmpty) r.vcReturnAlert!,
                ].join(' · '),
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }
}

/// Filtro de profissionais no celular.
class _ProfessionalChips extends ConsumerWidget {
  const _ProfessionalChips({required this.professionals, required this.hidden});

  final List<Professional> professionals;
  final Set<int> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in professionals)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                avatar: CircleAvatar(
                  radius: 6,
                  backgroundColor: Color(AgendaColors.argb(p.vcColor)),
                ),
                label: Text(p.vcName),
                selected: !hidden.contains(p.nrProfessional),
                onSelected: (v) {
                  final next = {...hidden};
                  v
                      ? next.remove(p.nrProfessional)
                      : next.add(p.nrProfessional);
                  ref.read(agendaHiddenProfessionalsProvider.notifier).state =
                      next;
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Lista do dia (celular): horario, paciente/compromisso, profissional e
/// situacao.
class _DayList extends StatelessWidget {
  const _DayList({required this.appointments, required this.onTap});

  final List<Appointment> appointments;
  final ValueChanged<Appointment> onTap;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_available_outlined,
        title: Strings.noAppointmentsDay,
      );
    }
    return ListView.separated(
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final a = appointments[i];
        return SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 54,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    a.idAllDay
                        ? Strings.allDay
                        : DayMinutes.format(a.startMinute),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: AppointmentBlock(appointment: a, onTap: () => onTap(a)),
              ),
            ],
          ),
        );
      },
    );
  }
}
