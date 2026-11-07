import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/patient_file_models.dart';

/// Fotos e exames: lista pela RPC; upload, visualizacao, download e exclusao
/// pela Edge Function patient-file (URLs assinadas do bucket privado).
class PatientFileRepository {
  PatientFileRepository(this._gateway);

  final SupabaseGateway _gateway;

  static const _fn = 'patient-file';
  static const _bucket = 'patient';

  Map<String, dynamic> _base(int c, int b, int p) => {
    'nr_company': c,
    'nr_branch': b,
    'nr_patient': p,
  };

  Future<PatientFileList> list(
    int c,
    int b,
    int p,
    PatientFileType type,
  ) async => PatientFileList.fromJson(
    await _gateway.rpc('patient_file_list', {
      ..._base(c, b, p),
      'it_type': type.code,
    }),
  );

  /// URLs assinadas (10 minutos) para mostrar as imagens.
  Future<Map<int, String>> urls(int c, int b, int p, List<int> files) async {
    if (files.isEmpty) return const {};
    final r = await _gateway.invokeFunction(_fn, {
      'action': 'urls',
      ..._base(c, b, p),
      'nr_files': files,
    });
    final m = (r['urls'] as Map?) ?? const {};
    return {
      for (final e in m.entries) int.parse(e.key.toString()): e.value as String,
    };
  }

  /// Envia: a Edge Function valida e reserva o caminho; o arquivo sobe pela
  /// URL assinada. Se o envio falhar, o registro e excluido.
  Future<void> upload(
    int c,
    int b,
    int p, {
    required PatientFileType type,
    required String name,
    required String mime,
    required Uint8List bytes,
    Map<String, dynamic> fields = const {},
  }) async {
    final r = await _gateway.invokeFunction(_fn, {
      'action': 'upload',
      ..._base(c, b, p),
      'it_type': type.code,
      'vc_name': name,
      'vc_mime': mime,
      'qt_bytes': bytes.length,
      ...fields,
    });
    try {
      await _gateway.uploadToSignedUrl(
        bucket: _bucket,
        path: r['vc_path'] as String,
        token: r['token'] as String,
        bytes: bytes,
        contentType: mime,
      );
    } catch (_) {
      await delete(c, b, p, (r['nr_file'] as num).toInt());
      rethrow;
    }
  }

  Future<Uint8List> download(int c, int b, int p, int nrFile) async {
    final r = await _gateway.invokeFunction(_fn, {
      'action': 'download',
      ..._base(c, b, p),
      'nr_file': nrFile,
    });
    return _gateway.fetchBytes(r['signed_url'] as String);
  }

  Future<void> update(
    int c,
    int b,
    int p,
    int nrFile,
    Map<String, dynamic> fields,
  ) => _gateway.rpc('patient_file_save', {
    'vc_action': 'U',
    ..._base(c, b, p),
    'nr_file': nrFile,
    ...fields,
  });

  Future<void> delete(int c, int b, int p, int nrFile) =>
      _gateway.invokeFunction(_fn, {
        'action': 'delete',
        ..._base(c, b, p),
        'nr_file': nrFile,
      });
}

final patientFileRepositoryProvider = Provider<PatientFileRepository>(
  (ref) => PatientFileRepository(ref.watch(supabaseGatewayProvider)),
);
