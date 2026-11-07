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

/// Tipo do agendamento (od.appointment.it_type).
abstract final class AppointmentType {
  static const consultation = 1;
  static const commitment = 2;
}

/// Situacao do atendimento (od.appointment.it_status), com a cor da agenda.
abstract final class AppointmentStatus {
  static const scheduled = 1;
  static const confirmed = 2;
  static const waiting = 3;
  static const inService = 4;
  static const done = 5;
  static const late = 6;
  static const noShow = 7;
  static const cancelled = 90;

  /// Ordem do seletor de situacao.
  static const all = [
    scheduled,
    confirmed,
    waiting,
    inService,
    done,
    late,
    noShow,
    cancelled,
  ];

  static String label(int status) => switch (status) {
    scheduled => Strings.statusScheduled,
    confirmed => Strings.statusConfirmed,
    waiting => Strings.statusWaiting,
    inService => Strings.statusInService,
    done => Strings.statusDone,
    late => Strings.statusLate,
    noShow => Strings.statusNoShow,
    cancelled => Strings.statusCancelled,
    _ => '-',
  };

  /// Cor ARGB da situacao (bolinha / faixa no cartao).
  static int color(int status) => switch (status) {
    scheduled => 0xFF94A3B8,
    confirmed => 0xFF0E8C86,
    waiting => 0xFFE9A23B,
    inService => 0xFF3B82F6,
    done => 0xFF2E9E6B,
    late => 0xFFD64545,
    noShow => 0xFF334155,
    cancelled => 0xFFCBD5E1,
    _ => 0xFF94A3B8,
  };

  /// Nao ocupa o horario (pode agendar por cima).
  static bool freesSlot(int status) => status == noShow || status == cancelled;
}

/// Selo financeiro do agendamento (ad.appointment_list.it_fin_status).
abstract final class FinSeal {
  static const pending = 1;
  static const open = 2;
  static const paid = 3;

  static String label(int seal) => switch (seal) {
    pending => Strings.finSealPending,
    open => Strings.finSealOpen,
    _ => Strings.finSealPaid,
  };

  /// ARGB: pendente laranja, em aberto azul, recebido verde.
  static int color(int seal) => switch (seal) {
    pending => 0xFFE9A23B,
    open => 0xFF2F80ED,
    _ => 0xFF2E9E6B,
  };
}

/// Agendamento (consulta ou compromisso) como vem de ad.appointment_list.
/// Datas ja convertidas para a hora local do aparelho.
class Appointment {
  const Appointment({
    required this.nrAppointment,
    required this.itType,
    required this.dhStart,
    required this.dhEnd,
    this.nrPatient,
    this.vcPatientName,
    this.vcPatientMobile,
    this.nrProfessional,
    this.vcProfessionalName,
    this.vcProfessionalColor,
    this.nrProcedure,
    this.vcProcedureName,
    this.vcTitle,
    this.vcNotes,
    this.idAllDay = false,
    this.idFitIn = false,
    this.itStatus = AppointmentStatus.scheduled,
    this.vcCreatedBy,
    this.dhCreated,
    this.itFinStatus,
    this.itOrigin = 1,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    nrAppointment: _int(json['nr_appointment']),
    itType: _int(json['it_type'] ?? 1),
    dhStart: _localTime(json['dh_start']) ?? DateTime.now(),
    dhEnd: _localTime(json['dh_end']) ?? DateTime.now(),
    nrPatient: json['nr_patient'] == null ? null : _int(json['nr_patient']),
    vcPatientName: json['vc_patient_name']?.toString(),
    vcPatientMobile: json['vc_patient_mobile']?.toString(),
    nrProfessional: json['nr_professional'] == null
        ? null
        : _int(json['nr_professional']),
    vcProfessionalName: json['vc_professional_name']?.toString(),
    vcProfessionalColor: json['vc_professional_color']?.toString(),
    nrProcedure: json['nr_procedure'] == null
        ? null
        : _int(json['nr_procedure']),
    vcProcedureName: json['vc_procedure_name']?.toString(),
    vcTitle: json['vc_title']?.toString(),
    vcNotes: json['vc_notes']?.toString(),
    idAllDay: json['id_all_day'] == true,
    idFitIn: json['id_fit_in'] == true,
    itStatus: _int(json['it_status'] ?? 1),
    vcCreatedBy: json['vc_created_by']?.toString(),
    dhCreated: _localTime(json['dh_created']),
    itFinStatus: json['it_fin_status'] == null
        ? null
        : _int(json['it_fin_status']),
    itOrigin: _int(json['it_origin'] ?? 1),
  );

  final int nrAppointment;
  final int itType;
  final DateTime dhStart;
  final DateTime dhEnd;
  final int? nrPatient;
  final String? vcPatientName;
  final String? vcPatientMobile;

  /// Null no compromisso da clinica toda.
  final int? nrProfessional;
  final String? vcProfessionalName;
  final String? vcProfessionalColor;
  final int? nrProcedure;
  final String? vcProcedureName;
  final String? vcTitle;
  final String? vcNotes;
  final bool idAllDay;
  final bool idFitIn;
  final int itStatus;
  final String? vcCreatedBy;
  final DateTime? dhCreated;

  /// Selo do financeiro (so para quem le o financeiro): [FinSeal].
  final int? itFinStatus;

  /// 1 agenda | 2 agendamento online (pagina publica).
  final int itOrigin;

  bool get isOnline => itOrigin == 2;

  bool get isConsultation => itType == AppointmentType.consultation;
  bool get isClinicWide => !isConsultation && nrProfessional == null;
  bool get isCancelled => itStatus == AppointmentStatus.cancelled;

  /// Texto principal do cartao: paciente (consulta) ou titulo (compromisso).
  String get headline =>
      (isConsultation ? vcPatientName : vcTitle) ?? vcTitle ?? '-';

  /// Minutos desde a meia-noite do dia de inicio.
  int get startMinute => dhStart.hour * 60 + dhStart.minute;

  int get durationMinutes => dhEnd.difference(dhStart).inMinutes;

  /// Fim em minutos no dia de inicio (dia inteiro / passa da meia-noite = 1440).
  int get endMinute {
    final sameDay =
        dhEnd.year == dhStart.year &&
        dhEnd.month == dhStart.month &&
        dhEnd.day == dhStart.day;
    return sameDay ? dhEnd.hour * 60 + dhEnd.minute : 1440;
  }

  bool occursOn(DateTime day) =>
      dhStart.year == day.year &&
      dhStart.month == day.month &&
      dhStart.day == day.day;

  /// Aparece na coluna deste profissional (os da clinica toda em todas).
  bool belongsTo(int nrProfessional) =>
      isClinicWide || this.nrProfessional == nrProfessional;
}

/// Alerta de retorno de paciente no periodo (painel lateral).
class ReturnAlert {
  const ReturnAlert({
    required this.nrPatient,
    required this.vcName,
    this.vcMobile,
    this.dtReturnAlert,
    this.vcReturnAlert,
  });

  factory ReturnAlert.fromJson(Map<String, dynamic> json) => ReturnAlert(
    nrPatient: _int(json['nr_patient']),
    vcName: json['vc_name']?.toString() ?? '',
    vcMobile: json['vc_mobile']?.toString(),
    dtReturnAlert: DateTime.tryParse(json['dt_return_alert']?.toString() ?? ''),
    vcReturnAlert: json['vc_return_alert']?.toString(),
  );

  final int nrPatient;
  final String vcName;
  final String? vcMobile;
  final DateTime? dtReturnAlert;
  final String? vcReturnAlert;
}

/// Resposta de ad.appointment_list.
class AppointmentListData {
  const AppointmentListData({
    this.appointments = const [],
    this.returnAlerts = const [],
  });

  factory AppointmentListData.fromJson(Map<String, dynamic> json) =>
      AppointmentListData(
        appointments: [
          for (final a in _list(json['appointments']))
            Appointment.fromJson((a as Map).cast<String, dynamic>()),
        ],
        returnAlerts: [
          for (final r in _list(json['return_alerts']))
            ReturnAlert.fromJson((r as Map).cast<String, dynamic>()),
        ],
      );

  final List<Appointment> appointments;
  final List<ReturnAlert> returnAlerts;
}

/// Visualizacao da grade.
enum AgendaView { day, week, month }

/// Periodo coberto pela visualizacao (inclusive), em datas locais.
({DateTime from, DateTime to}) agendaRange(AgendaView view, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  switch (view) {
    case AgendaView.day:
      return (from: d, to: d);
    case AgendaView.week:
      // semana de domingo a sabado
      final start = d.subtract(Duration(days: d.weekday % 7));
      return (from: start, to: start.add(const Duration(days: 6)));
    case AgendaView.month:
      // grade do mes: 6 semanas a partir do domingo antes do dia 1
      final first = DateTime(d.year, d.month);
      final start = first.subtract(Duration(days: first.weekday % 7));
      return (from: start, to: start.add(const Duration(days: 41)));
  }
}

/// ISO com fuso do backend -> hora local do aparelho.
DateTime? _localTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal();
}
