import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/patient_file_repository.dart';
import '../domain/patient_file_models.dart';

typedef PatientFileKey = ({int nrPatient, PatientFileType type});

/// Arquivos do paciente com as URLs assinadas das imagens que o app mostra.
class PatientFileView {
  const PatientFileView({
    this.list = const PatientFileList(),
    this.urls = const {},
  });

  final PatientFileList list;
  final Map<int, String> urls;
}

final patientFilesProvider = FutureProvider.autoDispose
    .family<PatientFileView, PatientFileKey>((ref, key) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const PatientFileView();
      final repo = ref.read(patientFileRepositoryProvider);
      final list = await repo.list(c, b, key.nrPatient, key.type);
      final viewable = [
        for (final f in list.files)
          if (f.isViewableImage) f.nrFile,
      ];
      Map<int, String> urls = const {};
      try {
        urls = await repo.urls(c, b, key.nrPatient, viewable);
      } catch (_) {
        // sem as miniaturas a lista ainda funciona (download por arquivo)
      }
      return PatientFileView(list: list, urls: urls);
    });

/// Escritas de fotos e exames.
class PatientFileActions {
  PatientFileActions(this._ref);

  final Ref _ref;

  ({int c, int b}) get _branch {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return (c: c, b: b);
  }

  PatientFileRepository get _repo => _ref.read(patientFileRepositoryProvider);

  void _refresh(PatientFileKey key) =>
      _ref.invalidate(patientFilesProvider(key));

  Future<void> upload(
    PatientFileKey key, {
    required String name,
    required String mime,
    required Uint8List bytes,
    Map<String, dynamic> fields = const {},
  }) async {
    final x = _branch;
    await _repo.upload(
      x.c,
      x.b,
      key.nrPatient,
      type: key.type,
      name: name,
      mime: mime,
      bytes: bytes,
      fields: fields,
    );
  }

  /// Chamado depois de um lote de uploads.
  void refresh(PatientFileKey key) => _refresh(key);

  Future<Uint8List> download(PatientFileKey key, int nrFile) {
    final x = _branch;
    return _repo.download(x.c, x.b, key.nrPatient, nrFile);
  }

  Future<void> update(
    PatientFileKey key,
    int nrFile,
    Map<String, dynamic> fields,
  ) async {
    final x = _branch;
    await _repo.update(x.c, x.b, key.nrPatient, nrFile, fields);
    _refresh(key);
  }

  Future<void> delete(PatientFileKey key, int nrFile) async {
    final x = _branch;
    await _repo.delete(x.c, x.b, key.nrPatient, nrFile);
    _refresh(key);
  }
}

final patientFileActionsProvider = Provider<PatientFileActions>(
  PatientFileActions.new,
);
