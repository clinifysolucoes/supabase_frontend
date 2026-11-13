import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/chart_models.dart';

/// Fichas por especialidade e periograma.
class ChartRepository {
  ChartRepository(this._ref);

  final Ref _ref;

  SupabaseGateway get _gw => _ref.read(supabaseGatewayProvider);

  Map<String, dynamic> get _br {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return {'nr_company': c, 'nr_branch': b};
  }

  Future<ChartModelList> models({bool inactive = false}) async =>
      ChartModelList.fromJson(
        await _gw.rpc('chart_model_list', {..._br, 'id_inactive': inactive}),
      );

  Future<void> saveModel(int? nrModel, Map<String, dynamic> fields) async {
    await _gw.rpc('chart_model_save', {
      ..._br,
      'vc_action': nrModel == null ? 'I' : 'U',
      'nr_model': ?nrModel,
      ...fields,
    });
    _ref.invalidate(chartModelsProvider);
  }

  Future<PatientChartList> charts(int nrPatient) async =>
      PatientChartList.fromJson(
        await _gw.rpc('patient_chart_list', {..._br, 'nr_patient': nrPatient}),
      );

  Future<void> saveChart(
    int nrPatient,
    String action,
    Map<String, dynamic> fields,
  ) async {
    await _gw.rpc('patient_chart_save', {
      ..._br,
      'vc_action': action,
      'nr_patient': nrPatient,
      ...fields,
    });
    _ref.invalidate(patientChartsProvider(nrPatient));
  }

  Future<PerioExamList> perio(int nrPatient) async => PerioExamList.fromJson(
    await _gw.rpc('perio_exam_list', {..._br, 'nr_patient': nrPatient}),
  );

  Future<void> savePerio(
    int nrPatient,
    String action,
    Map<String, dynamic> fields,
  ) async {
    await _gw.rpc('perio_exam_save', {
      ..._br,
      'vc_action': action,
      'nr_patient': nrPatient,
      ...fields,
    });
    _ref.invalidate(perioExamsProvider(nrPatient));
  }
}

final chartRepositoryProvider = Provider<ChartRepository>(ChartRepository.new);

/// Modelos (true = inclui os inativos, para Configuracoes).
final chartModelsProvider = FutureProvider.autoDispose
    .family<ChartModelList, bool>((ref, inactive) {
      ref.watch(currentBranchNumberProvider);
      return ref.read(chartRepositoryProvider).models(inactive: inactive);
    });

final patientChartsProvider = FutureProvider.autoDispose
    .family<PatientChartList, int>((ref, nrPatient) {
      ref.watch(currentBranchNumberProvider);
      return ref.read(chartRepositoryProvider).charts(nrPatient);
    });

final perioExamsProvider = FutureProvider.autoDispose
    .family<PerioExamList, int>((ref, nrPatient) {
      ref.watch(currentBranchNumberProvider);
      return ref.read(chartRepositoryProvider).perio(nrPatient);
    });
