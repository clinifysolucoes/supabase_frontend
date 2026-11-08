import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/whatsapp_models.dart';

/// Configuracao e historico do WhatsApp. A gravacao passa pela Edge Function
/// whatsapp-config, que cifra a chave da Meta antes de guardar.
class WhatsappRepository {
  WhatsappRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<WhatsappSettings> settings(int c, int b) async =>
      WhatsappSettings.fromJson(
        await _gateway.rpc('whatsapp_settings_get', {
          'nr_company': c,
          'nr_branch': b,
        }),
      );

  Future<void> save(int c, int b, Map<String, dynamic> fields) =>
      _gateway.invokeFunction('whatsapp-config', {
        'action': 'save',
        'nr_company': c,
        'nr_branch': b,
        ...fields,
      });

  Future<void> test(int c, int b, String to) => _gateway.invokeFunction(
    'whatsapp-config',
    {'action': 'test', 'nr_company': c, 'nr_branch': b, 'vc_to': to},
  );

  Future<WhatsappMessagePage> messages(
    int c,
    int b, {
    int? kind,
    int? status,
    int offset = 0,
  }) async => WhatsappMessagePage.fromJson(
    await _gateway.rpc('whatsapp_message_list', {
      'nr_company': c,
      'nr_branch': b,
      'it_kind': ?kind,
      'it_status': ?status,
      'nr_offset': offset,
      'qt_limit': 50,
    }),
  );
}

final whatsappRepositoryProvider = Provider<WhatsappRepository>(
  (ref) => WhatsappRepository(ref.watch(supabaseGatewayProvider)),
);
