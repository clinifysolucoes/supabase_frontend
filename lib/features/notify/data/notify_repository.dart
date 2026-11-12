import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/notify_models.dart';

/// Alertas por e-mail e SMS: configuracao, historico e confirmacao publica.
class NotifyRepository {
  NotifyRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<NotifySettings> settings(int c, int b) async =>
      NotifySettings.fromJson(
        await _gateway.rpc('notify_settings_get', {
          'nr_company': c,
          'nr_branch': b,
        }),
      );

  Future<void> save(int c, int b, Map<String, dynamic> fields) => _gateway.rpc(
    'notify_settings_save',
    {'nr_company': c, 'nr_branch': b, ...fields},
  );

  Future<NotifyMessagePage> messages(
    int c,
    int b, {
    int? channel,
    int? status,
  }) async => NotifyMessagePage.fromJson(
    await _gateway.rpc('notify_message_list', {
      'nr_company': c,
      'nr_branch': b,
      'it_channel': ?channel,
      'it_status': ?status,
      'qt_limit': 50,
    }),
  );

  /// Pagina publica `/confirmar/<token>` (sem login).
  Future<NotifyConfirmResult> confirm(String token) async =>
      NotifyConfirmResult.fromJson(
        await _gateway.invokeFunction('notify-confirm', {'token': token}),
      );
}

final notifyRepositoryProvider = Provider<NotifyRepository>(
  (ref) => NotifyRepository(ref.watch(supabaseGatewayProvider)),
);

final notifySettingsProvider = FutureProvider.autoDispose<NotifySettings>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const NotifySettings();
  return ref.read(notifyRepositoryProvider).settings(c, b);
});

/// Filtros do historico: canal e situacao (null = todos).
final notifyChannelFilterProvider = StateProvider.autoDispose<int?>(
  (_) => null,
);
final notifyStatusFilterProvider = StateProvider.autoDispose<int?>((_) => null);

final notifyMessagesProvider = FutureProvider.autoDispose<NotifyMessagePage>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const NotifyMessagePage();
  return ref
      .read(notifyRepositoryProvider)
      .messages(
        c,
        b,
        channel: ref.watch(notifyChannelFilterProvider),
        status: ref.watch(notifyStatusFilterProvider),
      );
});
