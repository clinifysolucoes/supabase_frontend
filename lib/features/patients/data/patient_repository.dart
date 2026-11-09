import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/patient_models.dart';
import '../domain/patient_summary_models.dart';

/// Filtros de `patient_list`.
class PatientFilters {
  const PatientFilters({
    this.search = '',
    this.includeInactive = false,
    this.page = 1,
    this.pageSize = 50,
  });

  final String search;
  final bool includeInactive;
  final int page;
  final int pageSize;

  PatientFilters copyWith({String? search, bool? includeInactive, int? page}) =>
      PatientFilters(
        search: search ?? this.search,
        includeInactive: includeInactive ?? this.includeInactive,
        page: page ?? this.page,
        pageSize: pageSize,
      );
}

/// RPCs da tela Pacientes (schema `ad`, dados em `od`).
///
/// O cadastro e enviado como mapa `coluna -> valor` com as MESMAS chaves do
/// backend (`vc_name`, `dt_birth`...): chave presente altera (null limpa),
/// ausente mantem (update parcial de patient_save). Documentos, telefones e
/// CEP vao sem mascara (`Masks.unmask`), datas em ISO (`Dates.toIso`).
class PatientRepository {
  PatientRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<PatientPage> list({
    required int nrCompany,
    required int nrBranch,
    required PatientFilters filters,
  }) async {
    final json = await _gateway.rpc('patient_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      if (filters.search.trim().isNotEmpty) 'vc_search': filters.search.trim(),
      'id_include_inactive': filters.includeInactive,
      'nr_page': filters.page,
      'qt_page_size': filters.pageSize,
    });
    return PatientPage.fromJson(json);
  }

  Future<PatientRecord> get({
    required int nrCompany,
    required int nrBranch,
    required int nrPatient,
  }) async {
    final json = await _gateway.rpc('patient_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': nrPatient,
    });
    return PatientRecord.fromJson(json);
  }

  /// Cria e devolve o nr_patient.
  Future<int> create({
    required int nrCompany,
    required int nrBranch,
    required Map<String, dynamic> fields,
  }) async {
    final json = await _gateway.rpc('patient_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...fields,
    });
    return (json['nr_patient'] as num).toInt();
  }

  /// Update parcial: so as chaves presentes em [fields].
  Future<void> update({
    required int nrCompany,
    required int nrBranch,
    required int nrPatient,
    required Map<String, dynamic> fields,
  }) async {
    await _gateway.rpc('patient_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': nrPatient,
      ...fields,
    });
  }

  Future<int> addNote({
    required int nrCompany,
    required int nrBranch,
    required int nrPatient,
    required String text,
  }) async {
    final json = await _gateway.rpc('patient_note_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': nrPatient,
      'vc_note': text,
    });
    return (json['nr_note'] as num).toInt();
  }

  Future<void> deleteNote({
    required int nrCompany,
    required int nrBranch,
    required int nrPatient,
    required int nrNote,
  }) async {
    await _gateway.rpc('patient_note_save', {
      'vc_action': 'D',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': nrPatient,
      'nr_note': nrNote,
    });
  }

  /// Abas Agendamentos, Financeiro e Plano de tratamento da ficha.
  Future<PatientSummary> summary({
    required int nrCompany,
    required int nrBranch,
    required int nrPatient,
  }) async => PatientSummary.fromJson(
    await _gateway.rpc('patient_summary_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': nrPatient,
    }),
  );
}

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => PatientRepository(ref.watch(supabaseGatewayProvider)),
);
