import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/radiology_models.dart';

/// Filtro da tela: uma situacao (null = todas menos canceladas) e a busca.
final radiologyStatusFilterProvider =
    StateProvider.autoDispose<RadiologyStatus?>((_) => null);
final radiologySearchProvider = StateProvider.autoDispose<String>((_) => '');

final radiologyListProvider = FutureProvider.autoDispose<RadiologyListData>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const RadiologyListData();
  final status = ref.watch(radiologyStatusFilterProvider);
  final search = ref.watch(radiologySearchProvider);
  return RadiologyListData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('radiology_list', {
      'nr_company': c,
      'nr_branch': b,
      'it_status': ?status?.code,
      if (search.isNotEmpty) 'vc_search': search,
    }),
  );
});

/// Cria ([nrRequest] null) ou altera um pedido de exame e recarrega a lista.
final radiologySaveProvider =
    Provider<Future<int> Function(int? nrRequest, Map<String, dynamic> fields)>(
      (ref) => (nrRequest, fields) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        final r = await ref
            .read(supabaseGatewayProvider)
            .rpc('radiology_save', {
              'nr_company': c,
              'nr_branch': b,
              'vc_action': nrRequest == null ? 'I' : 'U',
              'nr_request': ?nrRequest,
              ...fields,
            });
        ref.invalidate(radiologyListProvider);
        return (r['nr_request'] as num).toInt();
      },
    );

/// Cadastra ([nrCenter] null) ou altera um centro radiologico.
final radiologyCenterSaveProvider =
    Provider<Future<int> Function(int? nrCenter, Map<String, dynamic> fields)>(
      (ref) => (nrCenter, fields) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        final r = await ref
            .read(supabaseGatewayProvider)
            .rpc('radiology_center_save', {
              'nr_company': c,
              'nr_branch': b,
              'vc_action': nrCenter == null ? 'I' : 'U',
              'nr_center': ?nrCenter,
              ...fields,
            });
        ref.invalidate(radiologyListProvider);
        return (r['nr_center'] as num).toInt();
      },
    );
