import '../../../l10n/strings.dart';

/// Dia da semana como no banco (od.professional_schedule.it_weekday):
/// 0 domingo .. 6 sabado.
abstract final class Weekday {
  static const all = [1, 2, 3, 4, 5, 6, 0];

  static String label(int day) => switch (day) {
    0 => Strings.weekdaySunday,
    1 => Strings.weekdayMonday,
    2 => Strings.weekdayTuesday,
    3 => Strings.weekdayWednesday,
    4 => Strings.weekdayThursday,
    5 => Strings.weekdayFriday,
    6 => Strings.weekdaySaturday,
    _ => '-',
  };

  static String short(int day) => label(day).substring(0, 3);

  /// DateTime.weekday (1 segunda .. 7 domingo) -> it_weekday.
  static int fromDate(DateTime d) => d.weekday % 7;
}

/// Minutos desde a meia-noite <-> "08:30".
abstract final class DayMinutes {
  static String format(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String range(int start, int end) =>
      '${format(start)} – ${format(end)}';
}

/// Cores da paleta da agenda (mesma ordem da paleta padrao do banco).
abstract final class AgendaColors {
  static const palette = [
    '#0E8C86',
    '#E9A23B',
    '#6C5CE7',
    '#D64545',
    '#2E9E6B',
    '#3B82F6',
    '#DB2777',
    '#E07B2E',
    '#14B8A6',
    '#64748B',
  ];

  /// "#0E8C86" -> 0xFF0E8C86.
  static int argb(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x0E8C86;
    return 0xFF000000 | v;
  }
}

/// Faixa de atendimento (od.professional_schedule).
class ScheduleRange {
  const ScheduleRange({
    required this.itWeekday,
    required this.qtMinuteStart,
    required this.qtMinuteEnd,
  });

  factory ScheduleRange.fromJson(Map<String, dynamic> json) => ScheduleRange(
    itWeekday: _int(json['it_weekday']),
    qtMinuteStart: _int(json['qt_minute_start']),
    qtMinuteEnd: _int(json['qt_minute_end']),
  );

  final int itWeekday;
  final int qtMinuteStart;
  final int qtMinuteEnd;

  bool get isValid => qtMinuteStart < qtMinuteEnd;

  bool overlaps(ScheduleRange o) =>
      o.itWeekday == itWeekday &&
      qtMinuteStart < o.qtMinuteEnd &&
      o.qtMinuteStart < qtMinuteEnd;

  ScheduleRange copyWith({
    int? itWeekday,
    int? qtMinuteStart,
    int? qtMinuteEnd,
  }) => ScheduleRange(
    itWeekday: itWeekday ?? this.itWeekday,
    qtMinuteStart: qtMinuteStart ?? this.qtMinuteStart,
    qtMinuteEnd: qtMinuteEnd ?? this.qtMinuteEnd,
  );

  Map<String, dynamic> toJson() => {
    'it_weekday': itWeekday,
    'qt_minute_start': qtMinuteStart,
    'qt_minute_end': qtMinuteEnd,
  };
}

/// Profissional da agenda (od.professional) com o horario de atendimento.
class Professional {
  const Professional({
    required this.nrProfessional,
    required this.vcName,
    this.vcCouncil,
    this.vcColor = '#0E8C86',
    this.qtSlotMinutes = 30,
    this.nrUser,
    this.vcUserName,
    this.itStatus = 1,
    this.schedules = const [],
  });

  factory Professional.fromJson(Map<String, dynamic> json) => Professional(
    nrProfessional: _int(json['nr_professional']),
    vcName: json['vc_name']?.toString() ?? '',
    vcCouncil: json['vc_council']?.toString(),
    vcColor: json['vc_color']?.toString() ?? '#0E8C86',
    qtSlotMinutes: _int(json['qt_slot_minutes'] ?? 30),
    nrUser: json['nr_user'] == null ? null : _int(json['nr_user']),
    vcUserName: json['vc_user_name']?.toString(),
    itStatus: _int(json['it_status'] ?? 1),
    schedules: [
      for (final s in _list(json['schedules']))
        ScheduleRange.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );

  final int nrProfessional;
  final String vcName;
  final String? vcCouncil;
  final String vcColor;
  final int qtSlotMinutes;
  final int? nrUser;
  final String? vcUserName;
  final int itStatus;
  final List<ScheduleRange> schedules;

  bool get isActive => itStatus == 1;

  List<ScheduleRange> rangesOf(int weekday) => [
    for (final s in schedules)
      if (s.itWeekday == weekday) s,
  ]..sort((a, b) => a.qtMinuteStart.compareTo(b.qtMinuteStart));

  /// Horas de atendimento por semana.
  double get weeklyHours =>
      schedules.fold<int>(0, (t, s) => t + s.qtMinuteEnd - s.qtMinuteStart) /
      60;
}

/// Usuario ativo da empresa que pode ser vinculado a um profissional.
class AgendaUser {
  const AgendaUser({required this.nrUser, required this.vcName, this.vcEmail});

  factory AgendaUser.fromJson(Map<String, dynamic> json) => AgendaUser(
    nrUser: _int(json['nr_user']),
    vcName: json['vc_name']?.toString() ?? '',
    vcEmail: json['vc_email']?.toString(),
  );

  final int nrUser;
  final String vcName;
  final String? vcEmail;
}

/// Resposta de ad.professional_list.
class ProfessionalListData {
  const ProfessionalListData({
    this.professionals = const [],
    this.users = const [],
  });

  factory ProfessionalListData.fromJson(Map<String, dynamic> json) =>
      ProfessionalListData(
        professionals: [
          for (final p in _list(json['professionals']))
            Professional.fromJson((p as Map).cast<String, dynamic>()),
        ],
        users: [
          for (final u in _list(json['users']))
            AgendaUser.fromJson((u as Map).cast<String, dynamic>()),
        ],
      );

  final List<Professional> professionals;
  final List<AgendaUser> users;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];
