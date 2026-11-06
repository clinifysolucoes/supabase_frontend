import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/data_export.dart';
import '../domain/settings_models.dart';
import '../domain/trash_models.dart';

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

  /// Planilha (ad.data_export): colunas e linhas.
  Future<ExportTable> export({
    required int nrCompany,
    required int nrBranch,
    required ExportKind kind,
    Map<String, dynamic> params = const {},
  }) async => ExportTable.fromJson(
    await _gateway.rpc('data_export', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'vc_kind': kind.code,
      ...params,
    }),
  );

  /// Lixeira (ad.trash_list).
  Future<TrashData> trash({
    required int nrCompany,
    required int nrBranch,
    String? kind,
    String? search,
  }) async => TrashData.fromJson(
    await _gateway.rpc('trash_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      if (kind != null) 'vc_kind': kind,
      if (search != null && search.isNotEmpty) 'vc_search': search,
    }),
  );

  /// Restaura um item da lixeira (ad.trash_restore).
  Future<void> restore({
    required int nrCompany,
    required int nrBranch,
    required TrashItem item,
  }) => _gateway.rpc('trash_restore', {
    'nr_company': nrCompany,
    'nr_branch': nrBranch,
    'vc_kind': item.vcKind,
    'nr_key': item.nrKey,
    if (item.nrParent != null) 'nr_parent': item.nrParent,
  });

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

/// Formas de pagamento aceitas ao receber na filial atual (todas se falhar).
Future<List<int>> loadAcceptedPaymentMethods(WidgetRef ref) async {
  final c = ref.read(currentCompanyProvider);
  final b = ref.read(currentBranchNumberProvider);
  if (c == null || b == null) return BranchSettings.allPaymentMethods;
  try {
    final s = await ref
        .read(settingsRepositoryProvider)
        .get(nrCompany: c, nrBranch: b);
    return s.itPaymentMethods;
  } catch (_) {
    return BranchSettings.allPaymentMethods;
  }
}

final settingsProvider =
    AsyncNotifierProvider.autoDispose<SettingsController, BranchSettings>(
      SettingsController.new,
    );
