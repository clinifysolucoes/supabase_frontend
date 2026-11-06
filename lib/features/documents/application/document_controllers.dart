import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/document_repository.dart';
import '../domain/document_models.dart';

({int c, int b})? _branchOf(Ref ref) {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  return c == null || b == null ? null : (c: c, b: b);
}

/// Documentos emitidos de um paciente.
final patientDocumentsProvider = FutureProvider.autoDispose
    .family<PatientDocumentList, int>((ref, nrPatient) async {
      final x = _branchOf(ref);
      if (x == null) return const PatientDocumentList();
      return ref.read(documentRepositoryProvider).list(x.c, x.b, nrPatient);
    });

/// Modelos de documento ([true] = inclui inativos, Configuracoes).
final documentTemplatesProvider = FutureProvider.autoDispose
    .family<DocumentTemplateList, bool>((ref, includeInactive) async {
      final x = _branchOf(ref);
      if (x == null) return const DocumentTemplateList();
      return ref
          .read(documentRepositoryProvider)
          .templates(x.c, x.b, includeInactive: includeInactive);
    });

/// Medicamentos ([true] = inclui inativos, Configuracoes).
final medicationsProvider = FutureProvider.autoDispose
    .family<MedicationList, bool>((ref, includeInactive) async {
      final x = _branchOf(ref);
      if (x == null) return const MedicationList();
      return ref
          .read(documentRepositoryProvider)
          .medications(x.c, x.b, includeInactive: includeInactive);
    });

/// Escritas de documentos: chamam a RPC e recarregam.
class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  ({int c, int b}) get _branch {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return (c: c, b: b);
  }

  DocumentRepository get _repo => _ref.read(documentRepositoryProvider);

  Future<String> render(
    int nrPatient, {
    int? nrTemplate,
    String? body,
    int? nrProfessional,
    Map<String, String> extra = const {},
  }) {
    final x = _branch;
    return _repo.render(
      x.c,
      x.b,
      nrPatient,
      nrTemplate: nrTemplate,
      body: body,
      nrProfessional: nrProfessional,
      extra: extra,
    );
  }

  Future<void> emit(int nrPatient, Map<String, dynamic> fields) async {
    final x = _branch;
    await _repo.save(x.c, x.b, nrPatient, {'vc_action': 'I', ...fields});
    _ref.invalidate(patientDocumentsProvider(nrPatient));
  }

  Future<void> delete(int nrPatient, int nrDocument) async {
    final x = _branch;
    await _repo.save(x.c, x.b, nrPatient, {
      'vc_action': 'D',
      'nr_document': nrDocument,
    });
    _ref.invalidate(patientDocumentsProvider(nrPatient));
  }

  Future<void> saveTemplate({
    int? nrTemplate,
    required Map<String, dynamic> fields,
  }) async {
    final x = _branch;
    await _repo.saveTemplate(x.c, x.b, nrTemplate: nrTemplate, fields: fields);
    _ref.invalidate(documentTemplatesProvider);
  }

  Future<void> saveMedication({
    int? nrMedication,
    required Map<String, dynamic> fields,
  }) async {
    final x = _branch;
    await _repo.saveMedication(
      x.c,
      x.b,
      nrMedication: nrMedication,
      fields: fields,
    );
    _ref.invalidate(medicationsProvider);
  }
}

final documentActionsProvider = Provider<DocumentActions>(DocumentActions.new);
