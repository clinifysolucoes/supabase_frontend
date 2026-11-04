import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../domain/agenda_models.dart';

/// Uma coluna da grade de horarios: um profissional (visao dia) ou um dia
/// (visao semana). [available] sao as faixas de atendimento; fora delas o
/// fundo fica hachurado. Null = tudo disponivel.
class GridColumn {
  const GridColumn({
    required this.title,
    required this.day,
    required this.appointments,
    this.subtitle,
    this.color,
    this.nrProfessional,
    this.available,
    this.highlight = false,
  });

  final String title;
  final String? subtitle;
  final Color? color;
  final DateTime day;
  final int? nrProfessional;
  final List<Appointment> appointments;
  final List<ScheduleRange>? available;

  /// Destaque no cabecalho (hoje).
  final bool highlight;
}

/// Grade de horarios com colunas lado a lado. Toque num horario vazio chama
/// [onTapSlot] (arredondado para [slotMinutes]); toque num cartao chama
/// [onTapAppointment].
class TimeGrid extends StatelessWidget {
  const TimeGrid({
    super.key,
    required this.columns,
    required this.minuteFrom,
    required this.minuteTo,
    required this.onTapSlot,
    required this.onTapAppointment,
    this.slotMinutes = 30,
    this.pixelsPerMinute = 1.4,
    this.minColumnWidth = 150,
  });

  final List<GridColumn> columns;
  final int minuteFrom;
  final int minuteTo;
  final int slotMinutes;
  final double pixelsPerMinute;
  final double minColumnWidth;
  final void Function(GridColumn column, int minute) onTapSlot;
  final ValueChanged<Appointment> onTapAppointment;

  static const _gutter = 56.0;
  static const _header = 52.0;

  @override
  Widget build(BuildContext context) {
    final bodyHeight = (minuteTo - minuteFrom) * pixelsPerMinute;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _gutter;
        final colWidth = math.max(
          minColumnWidth,
          available / math.max(1, columns.length),
        );
        final totalWidth = _gutter + colWidth * columns.length;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(totalWidth, constraints.maxWidth),
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _HeaderRow(columns: columns, columnWidth: colWidth),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: bodyHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HourGutter(
                              from: minuteFrom,
                              to: minuteTo,
                              ppm: pixelsPerMinute,
                            ),
                            for (final c in columns)
                              SizedBox(
                                width: colWidth,
                                child: _ColumnBody(
                                  column: c,
                                  from: minuteFrom,
                                  to: minuteTo,
                                  ppm: pixelsPerMinute,
                                  slot: slotMinutes,
                                  onTapSlot: (m) => onTapSlot(c, m),
                                  onTapAppointment: onTapAppointment,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Janela de horas da grade: das faixas de atendimento e dos agendamentos,
  /// arredondada para horas cheias (padrao 08:00 - 18:00).
  static ({int from, int to}) window(
    Iterable<ScheduleRange> ranges,
    Iterable<Appointment> appointments,
  ) {
    var from = 1440;
    var to = 0;
    for (final r in ranges) {
      from = math.min(from, r.qtMinuteStart);
      to = math.max(to, r.qtMinuteEnd);
    }
    for (final a in appointments) {
      if (a.idAllDay) continue;
      from = math.min(from, a.startMinute);
      to = math.max(to, a.endMinute);
    }
    if (from >= to) return (from: 480, to: 1080);
    return (
      from: (from ~/ 60) * 60,
      to: math.min(1440, ((to + 59) ~/ 60) * 60),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.columnWidth});

  final List<GridColumn> columns;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimeGrid._header,
      child: Row(
        children: [
          const SizedBox(width: TimeGrid._gutter),
          for (final c in columns)
            Container(
              width: columnWidth,
              decoration: BoxDecoration(
                color: c.highlight ? AppColors.mint : AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: c.color ?? Colors.transparent,
                    width: 3,
                  ),
                  left: const BorderSide(color: AppColors.line, width: 0.6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (c.subtitle != null)
                    Text(
                      c.subtitle!,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  const _HourGutter({required this.from, required this.to, required this.ppm});

  final int from;
  final int to;
  final double ppm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TimeGrid._gutter,
      child: Stack(
        children: [
          for (var m = from; m < to; m += 60)
            Positioned(
              top: (m - from) * ppm + 2,
              left: 0,
              right: AppSpacing.xs,
              child: Text(
                DayMinutes.format(m),
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnBody extends StatelessWidget {
  const _ColumnBody({
    required this.column,
    required this.from,
    required this.to,
    required this.ppm,
    required this.slot,
    required this.onTapSlot,
    required this.onTapAppointment,
  });

  final GridColumn column;
  final int from;
  final int to;
  final double ppm;
  final int slot;
  final ValueChanged<int> onTapSlot;
  final ValueChanged<Appointment> onTapAppointment;

  @override
  Widget build(BuildContext context) {
    final placed = layoutLanes(column.appointments);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final minute = from + d.localPosition.dy / ppm;
            onTapSlot(((minute ~/ slot) * slot).clamp(from, to - slot));
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BackgroundPainter(
                    from: from,
                    to: to,
                    ppm: ppm,
                    slot: slot,
                    available: column.available,
                  ),
                ),
              ),
              for (final p in placed)
                Positioned(
                  top: (math.max(p.a.startMinute, from) - from) * ppm,
                  height: math.max(
                    22.0,
                    (math.min(p.a.endMinute, to) -
                                math.max(p.a.startMinute, from)) *
                            ppm -
                        2,
                  ),
                  left: width * p.lane / p.lanes + 2,
                  width: width / p.lanes - 4,
                  child: AppointmentBlock(
                    appointment: p.a,
                    onTap: () => onTapAppointment(p.a),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Posicao de um cartao na coluna: faixa [lane] de [lanes] lado a lado.
class PlacedAppointment {
  const PlacedAppointment(this.a, this.lane, this.lanes);

  final Appointment a;
  final int lane;
  final int lanes;
}

/// Distribui cartoes que se sobrepoem (encaixes) lado a lado.
List<PlacedAppointment> layoutLanes(List<Appointment> items) {
  final sorted = [...items]
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  final result = <PlacedAppointment>[];
  var cluster = <(Appointment, int)>[];
  var clusterEnd = -1;
  var laneEnds = <int>[];

  void flush() {
    final lanes = laneEnds.length;
    for (final (a, lane) in cluster) {
      result.add(PlacedAppointment(a, lane, math.max(1, lanes)));
    }
    cluster = [];
    laneEnds = [];
  }

  for (final a in sorted) {
    if (a.startMinute >= clusterEnd && cluster.isNotEmpty) flush();
    var lane = laneEnds.indexWhere((end) => end <= a.startMinute);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(a.endMinute);
    } else {
      laneEnds[lane] = a.endMinute;
    }
    cluster.add((a, lane));
    clusterEnd = math.max(clusterEnd, a.endMinute);
  }
  if (cluster.isNotEmpty) flush();
  return result;
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.from,
    required this.to,
    required this.ppm,
    required this.slot,
    required this.available,
  });

  final int from;
  final int to;
  final double ppm;
  final int slot;
  final List<ScheduleRange>? available;

  @override
  void paint(Canvas canvas, Size size) {
    final off = Paint()..color = const Color(0xFFF1F3F5);
    final hatch = Paint()
      ..color = const Color(0xFFDDE2E7)
      ..strokeWidth = 1;
    if (available != null) {
      // indisponivel = tudo menos as faixas
      var cursor = from;
      final ranges = [...available!]
        ..sort((a, b) => a.qtMinuteStart.compareTo(b.qtMinuteStart));
      void paintOff(int a, int b) {
        if (b <= a) return;
        final rect = Rect.fromLTWH(
          0,
          (a - from) * ppm,
          size.width,
          (b - a) * ppm,
        );
        canvas.drawRect(rect, off);
        canvas.save();
        canvas.clipRect(rect);
        for (var x = -rect.height; x < size.width; x += 10) {
          canvas.drawLine(
            Offset(x, rect.bottom),
            Offset(x + rect.height, rect.top),
            hatch,
          );
        }
        canvas.restore();
      }

      for (final r in ranges) {
        paintOff(cursor, math.min(r.qtMinuteStart, to));
        cursor = math.max(cursor, r.qtMinuteEnd);
      }
      paintOff(cursor, to);
    }
    final line = Paint()
      ..color = AppColors.line
      ..strokeWidth = 0.6;
    final faint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.45)
      ..strokeWidth = 0.5;
    for (var m = from; m <= to; m += slot) {
      final y = (m - from) * ppm;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        m % 60 == 0 ? line : faint,
      );
    }
    canvas.drawLine(Offset.zero, Offset(0, size.height), line);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) =>
      old.from != from ||
      old.to != to ||
      old.ppm != ppm ||
      old.slot != slot ||
      old.available != available;
}

/// Cartao do agendamento na grade: cor do profissional, faixa da situacao,
/// horario e paciente (ou titulo do compromisso).
class AppointmentBlock extends StatelessWidget {
  const AppointmentBlock({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final base = a.vcProfessionalColor == null
        ? AppColors.muted
        : Color(AgendaColors.argb(a.vcProfessionalColor!));
    final status = Color(AppointmentStatus.color(a.itStatus));
    final consult = a.isConsultation;
    return Tooltip(
      message: [
        a.headline,
        if (consult) AppointmentStatus.label(a.itStatus),
        if (a.isClinicWide) Strings.forWholeClinic,
      ].join(' · '),
      child: Material(
        color: consult
            ? Color.alphaBlend(base.withValues(alpha: 0.16), Colors.white)
            : const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: consult ? status : AppColors.muted),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          fontStyle: consult ? null : FontStyle.italic,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          a.idAllDay
                              ? Strings.allDay
                              : DayMinutes.range(a.startMinute, a.endMinute),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visao mes: 6 semanas, ate 3 agendamentos por dia e "+N"; toque no dia
/// abre a visao dia.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.from,
    required this.appointments,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime from;
  final List<Appointment> appointments;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            height: 36,
            child: Row(
              children: [
                for (final d in const [0, 1, 2, 3, 4, 5, 6])
                  Expanded(
                    child: Center(
                      child: Text(
                        Weekday.short(d),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var w = 0; w < 6; w++)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: _MonthCell(
                        day: from.add(Duration(days: w * 7 + d)),
                        inMonth:
                            from.add(Duration(days: w * 7 + d)).month ==
                            month.month,
                        isToday: _same(
                          from.add(Duration(days: w * 7 + d)),
                          today,
                        ),
                        items: [
                          for (final a in appointments)
                            if (a.occursOn(from.add(Duration(days: w * 7 + d))))
                              a,
                        ],
                        onTap: onTapDay,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<Appointment> items;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(3).toList();
    return InkWell(
      onTap: () => onTap(day),
      child: Container(
        decoration: BoxDecoration(
          color: inMonth ? null : AppColors.surface,
          border: Border.all(color: AppColors.line, width: 0.4),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary : null,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isToday
                      ? Colors.white
                      : (inMonth ? AppColors.ink : AppColors.muted),
                ),
              ),
            ),
            for (final a in shown)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.vcProfessionalColor == null
                          ? AppColors.muted
                          : Color(AgendaColors.argb(a.vcProfessionalColor!)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      a.idAllDay
                          ? a.headline
                          : '${DayMinutes.format(a.startMinute)} ${a.headline}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            if (items.length > 3)
              Text(
                Strings.moreItems(items.length - 3),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
