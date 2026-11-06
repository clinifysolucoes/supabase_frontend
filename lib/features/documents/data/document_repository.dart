import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/document_models.dart';

/// RPCs de documentos, modelos e medicamentos.
class DocumentRepository {
  DocumentRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<DocumentTemplateList> templates(
    int c,
    int b, {
    bool includeInactive = false,
  }) async => DocumentTemplateList.fromJson(
    await _gateway.rpc('document_template_list', {
      'nr_company': c,
      'nr_branch': b,
      'id_include_inactive': includeInactive,
    }),
  );

  Future<void> saveTemplate(
    int c,
    int b, {
    int? nrTemplate,
    required Map<String, dynamic> fields,
  }) => _gateway.rpc('document_template_save', {
    'vc_action': nrTemplate == null ? 'I' : 'U',
    'nr_company': c,
    'nr_branch': b,
    'nr_template': ?nrTemplate,
    ...fields,
  });

  Future<MedicationList> medications(
    int c,
    int b, {
    bool includeInactive = false,
    String? search,
  }) async => MedicationList.fromJson(
    await _gateway.rpc('medication_list', {
      'nr_company': c,
      'nr_branch': b,
      'id_include_inactive': includeInactive,
      if (search != null && search.isNotEmpty) 'vc_search': search,
    }),
  );

  Future<void> saveMedication(
    int c,
    int b, {
    int? nrMedication,
    required Map<String, dynamic> fields,
  }) => _gateway.rpc('medication_save', {
    'vc_action': nrMedication == null ? 'I' : 'U',
    'nr_company': c,
    'nr_branch': b,
    'nr_medication': ?nrMedication,
    ...fields,
  });

  Future<PatientDocumentList> list(int c, int b, int nrPatient) async =>
      PatientDocumentList.fromJson(
        await _gateway.rpc('patient_document_list', {
          'nr_company': c,
          'nr_branch': b,
          'nr_patient': nrPatient,
        }),
      );

  Future<String> render(
    int c,
    int b,
    int nrPatient, {
    int? nrTemplate,
    String? body,
    int? nrProfessional,
    Map<String, String> extra = const {},
  }) async {
    final r = await _gateway.rpc('patient_document_render', {
      'nr_company': c,
      'nr_branch': b,
      'nr_patient': nrPatient,
      'nr_template': ?nrTemplate,
      'vc_body': ?body,
      'nr_professional': ?nrProfessional,
      'extra': extra,
    });
    return r['vc_body'] as String? ?? '';
  }

  Future<void> save(int c, int b, int nrPatient, Map<String, dynamic> f) =>
      _gateway.rpc('patient_document_save', {
        'nr_company': c,
        'nr_branch': b,
        'nr_patient': nrPatient,
        ...f,
      });
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(supabaseGatewayProvider)),
);
