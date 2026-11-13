/// Fichas por especialidade (ad.chart_model_list/save, ad.patient_chart_save/
/// list) e periograma (ad.perio_exam_save/list).
library;

import '../../../l10n/strings.dart';

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();

/// Tipo do campo (od.chart_field.it_type).
enum ChartFieldType {
  shortText(1, Strings.cfShortText),
  longText(2, Strings.cfLongText),
  yesNo(3, Strings.cfYesNo),
  choice(4, Strings.cfChoice),
  number(5, Strings.cfNumber),
  date(6, Strings.cfDate),
  section(7, Strings.cfSection);

  const ChartFieldType(this.code, this.label);

  final int code;
  final String label;

  static ChartFieldType of(int code) => values.firstWhere(
    (t) => t.code == code,
    orElse: () => ChartFieldType.shortText,
  );
}

class ChartField {
  const ChartField({
    required this.nrField,
    required this.vcLabel,
    required this.type,
    this.options = const [],
    this.vcUnit,
    this.idRequired = false,
  });

  factory ChartField.fromJson(Map<String, dynamic> j) => ChartField(
    nrField: _int(j['nr_field']),
    vcLabel: j['vc_label'] as String? ?? '',
    type: ChartFieldType.of(_int(j['it_type'], 1)),
    options: ((j['vc_options'] as String?) ?? '')
        .split('|')
        .where((o) => o.isNotEmpty)
        .toList(),
    vcUnit: j['vc_unit'] as String?,
    idRequired: j['id_required'] as bool? ?? false,
  );

  final int nrField;
  final String vcLabel;
  final ChartFieldType type;
  final List<String> options;
  final String? vcUnit;
  final bool idRequired;

  Map<String, dynamic> toJson() => {
    'vc_label': vcLabel,
    'it_type': type.code,
    if (type == ChartFieldType.choice) 'vc_options': options,
    if (type == ChartFieldType.number && (vcUnit ?? '').isNotEmpty)
      'vc_unit': vcUnit,
    'id_required': idRequired,
  };
}

class ChartModel {
  const ChartModel({
    required this.nrModel,
    required this.vcName,
    this.nrSpecialty,
    this.vcSpecialty,
    this.idPerTooth = false,
    this.itStatus = 1,
    this.fields = const [],
  });

  factory ChartModel.fromJson(Map<String, dynamic> j) => ChartModel(
    nrModel: _int(j['nr_model']),
    vcName: j['vc_name'] as String? ?? '',
    nrSpecialty: (j['nr_specialty'] as num?)?.toInt(),
    vcSpecialty: j['vc_specialty'] as String?,
    idPerTooth: j['id_per_tooth'] as bool? ?? false,
    itStatus: _int(j['it_status'], 1),
    fields: _list(j['fields']).map(ChartField.fromJson).toList(),
  );

  final int nrModel;
  final String vcName;
  final int? nrSpecialty;
  final String? vcSpecialty;
  final bool idPerTooth;
  final int itStatus;
  final List<ChartField> fields;

  bool get isActive => itStatus == 1;
}

class ChartModelList {
  const ChartModelList({this.models = const [], this.canUpdate = false});

  factory ChartModelList.fromJson(Map<String, dynamic> j) => ChartModelList(
    models: _list(j['models']).map(ChartModel.fromJson).toList(),
    canUpdate:
        ((j['permission'] as Map?) ?? const {})['id_update'] as bool? ?? false,
  );

  final List<ChartModel> models;
  final bool canUpdate;
}

class ChartValue {
  const ChartValue({
    required this.nrField,
    required this.vcLabel,
    required this.type,
    this.vcUnit,
    this.vcValue,
  });

  factory ChartValue.fromJson(Map<String, dynamic> j) => ChartValue(
    nrField: _int(j['nr_field']),
    vcLabel: j['vc_label'] as String? ?? '',
    type: ChartFieldType.of(_int(j['it_type'], 1)),
    vcUnit: j['vc_unit'] as String?,
    vcValue: j['vc_value'] as String?,
  );

  final int nrField;
  final String vcLabel;
  final ChartFieldType type;
  final String? vcUnit;
  final String? vcValue;

  /// Valor para exibir (S/N, data dd/mm/aaaa, numero com virgula e unidade).
  String get display {
    final v = vcValue;
    if (v == null || v.isEmpty) return '';
    return switch (type) {
      ChartFieldType.yesNo => v == 'S' ? Strings.yes : Strings.no,
      ChartFieldType.date => () {
        final d = DateTime.tryParse(v);
        return d == null
            ? v
            : '${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}/${d.year}';
      }(),
      ChartFieldType.number =>
        '${v.replaceAll('.', ',')}${(vcUnit ?? '').isEmpty ? '' : ' $vcUnit'}',
      _ => v,
    };
  }
}

class PatientChart {
  const PatientChart({
    required this.nrChart,
    required this.vcModel,
    this.nrModel,
    this.vcTooth,
    this.dtChart,
    this.nrProfessional,
    this.vcProfessional,
    this.vcNotes,
    this.vcUser,
    this.values = const [],
  });

  factory PatientChart.fromJson(Map<String, dynamic> j) => PatientChart(
    nrChart: _int(j['nr_chart']),
    nrModel: (j['nr_model'] as num?)?.toInt(),
    vcModel: j['vc_model'] as String? ?? '',
    vcTooth: j['vc_tooth'] as String?,
    dtChart: _date(j['dt_chart']),
    nrProfessional: (j['nr_professional'] as num?)?.toInt(),
    vcProfessional: j['vc_professional'] as String?,
    vcNotes: j['vc_notes'] as String?,
    vcUser: j['vc_user'] as String?,
    values: _list(j['values']).map(ChartValue.fromJson).toList(),
  );

  final int nrChart;
  final int? nrModel;
  final String vcModel;
  final String? vcTooth;
  final DateTime? dtChart;
  final int? nrProfessional;
  final String? vcProfessional;
  final String? vcNotes;
  final String? vcUser;
  final List<ChartValue> values;

  /// Valores preenchidos (sem titulos e vazios) para o resumo do cartao.
  List<ChartValue> get filled => [
    for (final v in values)
      if (v.type != ChartFieldType.section && (v.vcValue ?? '').isNotEmpty) v,
  ];
}

class PatientChartList {
  const PatientChartList({
    this.charts = const [],
    this.canCreate = false,
    this.canUpdate = false,
  });

  factory PatientChartList.fromJson(Map<String, dynamic> j) {
    final p = (j['permission'] as Map?) ?? const {};
    return PatientChartList(
      charts: _list(j['charts']).map(PatientChart.fromJson).toList(),
      canCreate: p['id_create'] as bool? ?? false,
      canUpdate: p['id_update'] as bool? ?? false,
    );
  }

  final List<PatientChart> charts;
  final bool canCreate;
  final bool canUpdate;
}

/// Dentes permanentes na ordem do periograma (superior 18->28, inferior
/// 48->38), como o paciente e visto de frente.
const perioUpper = [
  '18',
  '17',
  '16',
  '15',
  '14',
  '13',
  '12',
  '11',
  '21',
  '22',
  '23',
  '24',
  '25',
  '26',
  '27',
  '28',
];
const perioLower = [
  '48',
  '47',
  '46',
  '45',
  '44',
  '43',
  '42',
  '41',
  '31',
  '32',
  '33',
  '34',
  '35',
  '36',
  '37',
  '38',
];

/// Um dente do periograma: 6 pontos na ordem DV, V, MV, DL, L, ML.
class PerioTooth {
  PerioTooth({
    required this.vcTooth,
    this.idMissing = false,
    this.itMobility,
    this.itFurcation,
    List<int?>? probing,
    List<int?>? recession,
    List<bool?>? bleeding,
    List<bool?>? plaque,
  }) : probing = probing ?? List.filled(6, null),
       recession = recession ?? List.filled(6, null),
       bleeding = bleeding ?? List.filled(6, null),
       plaque = plaque ?? List.filled(6, null);

  factory PerioTooth.fromJson(Map<String, dynamic> j) {
    List<T?> six<T>(Object? v) {
      final l = (v as List?) ?? const [];
      return List<T?>.generate(6, (i) => i < l.length ? l[i] as T? : null);
    }

    return PerioTooth(
      vcTooth: j['vc_tooth'] as String? ?? '',
      idMissing: j['id_missing'] as bool? ?? false,
      itMobility: (j['it_mobility'] as num?)?.toInt(),
      itFurcation: (j['it_furcation'] as num?)?.toInt(),
      probing: six<num>(j['qt_probing']).map((e) => e?.toInt()).toList(),
      recession: six<num>(j['qt_recession']).map((e) => e?.toInt()).toList(),
      bleeding: six<bool>(j['id_bleeding']),
      plaque: six<bool>(j['id_plaque']),
    );
  }

  final String vcTooth;
  bool idMissing;
  int? itMobility;
  int? itFurcation;
  final List<int?> probing;
  final List<int?> recession;
  final List<bool?> bleeding;
  final List<bool?> plaque;

  bool get hasData =>
      idMissing ||
      itMobility != null ||
      itFurcation != null ||
      probing.any((e) => e != null) ||
      recession.any((e) => e != null) ||
      bleeding.any((e) => e == true) ||
      plaque.any((e) => e == true);

  /// Maior profundidade de sondagem medida (para a cor do dente).
  int? get maxProbing => probing.whereType<int>().fold<int?>(
    null,
    (m, v) => m == null || v > m ? v : m,
  );

  Map<String, dynamic> toJson() => {
    'vc_tooth': vcTooth,
    'id_missing': idMissing,
    'it_mobility': itMobility,
    'it_furcation': itFurcation,
    if (probing.any((e) => e != null)) 'qt_probing': probing,
    if (recession.any((e) => e != null)) 'qt_recession': recession,
    if (bleeding.any((e) => e != null))
      'id_bleeding': [for (final b in bleeding) b ?? false],
    if (plaque.any((e) => e != null))
      'id_plaque': [for (final b in plaque) b ?? false],
  };
}

class PerioSummary {
  const PerioSummary({
    this.qtTeeth = 0,
    this.qtSites = 0,
    this.pcBleeding,
    this.pcPlaque,
    this.vlProbingMean,
    this.qtSites45 = 0,
    this.qtSites6 = 0,
    this.vlAttachmentMean,
  });

  factory PerioSummary.fromJson(Map<String, dynamic> j) => PerioSummary(
    qtTeeth: _int(j['qt_teeth']),
    qtSites: _int(j['qt_sites']),
    pcBleeding: (j['pc_bleeding'] as num?)?.toDouble(),
    pcPlaque: (j['pc_plaque'] as num?)?.toDouble(),
    vlProbingMean: (j['vl_probing_mean'] as num?)?.toDouble(),
    qtSites45: _int(j['qt_sites_4_5']),
    qtSites6: _int(j['qt_sites_6']),
    vlAttachmentMean: (j['vl_attachment_mean'] as num?)?.toDouble(),
  );

  final int qtTeeth;
  final int qtSites;
  final double? pcBleeding;
  final double? pcPlaque;
  final double? vlProbingMean;
  final int qtSites45;
  final int qtSites6;
  final double? vlAttachmentMean;
}

class PerioExam {
  const PerioExam({
    required this.nrExam,
    this.dtExam,
    this.nrProfessional,
    this.vcProfessional,
    this.vcNotes,
    this.vcUser,
    this.summary = const PerioSummary(),
    this.teeth = const [],
  });

  factory PerioExam.fromJson(Map<String, dynamic> j) => PerioExam(
    nrExam: _int(j['nr_exam']),
    dtExam: _date(j['dt_exam']),
    nrProfessional: (j['nr_professional'] as num?)?.toInt(),
    vcProfessional: j['vc_professional'] as String?,
    vcNotes: j['vc_notes'] as String?,
    vcUser: j['vc_user'] as String?,
    summary: PerioSummary.fromJson(
      ((j['summary'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    teeth: _list(j['teeth']).map(PerioTooth.fromJson).toList(),
  );

  final int nrExam;
  final DateTime? dtExam;
  final int? nrProfessional;
  final String? vcProfessional;
  final String? vcNotes;
  final String? vcUser;
  final PerioSummary summary;
  final List<PerioTooth> teeth;

  PerioTooth? tooth(String t) => teeth.where((x) => x.vcTooth == t).firstOrNull;
}

class PerioExamList {
  const PerioExamList({
    this.exams = const [],
    this.canCreate = false,
    this.canUpdate = false,
  });

  factory PerioExamList.fromJson(Map<String, dynamic> j) {
    final p = (j['permission'] as Map?) ?? const {};
    return PerioExamList(
      exams: _list(j['exams']).map(PerioExam.fromJson).toList(),
      canCreate: p['id_create'] as bool? ?? false,
      canUpdate: p['id_update'] as bool? ?? false,
    );
  }

  final List<PerioExam> exams;
  final bool canCreate;
  final bool canUpdate;
}
