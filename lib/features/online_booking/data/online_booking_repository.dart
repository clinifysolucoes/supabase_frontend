import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../domain/online_booking_models.dart';

/// Configuracao (RPC, usuario logado) e pagina publica (Edge Function
/// online-booking, sem login).
class OnlineBookingRepository {
  OnlineBookingRepository(this._gateway);

  final SupabaseGateway _gateway;

  static const _fn = 'online-booking';

  Future<OnlineBookingSettings> settings(int c, int b) async =>
      OnlineBookingSettings.fromJson(
        await _gateway.rpc('online_booking_settings_get', {
          'nr_company': c,
          'nr_branch': b,
        }),
      );

  Future<void> saveSettings(int c, int b, Map<String, dynamic> fields) =>
      _gateway.rpc('online_booking_settings_save', {
        'nr_company': c,
        'nr_branch': b,
        ...fields,
      });

  Future<OnlineClinic> info(String slug) async => OnlineClinic.fromJson(
    await _gateway.invokeFunction(_fn, {'action': 'info', 'vc_slug': slug}),
  );

  Future<List<String>> slots(
    String slug,
    int nrProfessional,
    DateTime day,
  ) async {
    final r = await _gateway.invokeFunction(_fn, {
      'action': 'slots',
      'vc_slug': slug,
      'nr_professional': nrProfessional,
      'dt_day': Dates.toIso(day),
    });
    return ((r['slots'] as List?) ?? const []).cast<String>();
  }

  Future<OnlineBookingResult> book(
    String slug,
    Map<String, dynamic> fields,
  ) async => OnlineBookingResult.fromJson(
    await _gateway.invokeFunction(_fn, {
      'action': 'book',
      'vc_slug': slug,
      ...fields,
    }),
  );
}

final onlineBookingRepositoryProvider = Provider<OnlineBookingRepository>(
  (ref) => OnlineBookingRepository(ref.watch(supabaseGatewayProvider)),
);
