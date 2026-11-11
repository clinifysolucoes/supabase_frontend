/// Dashboard Analitico (ad.dashboard_get). Cada parte vem null sem permissao
/// da tela dela (AGENDA, PATIENTS, BUDGETS, FINANCE).
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
Map<String, dynamic>? _map(Object? v) =>
    v == null ? null : (v as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();

/// Variacao percentual entre o periodo e o anterior (null sem base).
double? deltaPercent(num current, num previous) =>
    previous == 0 ? null : (current - previous) * 100 / previous;

class DashboardAgenda {
  const DashboardAgenda({
    this.qtAppointments = 0,
    this.qtAttended = 0,
    this.qtNoShow = 0,
    this.qtCancelled = 0,
    this.pcNoShow = 0,
    this.qtOnline = 0,
    this.qtAppointmentsPrev = 0,
    this.qtToday = 0,
    this.qtTodayConfirmed = 0,
  });

  factory DashboardAgenda.fromJson(Map<String, dynamic> j) => DashboardAgenda(
    qtAppointments: _int(j['qt_appointments']),
    qtAttended: _int(j['qt_attended']),
    qtNoShow: _int(j['qt_no_show']),
    qtCancelled: _int(j['qt_cancelled']),
    pcNoShow: _num(j['pc_no_show']),
    qtOnline: _int(j['qt_online']),
    qtAppointmentsPrev: _int(j['qt_appointments_prev']),
    qtToday: _int(j['qt_today']),
    qtTodayConfirmed: _int(j['qt_today_confirmed']),
  );

  final int qtAppointments;
  final int qtAttended;
  final int qtNoShow;
  final int qtCancelled;
  final double pcNoShow;
  final int qtOnline;
  final int qtAppointmentsPrev;
  final int qtToday;
  final int qtTodayConfirmed;
}

class DashboardPatients {
  const DashboardPatients({
    this.qtNew = 0,
    this.qtNewPrev = 0,
    this.qtActive = 0,
    this.qtBirthdaysToday = 0,
    this.qtProcedures = 0,
    this.bySource = const [],
    this.topProcedures = const [],
  });

  factory DashboardPatients.fromJson(Map<String, dynamic> j) =>
      DashboardPatients(
        qtNew: _int(j['qt_new']),
        qtNewPrev: _int(j['qt_new_prev']),
        qtActive: _int(j['qt_active']),
        qtBirthdaysToday: _int(j['qt_birthdays_today']),
        qtProcedures: _int(j['qt_procedures']),
        bySource: [
          for (final s in _list(j['by_source']))
            (source: (s['it_source'] as num?)?.toInt(), qt: _int(s['qt'])),
        ],
        topProcedures: [
          for (final p in _list(j['top_procedures']))
            (name: p['vc_procedure']?.toString() ?? '', qt: _int(p['qt'])),
        ],
      );

  final int qtNew;
  final int qtNewPrev;
  final int qtActive;
  final int qtBirthdaysToday;
  final int qtProcedures;

  /// Origem dos pacientes novos (it_source null = nao informada).
  final List<({int? source, int qt})> bySource;
  final List<({String name, int qt})> topProcedures;
}

class DashboardBudgets {
  const DashboardBudgets({
    this.qtCreated = 0,
    this.vlCreated = 0,
    this.qtAccepted = 0,
    this.vlAccepted = 0,
    this.pcConversion = 0,
    this.qtOpen = 0,
    this.vlOpen = 0,
  });

  factory DashboardBudgets.fromJson(Map<String, dynamic> j) => DashboardBudgets(
    qtCreated: _int(j['qt_created']),
    vlCreated: _num(j['vl_created']),
    qtAccepted: _int(j['qt_accepted']),
    vlAccepted: _num(j['vl_accepted']),
    pcConversion: _num(j['pc_conversion']),
    qtOpen: _int(j['qt_open']),
    vlOpen: _num(j['vl_open']),
  );

  final int qtCreated;
  final double vlCreated;
  final int qtAccepted;
  final double vlAccepted;
  final double pcConversion;
  final int qtOpen;
  final double vlOpen;
}

class DashboardFinance {
  const DashboardFinance({
    this.vlRevenue = 0,
    this.vlExpense = 0,
    this.vlResult = 0,
    this.vlRevenuePrev = 0,
    this.vlOverdue = 0,
    this.qtOverdue = 0,
    this.vlPayableWeek = 0,
  });

  factory DashboardFinance.fromJson(Map<String, dynamic> j) => DashboardFinance(
    vlRevenue: _num(j['vl_revenue']),
    vlExpense: _num(j['vl_expense']),
    vlResult: _num(j['vl_result']),
    vlRevenuePrev: _num(j['vl_revenue_prev']),
    vlOverdue: _num(j['vl_overdue']),
    qtOverdue: _int(j['qt_overdue']),
    vlPayableWeek: _num(j['vl_payable_week']),
  );

  final double vlRevenue;
  final double vlExpense;
  final double vlResult;
  final double vlRevenuePrev;
  final double vlOverdue;
  final int qtOverdue;
  final double vlPayableWeek;
}

/// Um mes da serie; campo null = parte sem permissao.
class DashboardMonth {
  const DashboardMonth({
    required this.month,
    this.qtAttended,
    this.qtNewPatients,
    this.vlRevenue,
    this.vlExpense,
  });

  factory DashboardMonth.fromJson(Map<String, dynamic> j) => DashboardMonth(
    month: DateTime.tryParse(j['dt_month'] as String? ?? '') ?? DateTime(2000),
    qtAttended: (j['qt_attended'] as num?)?.toInt(),
    qtNewPatients: (j['qt_new_patients'] as num?)?.toInt(),
    vlRevenue: (j['vl_revenue'] as num?)?.toDouble(),
    vlExpense: (j['vl_expense'] as num?)?.toDouble(),
  );

  final DateTime month;
  final int? qtAttended;
  final int? qtNewPatients;
  final double? vlRevenue;
  final double? vlExpense;
}

class DashboardData {
  const DashboardData({
    this.agenda,
    this.patients,
    this.budgets,
    this.finance,
    this.series = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final a = _map(j['agenda']);
    final p = _map(j['patients']);
    final b = _map(j['budgets']);
    final f = _map(j['finance']);
    return DashboardData(
      agenda: a == null ? null : DashboardAgenda.fromJson(a),
      patients: p == null ? null : DashboardPatients.fromJson(p),
      budgets: b == null ? null : DashboardBudgets.fromJson(b),
      finance: f == null ? null : DashboardFinance.fromJson(f),
      series: _list(j['series']).map(DashboardMonth.fromJson).toList(),
    );
  }

  final DashboardAgenda? agenda;
  final DashboardPatients? patients;
  final DashboardBudgets? budgets;
  final DashboardFinance? finance;
  final List<DashboardMonth> series;

  /// Nenhuma parte permitida: o painel mostra so a mensagem de boas-vindas.
  bool get isEmpty =>
      agenda == null && patients == null && budgets == null && finance == null;
}

/// Periodos de atalho do painel.
enum DashboardPeriod { thisMonth, lastMonth, thisYear }

({DateTime from, DateTime to}) dashboardRange(
  DashboardPeriod p,
  DateTime now,
) => switch (p) {
  DashboardPeriod.thisMonth => (
    from: DateTime(now.year, now.month),
    to: DateTime(now.year, now.month + 1, 0),
  ),
  DashboardPeriod.lastMonth => (
    from: DateTime(now.year, now.month - 1),
    to: DateTime(now.year, now.month, 0),
  ),
  DashboardPeriod.thisYear => (
    from: DateTime(now.year),
    to: DateTime(now.year, 12, 31),
  ),
};
