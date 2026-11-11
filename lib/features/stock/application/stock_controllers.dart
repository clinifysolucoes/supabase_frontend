import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/stock_models.dart';

final stockFilterProvider = StateProvider.autoDispose<StockFilter>(
  (_) => StockFilter.controlled,
);
final stockSearchProvider = StateProvider.autoDispose<String>((_) => '');
final stockPeriodProvider = StateProvider.autoDispose<StockPeriod>(
  (_) => StockPeriod.last30,
);

/// Tipo de movimento filtrado (null = todos).
final stockTypeProvider = StateProvider.autoDispose<int?>((_) => null);

Map<String, dynamic>? _branch(Ref ref) {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  return c == null || b == null ? null : {'nr_company': c, 'nr_branch': b};
}

final stockListProvider = FutureProvider.autoDispose<StockListData>((
  ref,
) async {
  final br = _branch(ref);
  if (br == null) return const StockListData();
  final search = ref.watch(stockSearchProvider);
  return StockListData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('stock_list', {
      ...br,
      'vc_filter': ref.watch(stockFilterProvider).code,
      if (search.isNotEmpty) 'vc_search': search,
    }),
  );
});

final stockMovementsProvider = FutureProvider.autoDispose<StockMovementData>((
  ref,
) async {
  final br = _branch(ref);
  if (br == null) return const StockMovementData();
  final r = stockRange(ref.watch(stockPeriodProvider), DateTime.now());
  final type = ref.watch(stockTypeProvider);
  return StockMovementData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('stock_movement_list', {
      ...br,
      'dt_start': Dates.toIso(r.from),
      'dt_end': Dates.toIso(r.to),
      'it_type': ?type,
    }),
  );
});

/// Escritas da tela; cada uma recarrega saldos e movimentos.
class StockActions {
  StockActions(this._ref);

  final Ref _ref;

  Map<String, dynamic> get _br {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return {'nr_company': c, 'nr_branch': b};
  }

  void _refresh() {
    _ref.invalidate(stockListProvider);
    _ref.invalidate(stockMovementsProvider);
  }

  Future<void> saveItem(int nrMaterial, Map<String, dynamic> fields) async {
    await _ref.read(supabaseGatewayProvider).rpc('stock_item_save', {
      ..._br,
      'nr_material': nrMaterial,
      ...fields,
    });
    _refresh();
  }

  /// Devolve o saldo novo, se gerou conta a pagar e se houve diferenca
  /// (ajuste igual ao saldo nao grava nada).
  Future<({double stock, bool payable, bool changed})> move(
    int nrMaterial,
    Map<String, dynamic> fields,
  ) async {
    final r = await _ref.read(supabaseGatewayProvider).rpc(
      'stock_movement_save',
      {..._br, 'nr_material': nrMaterial, ...fields},
    );
    _refresh();
    return (
      stock: (r['qt_stock'] as num?)?.toDouble() ?? 0,
      payable: r['nr_entry'] != null,
      changed: r['id_changed'] as bool? ?? true,
    );
  }
}

final stockActionsProvider = Provider<StockActions>(StockActions.new);
