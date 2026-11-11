import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/referral_models.dart';

final referralPeriodProvider = StateProvider.autoDispose<ReferralPeriod>(
  (_) => ReferralPeriod.last12,
);

/// So os convertidos sem recompensa.
final referralPendingProvider = StateProvider.autoDispose<bool>((_) => false);

final referralProvider = FutureProvider.autoDispose<ReferralData>((ref) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const ReferralData();
  final r = referralRange(ref.watch(referralPeriodProvider), DateTime.now());
  return ReferralData.fromJson(
    await ref.read(supabaseGatewayProvider).rpc('referral_list', {
      'nr_company': c,
      'nr_branch': b,
      'dt_start': Dates.toIso(r.from),
      'dt_end': Dates.toIso(r.to),
      'vc_filter': ref.watch(referralPendingProvider) ? 'pending' : 'all',
    }),
  );
});

class ReferralActions {
  ReferralActions(this._ref);

  final Ref _ref;

  Future<void> _call(Map<String, dynamic> body) async {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    await _ref.read(supabaseGatewayProvider).rpc('referral_reward_save', {
      'nr_company': c,
      'nr_branch': b,
      ...body,
    });
    _ref.invalidate(referralProvider);
  }

  Future<void> reward(
    int nrPatient, {
    required String reward,
    DateTime? date,
    double? value,
  }) => _call({
    'vc_action': 'I',
    'nr_patient': nrPatient,
    'vc_reward': reward,
    if (date != null) 'dt_reward': Dates.toIso(date),
    'vl_reward': ?value,
  });

  Future<void> undo(int nrPatient) =>
      _call({'vc_action': 'D', 'nr_patient': nrPatient});
}

final referralActionsProvider = Provider<ReferralActions>(ReferralActions.new);
