import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/prosthetic_models.dart';

final prostheticFilterProvider = StateProvider.autoDispose<ProstheticFilter>(
  (_) => ProstheticFilter.open,
);
final prostheticSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Trabalhos da filial com o filtro e a busca da tela.
final prostheticListProvider = FutureProvider.autoDispose<ProstheticListData>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const ProstheticListData();
  final search = ref.watch(prostheticSearchProvider);
  return ProstheticListData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('prosthetic_list', {
      'nr_company': c,
      'nr_branch': b,
      'vc_filter': ref.watch(prostheticFilterProvider).code,
      if (search.isNotEmpty) 'vc_search': search,
    }),
  );
});

/// Escritas da tela; cada uma recarrega a lista.
class ProstheticActions {
  ProstheticActions(this._ref);

  final Ref _ref;

  Map<String, dynamic> get _branch {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return {'nr_company': c, 'nr_branch': b};
  }

  /// Cadastra ([nrWork] null) ou altera.
  Future<int> save(int? nrWork, Map<String, dynamic> fields) async {
    final r = await _ref.read(supabaseGatewayProvider).rpc('prosthetic_save', {
      ..._branch,
      'vc_action': nrWork == null ? 'I' : 'U',
      'nr_work': ?nrWork,
      ...fields,
    });
    _ref.invalidate(prostheticListProvider);
    return (r['nr_work'] as num).toInt();
  }

  /// Muda a etapa. Devolve se a conta a pagar foi gerada e se ficou de fora
  /// por falta de permissao no Financeiro.
  Future<({bool payable, bool skipped})> stage(
    int nrWork,
    Map<String, dynamic> fields,
  ) async {
    final r = await _ref.read(supabaseGatewayProvider).rpc('prosthetic_stage', {
      ..._branch,
      'nr_work': nrWork,
      ...fields,
    });
    _ref.invalidate(prostheticListProvider);
    return (
      payable: r['nr_entry'] != null,
      skipped: r['id_fin_skipped'] as bool? ?? false,
    );
  }
}

final prostheticActionsProvider = Provider<ProstheticActions>(
  ProstheticActions.new,
);
