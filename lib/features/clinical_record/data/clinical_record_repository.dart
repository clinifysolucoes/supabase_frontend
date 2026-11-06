import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/clinical_record_models.dart';

/// RPCs do prontuario (anamnese, evolucao, odontograma).
class ClinicalRecordRepository {
  ClinicalRecordRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<PatientClinicalRecord> get(int c, int b, int nrPatient) async =>
      PatientClinicalRecord.fromJson(
        await _gateway.rpc('patient_record_get', {
          'nr_company': c,
          'nr_branch': b,
          'nr_patient': nrPatient,
        }),
      );

  Future<AnamnesisModelList> models(
    int c,
    int b, {
    bool includeInactive = false,
  }) async => AnamnesisModelList.fromJson(
    await _gateway.rpc('anamnesis_model_list', {
      'nr_company': c,
      'nr_branch': b,
      'id_include_inactive': includeInactive,
    }),
  );

  Future<void> saveModel(
    int c,
    int b, {
    int? nrModel,
    required Map<String, dynamic> fields,
  }) => _gateway.rpc('anamnesis_model_save', {
    'vc_action': nrModel == null ? 'I' : 'U',
    'nr_company': c,
    'nr_branch': b,
    'nr_model': ?nrModel,
    ...fields,
  });

  Future<void> _patient(
    String fn,
    int c,
    int b,
    int nrPatient,
    Map<String, dynamic> fields,
  ) => _gateway.rpc(fn, {
    'nr_company': c,
    'nr_branch': b,
    'nr_patient': nrPatient,
    ...fields,
  });

  Future<void> saveAnamnesis(int c, int b, int p, Map<String, dynamic> f) =>
      _patient('patient_anamnesis_save', c, b, p, f);

  Future<void> saveEvolution(int c, int b, int p, Map<String, dynamic> f) =>
      _patient('clinical_evolution_save', c, b, p, f);

  Future<void> saveMark(int c, int b, int p, Map<String, dynamic> f) =>
      _patient('tooth_mark_save', c, b, p, f);
}

final clinicalRecordRepositoryProvider = Provider<ClinicalRecordRepository>(
  (ref) => ClinicalRecordRepository(ref.watch(supabaseGatewayProvider)),
);
