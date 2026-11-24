import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/integration_models.dart';

/// Quais integracoes ja tem as chaves (Edge Function integrations-status).
/// Se a consulta falhar, as telas mostram "nao foi possivel verificar".
final integrationStatusProvider = FutureProvider<IntegrationStatusMap>((
  ref,
) async {
  try {
    return IntegrationStatusMap.fromJson(
      await ref
          .read(supabaseGatewayProvider)
          .invokeFunction('integrations-status', const {}),
    );
  } catch (_) {
    return IntegrationStatusMap.failed;
  }
});
