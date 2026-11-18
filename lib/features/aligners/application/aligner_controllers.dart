import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/aligner_models.dart';

/// Filtro da tela: uma situacao (null = todas menos canceladas) e a busca.
final alignerStatusFilterProvider = StateProvider.autoDispose<AlignerStatus?>(
  (_) => null,
);
final alignerSearchProvider = StateProvider.autoDispose<String>((_) => '');

final alignerListProvider = FutureProvider.autoDispose<AlignerListData>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const AlignerListData();
  final status = ref.watch(alignerStatusFilterProvider);
  final search = ref.watch(alignerSearchProvider);
  return AlignerListData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('aligner_list', {
      'nr_company': c,
      'nr_branch': b,
      'it_status': ?status?.code,
      if (search.isNotEmpty) 'vc_search': search,
    }),
  );
});

/// Cria ([nrCase] null) ou altera um caso e recarrega a lista.
final alignerSaveProvider =
    Provider<Future<int> Function(int? nrCase, Map<String, dynamic> fields)>(
      (ref) => (nrCase, fields) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        final r = await ref.read(supabaseGatewayProvider).rpc('aligner_save', {
          'nr_company': c,
          'nr_branch': b,
          'vc_action': nrCase == null ? 'I' : 'U',
          'nr_case': ?nrCase,
          ...fields,
        });
        ref.invalidate(alignerListProvider);
        return (r['nr_case'] as num).toInt();
      },
    );
