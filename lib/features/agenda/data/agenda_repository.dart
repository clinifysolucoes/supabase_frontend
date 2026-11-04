import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
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
}

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.watch(supabaseGatewayProvider)),
);
