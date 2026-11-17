/// Relatorios (ad.report_get), em grupos: agenda, pacientes, tratamentos,
/// financeiro e geral.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../agenda/domain/agenda_models.dart';
import '../../budgets/domain/budget_models.dart';
import '../../patients/domain/patient_models.dart';

/// Grupos da tela (chips de cima).
enum ReportGroup {
  agenda(Strings.reportGroupAgenda),
  patients(Strings.reportGroupPatients),
  treatments(Strings.reportGroupTreatments),
  finance(Strings.reportGroupFinance),
  general(Strings.reportGroupGeneral);

  const ReportGroup(this.label);

  final String label;

  List<ReportKind> get kinds =>
      ReportKind.values.where((k) => k.group == this).toList();
}

/// Tela que, alem de Relatorios, precisa ser lida para ver o relatorio.
enum ReportNeeds { none, finance, budgets, logs }

enum ReportKind {
  noShow('no_show', Strings.reportNoShow, ReportGroup.agenda),
  appointments('appointments', Strings.reportAppointments, ReportGroup.agenda),
  firstVisit('first_visit', Strings.reportFirstVisit, ReportGroup.agenda),
  returnAlerts(
    'return_alerts',
    Strings.reportReturnAlerts,
    ReportGroup.agenda,
    byProfessional: false,
  ),
  birthdays(
    'birthdays',
    Strings.reportBirthdays,
    ReportGroup.patients,
    byProfessional: false,
  ),
  ageGroups(
    'age_groups',
    Strings.reportAgeGroups,
    ReportGroup.patients,
    byProfessional: false,
    usesPeriod: false,
  ),
  location(
    'location',
    Strings.reportLocation,
    ReportGroup.patients,
    byProfessional: false,
    usesPeriod: false,
  ),
  lastVisit('last_visit', Strings.reportLastVisit, ReportGroup.patients),
  budgets(
    'budgets',
    Strings.reportBudgets,
    ReportGroup.patients,
    needs: ReportNeeds.budgets,
  ),
  procedures('procedures', Strings.reportProcedures, ReportGroup.treatments),
  openTreatments(
    'open_treatments',
    Strings.reportOpenTreatments,
    ReportGroup.treatments,
    needs: ReportNeeds.budgets,
  ),
  pendingProcedures(
    'pending_procedures',
    Strings.reportPendingProcedures,
    ReportGroup.treatments,
    needs: ReportNeeds.budgets,
  ),
  implants('implants', Strings.reportImplants, ReportGroup.treatments),
  revenue(
    'revenue',
    Strings.reportRevenue,
    ReportGroup.finance,
    needs: ReportNeeds.finance,
  ),
  overdue(
    'overdue',
    Strings.reportOverdue,
    ReportGroup.finance,
    byProfessional: false,
    needs: ReportNeeds.finance,
  ),
  healthPlans(
    'health_plans',
    Strings.reportHealthPlans,
    ReportGroup.finance,
    needs: ReportNeeds.finance,
  ),
  commissions(
    'commissions',
    Strings.reportCommissions,
    ReportGroup.finance,
    needs: ReportNeeds.finance,
  ),
  userAccess(
    'user_access',
    Strings.reportUserAccess,
    ReportGroup.general,
    byProfessional: false,
    needs: ReportNeeds.logs,
  ),
  userActions(
    'user_actions',
    Strings.reportUserActions,
    ReportGroup.general,
    byProfessional: false,
    needs: ReportNeeds.logs,
  ),
  messages(
    'messages',
    Strings.reportMessages,
    ReportGroup.general,
    byProfessional: false,
  );

  const ReportKind(
    this.code,
    this.label,
    this.group, {
    this.byProfessional = true,
    this.usesPeriod = true,
    this.needs = ReportNeeds.none,
  });

  final String code;
  final String label;
  final ReportGroup group;

  /// Filtra por profissional.
  final bool byProfessional;

  /// Usa o periodo (faixa etaria e localizacao sao da base toda).
  final bool usesPeriod;

  /// Outra tela que precisa ser lida.
  final ReportNeeds needs;

  /// Comissoes e os demais do financeiro exigem ler o Financeiro.
  bool get needsFinance => needs == ReportNeeds.finance;

  /// Periodo olha para frente (aniversariantes e alertas de retorno).
  bool get forward => this == birthdays || this == returnAlerts;
}

/// Uma coluna do relatorio: titulo, texto da celula e se e valor (alinha a direita).
class ReportColumn {
  const ReportColumn(this.title, this.text, {this.numeric = false});

  final String title;
  final String Function(Map<String, dynamic> row) text;
  final bool numeric;
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => v?.toString() ?? '';
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
String _phone(Object? v) {
  final s = _s(v);
  return s.isEmpty ? '' : Masks.format(MaskType.phone, s);
}

String _money(Object? v) => _num(v).toStringAsFixed(2).replaceAll('.', ',');
String _optMoney(Object? v) => v == null ? '' : _money(v);
String _qt(Object? v) => '${_int(v)}';
String _pc(Object? v) => Numbers.percent(_num(v));

String _dateTime(Object? v) {
  final d = _date(v)?.toLocal();
  return d == null ? '' : Dates.formatTime(d);
}

String _day(Object? v) {
  final d = _date(v);
  return d == null ? '' : Dates.format(d.isUtc ? d.toLocal() : d);
}

String _apptStatus(Object? v) => switch (_int(v)) {
  7 => Strings.statusNoShow,
  90 => Strings.statusCancelled,
  _ => '',
};

String _finStatus(Object? v) =>
    _int(v) == 2 ? Strings.reportPaid : Strings.reportOpen;

String _receivedStatus(Object? v) =>
    _int(v) == 2 ? Strings.reportReceived : Strings.reportToReceive;

/// Faixa etaria (it_band de fn_report_patients).
String reportAgeBand(int band) => switch (band) {
  1 => Strings.reportAge0,
  2 => Strings.reportAge13,
  3 => Strings.reportAge18,
  4 => Strings.reportAge30,
  5 => Strings.reportAge40,
  6 => Strings.reportAge50,
  7 => Strings.reportAge60,
  _ => Strings.reportAgeUnknown,
};

String _channel(Object? v) => switch (_int(v)) {
  1 => Strings.reportChannelEmail,
  2 => Strings.reportChannelSms,
  _ => Strings.reportChannelWhatsapp,
};

String _messageKind(Object? v) => switch (_int(v)) {
  1 => Strings.reportMsgReminder,
  2 => Strings.reportMsgBooked,
  3 => Strings.reportMsgBirthday,
  4 => Strings.reportMsgReturn,
  _ => '',
};

String _origin(Object? v) =>
    _int(v) == 2 ? Strings.reportOriginOnline : Strings.reportOriginAgenda;

const _colDate = Strings.reportColDate;
const _colPatient = Strings.reportColPatient;
const _colProf = Strings.reportColProfessional;

ReportColumn _patient() =>
    ReportColumn(_colPatient, (r) => _s(r['vc_patient']));
ReportColumn _mobile() =>
    ReportColumn(Strings.reportColPhone, (r) => _phone(r['vc_mobile']));
ReportColumn _prof() => ReportColumn(_colProf, (r) => _s(r['vc_professional']));
ReportColumn _user() =>
    ReportColumn(Strings.reportColUser, (r) => _s(r['vc_user']));
ReportColumn _num0(String title, String key) =>
    ReportColumn(title, (r) => _qt(r[key]), numeric: true);
ReportColumn _value(String title, String key) =>
    ReportColumn(title, (r) => _optMoney(r[key]), numeric: true);

/// Colunas de cada relatorio (tela e CSV usam as mesmas).
List<ReportColumn> reportColumns(ReportKind kind) => switch (kind) {
  ReportKind.noShow => [
    ReportColumn(_colDate, (r) => _dateTime(r['dh_start'])),
    _patient(),
    _mobile(),
    _prof(),
    ReportColumn(Strings.reportColStatus, (r) => _apptStatus(r['it_status'])),
  ],
  ReportKind.appointments => [
    ReportColumn(_colDate, (r) => _dateTime(r['dh_start'])),
    _patient(),
    _mobile(),
    _prof(),
    ReportColumn(Strings.reportColProcedure, (r) => _s(r['vc_procedure'])),
    ReportColumn(
      Strings.reportColStatus,
      (r) => AppointmentStatus.label(_int(r['it_status'])),
    ),
    ReportColumn(Strings.reportColOrigin, (r) => _origin(r['it_origin'])),
  ],
  ReportKind.firstVisit => [
    ReportColumn(_colDate, (r) => _dateTime(r['dh_start'])),
    _patient(),
    _mobile(),
    _prof(),
    ReportColumn(
      Strings.reportColStatus,
      (r) => AppointmentStatus.label(_int(r['it_status'])),
    ),
    ReportColumn(
      Strings.howFound,
      (r) => r['it_source'] == null
          ? ''
          : PatientSource.label(_int(r['it_source'])),
    ),
  ],
  ReportKind.returnAlerts => [
    ReportColumn(Strings.reportColReturn, (r) => _day(r['dt_return_alert'])),
    _patient(),
    _mobile(),
    ReportColumn(Strings.reportColReason, (r) => _s(r['vc_return_alert'])),
    ReportColumn(Strings.reportColNext, (r) => _dateTime(r['dh_next'])),
  ],
  ReportKind.birthdays => [
    ReportColumn(Strings.reportColBirthday, (r) => _day(r['dt_birthday'])),
    _patient(),
    ReportColumn(Strings.reportColAge, (r) => _s(r['qt_age']), numeric: true),
    _mobile(),
    ReportColumn(Strings.reportColEmail, (r) => _s(r['vc_email'])),
  ],
  ReportKind.ageGroups => [
    ReportColumn(
      Strings.reportColAgeGroup,
      (r) => reportAgeBand(_int(r['it_band'])),
    ),
    _num0(Strings.reportKpiPatientsAll, 'qt_patients'),
    _num0(Strings.reportColFemale, 'qt_female'),
    _num0(Strings.reportColMale, 'qt_male'),
    ReportColumn(
      Strings.reportColShare,
      (r) => _pc(r['pc_patients']),
      numeric: true,
    ),
  ],
  ReportKind.location => [
    ReportColumn(
      Strings.reportColCity,
      (r) => _s(r['vc_city']).isEmpty
          ? Strings.reportNoAddress
          : '${r['vc_city']}${_s(r['vc_state']).isEmpty ? '' : ' - ${r['vc_state']}'}',
    ),
    ReportColumn(Strings.reportColDistrict, (r) => _s(r['vc_district'])),
    _num0(Strings.reportKpiPatientsAll, 'qt_patients'),
    ReportColumn(
      Strings.reportColShare,
      (r) => _pc(r['pc_patients']),
      numeric: true,
    ),
  ],
  ReportKind.lastVisit => [
    ReportColumn(Strings.reportColLastVisit, (r) => _dateTime(r['dh_start'])),
    _patient(),
    _mobile(),
    _prof(),
    _num0(Strings.reportColDays, 'qt_days'),
  ],
  ReportKind.budgets => [
    ReportColumn(_colDate, (r) => _day(r['dt_budget'])),
    _patient(),
    _prof(),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_title'])),
    _value(Strings.reportColValue, 'vl_total'),
    ReportColumn(
      Strings.reportColStatus,
      (r) => BudgetStatus.label(_int(r['it_status'])),
    ),
  ],
  ReportKind.procedures => [
    ReportColumn(_colDate, (r) => _dateTime(r['dh_evolution'])),
    _patient(),
    ReportColumn(Strings.reportColProcedure, (r) => _s(r['vc_procedure'])),
    ReportColumn(Strings.reportColTooth, (r) => _s(r['vc_tooth'])),
    _prof(),
    _value(Strings.reportColValue, 'vl_total'),
  ],
  ReportKind.openTreatments => [
    ReportColumn(Strings.reportColApproved, (r) => _day(r['dh_accepted'])),
    _patient(),
    _mobile(),
    _prof(),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_title'])),
    ReportColumn(
      Strings.reportColDone,
      (r) => '${_int(r['qt_done'])}/${_int(r['qt_items'])}',
      numeric: true,
    ),
    _value(Strings.reportColPending, 'vl_pending'),
  ],
  ReportKind.pendingProcedures => [
    ReportColumn(Strings.reportColApproved, (r) => _day(r['dh_accepted'])),
    _patient(),
    ReportColumn(Strings.reportColProcedure, (r) => _s(r['vc_procedure'])),
    ReportColumn(Strings.reportColTooth, (r) => _s(r['vc_tooth'])),
    _prof(),
    _value(Strings.reportColValue, 'vl_total'),
  ],
  ReportKind.implants => [
    ReportColumn(_colDate, (r) => _dateTime(r['dh_evolution'])),
    _patient(),
    ReportColumn(Strings.reportColProcedure, (r) => _s(r['vc_procedure'])),
    ReportColumn(Strings.reportColTooth, (r) => _s(r['vc_tooth'])),
    _prof(),
  ],
  ReportKind.revenue => [
    ReportColumn(Strings.reportColCompetence, (r) => _day(r['dt_competence'])),
    _patient(),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_description'])),
    _prof(),
    _value(Strings.reportColValue, 'vl_amount'),
    ReportColumn(
      Strings.reportColStatus,
      (r) => _receivedStatus(r['it_status']),
    ),
    ReportColumn(Strings.reportColPaidOn, (r) => _day(r['dt_paid'])),
  ],
  ReportKind.overdue => [
    ReportColumn(Strings.reportColDue, (r) => _day(r['dt_due'])),
    _patient(),
    _mobile(),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_description'])),
    _value(Strings.reportColValue, 'vl_amount'),
    _num0(Strings.reportColDaysLate, 'qt_days_late'),
  ],
  ReportKind.healthPlans => [
    ReportColumn(Strings.reportColPlan, (r) => _s(r['vc_plan'])),
    _num0(Strings.reportColGuides, 'qt_guides'),
    _num0(Strings.reportColToInvoice, 'qt_open'),
    _value(Strings.reportColValue, 'vl_total'),
    _value(Strings.reportColInvoiced, 'vl_invoiced'),
    _value(Strings.reportColReceived, 'vl_paid'),
    _value(Strings.reportColDenied, 'vl_denied'),
  ],
  ReportKind.commissions => [
    ReportColumn(Strings.reportColCompetence, (r) => _day(r['dt_competence'])),
    _prof(),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_description'])),
    ReportColumn(Strings.reportColDue, (r) => _day(r['dt_due'])),
    _value(Strings.reportColValue, 'vl_amount'),
    ReportColumn(Strings.reportColStatus, (r) => _finStatus(r['it_status'])),
    ReportColumn(Strings.reportColPaidOn, (r) => _day(r['dt_paid'])),
  ],
  ReportKind.userAccess => [
    _user(),
    _num0(Strings.reportColAccesses, 'qt_access'),
    _num0(Strings.reportColWeb, 'qt_web'),
    _num0(Strings.reportColAndroid, 'qt_android'),
    _num0(Strings.reportColIos, 'qt_ios'),
    _num0(Strings.reportColDaysUsed, 'qt_days'),
    ReportColumn(Strings.reportColLast, (r) => _dateTime(r['dh_last'])),
  ],
  ReportKind.userActions => [
    _user(),
    _num0(Strings.reportKpiTotal, 'qt_events'),
    _num0(Strings.reportColCreated, 'qt_create'),
    _num0(Strings.reportColUpdated, 'qt_update'),
    _num0(Strings.reportColDeleted, 'qt_delete'),
    _num0(Strings.reportColOther, 'qt_other'),
    ReportColumn(Strings.reportColLast, (r) => _dateTime(r['dh_last'])),
  ],
  ReportKind.messages => [
    ReportColumn(Strings.reportColChannel, (r) => _channel(r['it_channel'])),
    ReportColumn(Strings.reportColKind, (r) => _messageKind(r['it_kind'])),
    _num0(Strings.reportKpiTotal, 'qt_total'),
    _num0(Strings.reportColSent, 'qt_sent'),
    _num0(Strings.reportColErrors, 'qt_error'),
    _num0(Strings.reportColConfirmed, 'qt_confirmed'),
  ],
};

class ReportResult {
  const ReportResult({
    required this.kind,
    this.rows = const [],
    this.summary = const {},
    this.byProfessional = const [],
    this.qtRows = 0,
    this.idTruncated = false,
  });

  factory ReportResult.fromJson(ReportKind kind, Map<String, dynamic> j) =>
      ReportResult(
        kind: kind,
        rows: ((j['rows'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        summary: ((j['summary'] as Map?) ?? const {}).cast<String, dynamic>(),
        byProfessional: ((j['by_professional'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        qtRows: _int(j['qt_rows']),
        idTruncated: j['id_truncated'] as bool? ?? false,
      );

  final ReportKind kind;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> byProfessional;
  final int qtRows;
  final bool idTruncated;

  int qt(String key) => _int(summary[key]);
  double vl(String key) => _num(summary[key]);

  /// CSV com ";" e BOM (abre direto no Excel em portugues).
  Uint8List toCsv() {
    String cell(String v) {
      final s = v.replaceAll('"', '""');
      return s.contains(';') || s.contains('"') || s.contains('\n')
          ? '"$s"'
          : s;
    }

    final cols = reportColumns(kind);
    final b = StringBuffer()..writeln(cols.map((c) => cell(c.title)).join(';'));
    for (final r in rows) {
      b.writeln(cols.map((c) => cell(c.text(r))).join(';'));
    }
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$b')]);
  }
}
