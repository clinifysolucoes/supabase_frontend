/// Linha do DRE (ad.fin_dre).
class DreLine {
  const DreLine({
    required this.vcKey,
    required this.vcLabel,
    this.itLevel = 3,
    this.itSign = 1,
    this.idEstimated = false,
    this.values = const [],
    this.vlTotal = 0,
    this.pcRevenue,
  });

  factory DreLine.fromJson(Map<String, dynamic> j) => DreLine(
    vcKey: '${j['vc_key']}',
    vcLabel: '${j['vc_label']}',
    itLevel: (j['it_level'] as num?)?.toInt() ?? 3,
    itSign: (j['it_sign'] as num?)?.toInt() ?? 1,
    idEstimated: j['id_estimated'] == true,
    values: [
      for (final v in (j['values'] as List? ?? const []))
        (v as num?)?.toDouble() ?? 0,
    ],
    vlTotal: (j['vl_total'] as num?)?.toDouble() ?? 0,
    pcRevenue: (j['pc_revenue'] as num?)?.toDouble(),
  );

  final String vcKey;
  final String vcLabel;

  /// 1 total, 2 grupo, 3 categoria.
  final int itLevel;

  /// 1 soma, -1 subtrai, 0 informativo (fora do resultado).
  final int itSign;
  final bool idEstimated;
  final List<double> values;
  final double vlTotal;
  final double? pcRevenue;

  bool get isTotal => itLevel == 1;
  bool get isCategory => itLevel == 3;
}

/// DRE do periodo: meses (YYYY-MM) e linhas.
class DreReport {
  const DreReport({
    this.months = const [],
    this.lines = const [],
    this.basis = 'competence',
  });

  factory DreReport.fromJson(Map<String, dynamic> j) => DreReport(
    months: [for (final m in (j['months'] as List? ?? const [])) '$m'],
    lines: [
      for (final l in (j['lines'] as List? ?? const []))
        DreLine.fromJson((l as Map).cast<String, dynamic>()),
    ],
    basis: j['vc_basis']?.toString() ?? 'competence',
  );

  final List<String> months;
  final List<DreLine> lines;
  final String basis;

  DreLine? line(String key) {
    for (final l in lines) {
      if (l.vcKey == key) return l;
    }
    return null;
  }
}
