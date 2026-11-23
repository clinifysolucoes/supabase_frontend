import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/credit_models.dart';

/// Consultas de credito do paciente e se a filial/usuario pode consultar.
final creditCheckListProvider = FutureProvider.autoDispose
    .family<CreditCheckData, int>((ref, nrPatient) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const CreditCheckData();
      return CreditCheckData.fromJson(
        await ref.read(supabaseGatewayProvider).rpc('credit_check_list', {
          'nr_company': c,
          'nr_branch': b,
          'nr_patient': nrPatient,
        }),
      );
    });

/// Faz a consulta pela Edge Function credit-check (a chave do biro fica la).
/// Devolve a resposta: it_status 2 concluida ou 9 erro (Message).
final creditCheckRunProvider =
    Provider<Future<Map<String, dynamic>> Function(int nrPatient)>(
      (ref) => (nrPatient) async {
        final c = ref.read(currentCompanyProvider);
        final b = ref.read(currentBranchNumberProvider);
        if (c == null || b == null) throw StateError('branch');
        try {
          return await ref
              .read(supabaseGatewayProvider)
              .invokeFunction('credit-check', {
                'nr_company': c,
                'nr_branch': b,
                'nr_patient': nrPatient,
                'id_consent': true,
              });
        } finally {
          ref.invalidate(creditCheckListProvider(nrPatient));
        }
      },
    );
