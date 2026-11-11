import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/dashboard_models.dart';

/// Periodo escolhido no painel (padrao: mes corrente).
final dashboardPeriodProvider = StateProvider.autoDispose<DashboardPeriod>(
  (_) => DashboardPeriod.thisMonth,
);

/// Indicadores da filial atual (ad.dashboard_get).
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const DashboardData();
  final r = dashboardRange(ref.watch(dashboardPeriodProvider), DateTime.now());
  final json = await ref.read(supabaseGatewayProvider).rpc('dashboard_get', {
    'nr_company': c,
    'nr_branch': b,
    'dt_start': Dates.toIso(r.from),
    'dt_end': Dates.toIso(r.to),
  });
  return DashboardData.fromJson(json);
});
