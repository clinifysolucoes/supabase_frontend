import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../profiles/application/profiles_controller.dart';
import '../domain/report_models.dart';

/// RPC dos relatorios (ad.report_get).
class ReportRepository {
  ReportRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<ReportResult> get({
    required int nrCompany,
    required int nrBranch,
    required ReportQuery query,
  }) async => ReportResult.fromJson(
    query.kind,
    await _gateway.rpc('report_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'vc_report': query.kind.code,
      'dt_start': isoDate(query.from),
      'dt_end': isoDate(query.to),
      if (query.kind.byProfessional && query.nrProfessional != null)
        'nr_professional': query.nrProfessional,
    }),
  );

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(supabaseGatewayProvider)),
);

/// Filtros da tela: relatorio, periodo (datas) e profissional.
class ReportQuery {
  const ReportQuery({
    required this.kind,
    required this.from,
    required this.to,
    this.nrProfessional,
  });

  /// Mes corrente.
  factory ReportQuery.initial([DateTime? now]) {
    final n = now ?? DateTime.now();
    return ReportQuery(
      kind: ReportKind.noShow,
      from: DateTime(n.year, n.month),
      to: DateTime(n.year, n.month + 1, 0),
    );
  }

  final ReportKind kind;
  final DateTime from;
  final DateTime to;
  final int? nrProfessional;

  ReportQuery copyWith({
    ReportKind? kind,
    DateTime? from,
    DateTime? to,
    int? Function()? nrProfessional,
  }) => ReportQuery(
    kind: kind ?? this.kind,
    from: from ?? this.from,
    to: to ?? this.to,
    nrProfessional: nrProfessional == null
        ? this.nrProfessional
        : nrProfessional(),
  );
}

final reportQueryProvider = StateProvider.autoDispose<ReportQuery>(
  (_) => ReportQuery.initial(),
);

final reportProvider = FutureProvider.autoDispose<ReportResult>((ref) async {
  final q = ref.watch(reportQueryProvider);
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return ReportResult(kind: q.kind);
  return ref
      .read(reportRepositoryProvider)
      .get(nrCompany: c, nrBranch: b, query: q);
});
