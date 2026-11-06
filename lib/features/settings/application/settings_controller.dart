import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/settings_models.dart';

/// RPCs da tela Configuracoes.
class SettingsRepository {
  SettingsRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<BranchSettings> get({
    required int nrCompany,
    required int nrBranch,
  }) async => BranchSettings.fromJson(
    await _gateway.rpc('settings_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
    }),
  );

  /// Preferencias da filial (parcial) e, com [hours], o horario de funcionamento.
  Future<BranchSettings> save({
    required int nrCompany,
    required int nrBranch,
    required Map<String, dynamic> fields,
  }) async => BranchSettings.fromJson(
    await _gateway.rpc('settings_save', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...fields,
    }),
  );

  /// Dados da clinica (administrador da empresa).
  Future<void> saveClinic({
    required int nrCompany,
    required int nrBranch,
    required Map<String, dynamic> fields,
  }) => _gateway.rpc('branch_update', {
    'nr_company': nrCompany,
    'nr_branch': nrBranch,
    ...fields,
  });
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(supabaseGatewayProvider)),
);

/// Configuracoes da filial atual.
class SettingsController extends AutoDisposeAsyncNotifier<BranchSettings> {
  ({int company, int branch})? get _b {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    return c == null || b == null ? null : (company: c, branch: b);
  }

  @override
  Future<BranchSettings> build() async {
    final c = ref.watch(currentCompanyProvider);
    final b = ref.watch(currentBranchNumberProvider);
    if (c == null || b == null) return const BranchSettings();
    return ref.read(settingsRepositoryProvider).get(nrCompany: c, nrBranch: b);
  }

  Future<void> save(Map<String, dynamic> fields) async {
    final b = _b;
    if (b == null) return;
    final s = await ref
        .read(settingsRepositoryProvider)
        .save(nrCompany: b.company, nrBranch: b.branch, fields: fields);
    state = AsyncData(s);
  }

  Future<void> saveClinic(Map<String, dynamic> fields) async {
    final b = _b;
    if (b == null) return;
    await ref
        .read(settingsRepositoryProvider)
        .saveClinic(nrCompany: b.company, nrBranch: b.branch, fields: fields);
    ref.invalidateSelf();
    await future;
  }
}

final settingsProvider =
    AsyncNotifierProvider.autoDispose<SettingsController, BranchSettings>(
      SettingsController.new,
    );
