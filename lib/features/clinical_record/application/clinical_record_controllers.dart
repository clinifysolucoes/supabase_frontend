import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/clinical_record_repository.dart';
import '../domain/clinical_record_models.dart';

({int c, int b})? _branchOf(Ref ref) {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  return c == null || b == null ? null : (c: c, b: b);
}

/// Prontuario de um paciente.
final clinicalRecordProvider = FutureProvider.autoDispose
    .family<PatientClinicalRecord, int>((ref, nrPatient) async {
      final x = _branchOf(ref);
      if (x == null) return const PatientClinicalRecord();
      return ref
          .read(clinicalRecordRepositoryProvider)
          .get(x.c, x.b, nrPatient);
    });

/// Modelos de anamnese ativos ([true] = inclui inativos, Configuracoes).
final anamnesisModelsProvider = FutureProvider.autoDispose
    .family<AnamnesisModelList, bool>((ref, includeInactive) async {
      final x = _branchOf(ref);
      if (x == null) return const AnamnesisModelList();
      return ref
          .read(clinicalRecordRepositoryProvider)
          .models(x.c, x.b, includeInactive: includeInactive);
    });

/// Escritas do prontuario: chamam a RPC e recarregam.
class ClinicalRecordActions {
  ClinicalRecordActions(this._ref);

  final Ref _ref;

  ({int c, int b}) get _branch {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return (c: c, b: b);
  }

  ClinicalRecordRepository get _repo =>
      _ref.read(clinicalRecordRepositoryProvider);

  Future<void> _patient(
    int nrPatient,
    Future<void> Function(int c, int b) call,
  ) async {
    final x = _branch;
    await call(x.c, x.b);
    _ref.invalidate(clinicalRecordProvider(nrPatient));
  }

  Future<void> fillAnamnesis(int nrPatient, Map<String, dynamic> f) => _patient(
    nrPatient,
    (c, b) => _repo.saveAnamnesis(c, b, nrPatient, {'vc_action': 'I', ...f}),
  );

  Future<void> deleteAnamnesis(int nrPatient, int nrAnamnesis) => _patient(
    nrPatient,
    (c, b) => _repo.saveAnamnesis(c, b, nrPatient, {
      'vc_action': 'D',
      'nr_anamnesis': nrAnamnesis,
    }),
  );

  Future<void> addEvolution(int nrPatient, Map<String, dynamic> f) => _patient(
    nrPatient,
    (c, b) => _repo.saveEvolution(c, b, nrPatient, {'vc_action': 'I', ...f}),
  );

  Future<void> deleteEvolution(int nrPatient, int nrEvolution) => _patient(
    nrPatient,
    (c, b) => _repo.saveEvolution(c, b, nrPatient, {
      'vc_action': 'D',
      'nr_evolution': nrEvolution,
    }),
  );

  /// Marca ([nrMark] null), altera ou remove ([delete]).
  Future<void> saveMark(
    int nrPatient, {
    int? nrMark,
    bool delete = false,
    Map<String, dynamic> fields = const {},
  }) => _patient(
    nrPatient,
    (c, b) => _repo.saveMark(c, b, nrPatient, {
      'vc_action': delete ? 'D' : (nrMark == null ? 'I' : 'U'),
      'nr_mark': ?nrMark,
      ...fields,
    }),
  );

  Future<void> saveModel({
    int? nrModel,
    required Map<String, dynamic> fields,
  }) async {
    final x = _branch;
    await _repo.saveModel(x.c, x.b, nrModel: nrModel, fields: fields);
    _ref.invalidate(anamnesisModelsProvider);
  }
}

final clinicalRecordActionsProvider = Provider<ClinicalRecordActions>(
  ClinicalRecordActions.new,
);
