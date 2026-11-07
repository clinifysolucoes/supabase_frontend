import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/signature_models.dart';

/// Alvo de uma assinatura: documento do paciente ou orcamento.
typedef SignatureKey = ({SignatureTarget target, int? nrPatient, int key});

class SignatureRepository {
  SignatureRepository(this._gateway, this._ref);

  final SupabaseGateway _gateway;
  final Ref _ref;

  Map<String, dynamic> _base(SignatureKey k) {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return {
      'nr_company': c,
      'nr_branch': b,
      'it_target': k.target.code,
      if (k.target == SignatureTarget.document) ...{
        'nr_patient': k.nrPatient,
        'nr_document': k.key,
      } else
        'nr_budget': k.key,
    };
  }

  Future<SignatureList> list(SignatureKey k) async =>
      SignatureList.fromJson(await _gateway.rpc('signature_list', _base(k)));

  Future<void> save(
    SignatureKey k, {
    required SignerRole role,
    required String name,
    String? cpf,
    required String image,
  }) => _gateway.rpc('signature_save', {
    ..._base(k),
    'it_signer': role.code,
    'vc_signer_name': name,
    'vc_signer_cpf': ?cpf,
    'tx_image': image,
    'id_consent': true,
  });
}

final signatureRepositoryProvider = Provider<SignatureRepository>(
  (ref) => SignatureRepository(ref.watch(supabaseGatewayProvider), ref),
);
