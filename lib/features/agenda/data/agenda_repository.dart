import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../domain/agenda_models.dart';

/// Campos editaveis de um profissional (ad.professional_save).
class ProfessionalDraft {
  const ProfessionalDraft({
    required this.vcName,
    this.vcCouncil,
    this.vcColor,
    this.qtSlotMinutes = 30,
    this.nrUser,
    this.itStatus,
    this.schedules = const [],
  });

  final String vcName;
  final String? vcCouncil;
  final String? vcColor;
  final int qtSlotMinutes;

  /// Usuario do sistema vinculado (null desvincula).
  final int? nrUser;

  /// Somente na alteracao (1 ativo | 90 inativo).
  final int? itStatus;
  final List<ScheduleRange> schedules;

  Map<String, dynamic> toJson() => {
    'vc_name': vcName,
    'vc_council': vcCouncil,
    if (vcColor != null) 'vc_color': vcColor,
    'qt_slot_minutes': qtSlotMinutes,
    'nr_user': nrUser,
    if (itStatus != null) 'it_status': itStatus,
    'schedules': [for (final s in schedules) s.toJson()],
  };
}

/// Campos de uma consulta ou compromisso (ad.appointment_save). Datas vao em
/// UTC (ISO com `Z`), o banco guarda com fuso.
class AppointmentDraft {
  const AppointmentDraft({
    required this.itType,
    required this.dhStart,
    required this.dhEnd,
    this.nrPatient,
    this.nrProfessional,
    this.nrProcedure,
    this.vcTitle,
    this.vcNotes,
    this.idAllDay = false,
    this.idFitIn = false,
    this.itStatus,
  });

  final int itType;
  final DateTime dhStart;
  final DateTime dhEnd;
  final int? nrPatient;

  /// Null no compromisso = clinica toda.
  final int? nrProfessional;
  final int? nrProcedure;
  final String? vcTitle;
  final String? vcNotes;
  final bool idAllDay;
  final bool idFitIn;

  /// Somente na alteracao.
  final int? itStatus;

  Map<String, dynamic> toJson() => {
    'it_type': itType,
    'nr_patient': nrPatient,
    'nr_professional': nrProfessional,
    'nr_procedure': nrProcedure,
    'vc_title': vcTitle,
    'vc_notes': vcNotes,
    'dh_start': dhStart.toUtc().toIso8601String(),
    'dh_end': dhEnd.toUtc().toIso8601String(),
    'id_all_day': idAllDay,
    'id_fit_in': idFitIn,
    if (itStatus != null) 'it_status': itStatus,
  };
}

/// RPCs da tela Agenda (schema `ad`, dados em `od`).
class AgendaRepository {
  AgendaRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<ProfessionalListData> professionals({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async {
    final json = await _gateway.rpc('professional_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'id_include_inactive': includeInactive,
    });
    return ProfessionalListData.fromJson(json);
  }

  Future<int> createProfessional({
    required int nrCompany,
    required int nrBranch,
    required ProfessionalDraft draft,
  }) async {
    final json = await _gateway.rpc('professional_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...draft.toJson(),
    });
    return (json['nr_professional'] as num).toInt();
  }

  Future<void> updateProfessional({
    required int nrCompany,
    required int nrBranch,
    required int nrProfessional,
    required ProfessionalDraft draft,
  }) async {
    await _gateway.rpc('professional_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_professional': nrProfessional,
      ...draft.toJson(),
    });
  }

  /// Consultas e compromissos de [from] a [to] (datas locais, inclusive).
  Future<AppointmentListData> appointments({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    List<int>? professionals,
    bool includeCancelled = false,
  }) async {
    final json = await _gateway.rpc('appointment_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'dt_start': Dates.toIso(from),
      'dt_end': Dates.toIso(to),
      if (professionals != null) 'nr_professionals': professionals,
      'id_include_cancelled': includeCancelled,
    });
    return AppointmentListData.fromJson(json);
  }

  /// Cria e devolve o total vencido do paciente quando a filial avisa (ou o
  /// administrador liberou com [debtOverride]); null sem pendencia.
  Future<double?> createAppointment({
    required int nrCompany,
    required int nrBranch,
    required AppointmentDraft draft,
    bool debtOverride = false,
  }) async {
    final json = await _gateway.rpc('appointment_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...draft.toJson(),
      if (debtOverride) 'id_debt_override': true,
    });
    return _debt(json);
  }

  Future<double?> updateAppointment({
    required int nrCompany,
    required int nrBranch,
    required int nrAppointment,
    required Map<String, dynamic> changes,
    bool debtOverride = false,
  }) async {
    final json = await _gateway.rpc('appointment_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_appointment': nrAppointment,
      ...changes,
      if (debtOverride) 'id_debt_override': true,
    });
    return _debt(json);
  }

  static double? _debt(Map<String, dynamic> json) {
    final d = json['debt'];
    return d is Map ? (d['vl_total'] as num?)?.toDouble() : null;
  }
}

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.watch(supabaseGatewayProvider)),
);
