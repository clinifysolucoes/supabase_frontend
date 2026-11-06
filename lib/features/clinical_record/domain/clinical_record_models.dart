/// Prontuario: modelos de anamnese, anamneses, evolucoes e odontograma
/// (ad.anamnesis_model_list / ad.patient_record_get).
library;

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();
List<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).cast<Map<String, dynamic>>();

/// Tipo de resposta da pergunta de anamnese.
enum QuestionType {
  yesNo(1),
  text(2),
  yesNoDetail(3);

  const QuestionType(this.code);
  final int code;

  static QuestionType of(int? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => yesNo);

  bool get hasYesNo => this != text;
  bool get hasText => this != yesNo;
}

class AnamnesisQuestion {
  const AnamnesisQuestion({
    this.nrQuestion = 0,
    required this.vcQuestion,
    this.type = QuestionType.yesNo,
    this.idAlert = false,
  });

  factory AnamnesisQuestion.fromJson(Map<String, dynamic> j) =>
      AnamnesisQuestion(
        nrQuestion: _int(j['nr_question']),
        vcQuestion: j['vc_question'] as String? ?? '',
        type: QuestionType.of(_int(j['it_type'], 1)),
        idAlert: j['id_alert'] as bool? ?? false,
      );

  final int nrQuestion;
  final String vcQuestion;
  final QuestionType type;
  final bool idAlert;

  Map<String, dynamic> toJson() => {
    'vc_question': vcQuestion,
    'it_type': type.code,
    'id_alert': idAlert && type.hasYesNo,
  };

  AnamnesisQuestion copyWith({
    String? vcQuestion,
    QuestionType? type,
    bool? idAlert,
  }) => AnamnesisQuestion(
    nrQuestion: nrQuestion,
    vcQuestion: vcQuestion ?? this.vcQuestion,
    type: type ?? this.type,
    idAlert: idAlert ?? this.idAlert,
  );
}

class AnamnesisModel {
  const AnamnesisModel({
    required this.nrModel,
    required this.vcName,
    this.nrSpecialty,
    this.vcSpecialty,
    this.itStatus = 1,
    this.questions = const [],
  });

  factory AnamnesisModel.fromJson(Map<String, dynamic> j) => AnamnesisModel(
    nrModel: _int(j['nr_model']),
    vcName: j['vc_name'] as String? ?? '',
    nrSpecialty: (j['nr_specialty'] as num?)?.toInt(),
    vcSpecialty: j['vc_specialty'] as String?,
    itStatus: _int(j['it_status'], 1),
    questions: _list(j['questions']).map(AnamnesisQuestion.fromJson).toList(),
  );

  final int nrModel;
  final String vcName;
  final int? nrSpecialty;
  final String? vcSpecialty;
  final int itStatus;
  final List<AnamnesisQuestion> questions;

  bool get isActive => itStatus == 1;
}

class AnamnesisModelList {
  const AnamnesisModelList({this.models = const [], this.canUpdate = false});

  factory AnamnesisModelList.fromJson(Map<String, dynamic> j) =>
      AnamnesisModelList(
        models: _list(j['models']).map(AnamnesisModel.fromJson).toList(),
        canUpdate: (j['permission'] as Map?)?['id_update'] as bool? ?? false,
      );

  final List<AnamnesisModel> models;
  final bool canUpdate;
}

class AnamnesisAnswer {
  const AnamnesisAnswer({
    required this.nrQuestion,
    required this.vcQuestion,
    required this.type,
    this.idYes,
    this.vcText,
    this.idAlert = false,
  });

  factory AnamnesisAnswer.fromJson(Map<String, dynamic> j) => AnamnesisAnswer(
    nrQuestion: _int(j['nr_question']),
    vcQuestion: j['vc_question'] as String? ?? '',
    type: QuestionType.of(_int(j['it_type'], 1)),
    idYes: j['id_yes'] as bool?,
    vcText: j['vc_text'] as String?,
    idAlert: j['id_alert'] as bool? ?? false,
  );

  final int nrQuestion;
  final String vcQuestion;
  final QuestionType type;
  final bool? idYes;
  final String? vcText;
  final bool idAlert;

  bool get isAnswered =>
      idYes != null || (vcText != null && vcText!.trim().isNotEmpty);
}

class PatientAnamnesis {
  const PatientAnamnesis({
    required this.nrAnamnesis,
    required this.vcModel,
    this.dtFilled,
    this.vcNotes,
    this.vcUser,
    this.answers = const [],
  });

  factory PatientAnamnesis.fromJson(Map<String, dynamic> j) => PatientAnamnesis(
    nrAnamnesis: _int(j['nr_anamnesis']),
    vcModel: j['vc_model'] as String? ?? '',
    dtFilled: _date(j['dt_filled']),
    vcNotes: j['vc_notes'] as String?,
    vcUser: j['vc_user'] as String?,
    answers: _list(j['answers']).map(AnamnesisAnswer.fromJson).toList(),
  );

  final int nrAnamnesis;
  final String vcModel;
  final DateTime? dtFilled;
  final String? vcNotes;
  final String? vcUser;
  final List<AnamnesisAnswer> answers;

  int get alertCount => answers.where((a) => a.idAlert).length;
}

class ClinicalEvolution {
  const ClinicalEvolution({
    required this.nrEvolution,
    this.dhEvolution,
    this.vcProfessional,
    required this.vcText,
    this.vcTooth,
    this.vcProcedure,
    this.nrBudget,
    this.nrItem,
    this.vcUser,
  });

  factory ClinicalEvolution.fromJson(Map<String, dynamic> j) =>
      ClinicalEvolution(
        nrEvolution: _int(j['nr_evolution']),
        dhEvolution: _date(j['dh_evolution']),
        vcProfessional: j['vc_professional'] as String?,
        vcText: j['vc_text'] as String? ?? '',
        vcTooth: j['vc_tooth'] as String?,
        vcProcedure: j['vc_procedure'] as String?,
        nrBudget: (j['nr_budget'] as num?)?.toInt(),
        nrItem: (j['nr_item'] as num?)?.toInt(),
        vcUser: j['vc_user'] as String?,
      );

  final int nrEvolution;
  final DateTime? dhEvolution;
  final String? vcProfessional;
  final String vcText;
  final String? vcTooth;
  final String? vcProcedure;
  final int? nrBudget;
  final int? nrItem;
  final String? vcUser;
}

/// Item de orcamento aprovado (a fazer ou realizado).
class TreatmentItem {
  const TreatmentItem({
    required this.nrBudget,
    required this.nrItem,
    required this.vcDescription,
    this.vcTooth,
    this.dtDone,
  });

  factory TreatmentItem.fromJson(Map<String, dynamic> j) => TreatmentItem(
    nrBudget: _int(j['nr_budget']),
    nrItem: _int(j['nr_item']),
    vcDescription: j['vc_description'] as String? ?? '',
    vcTooth: j['vc_tooth'] as String?,
    dtDone: _date(j['dt_done']),
  );

  final int nrBudget;
  final int nrItem;
  final String vcDescription;
  final String? vcTooth;
  final DateTime? dtDone;

  String get label =>
      '$vcDescription${vcTooth == null || vcTooth!.isEmpty ? '' : ' · $vcTooth'} (orç. $nrBudget)';
}

/// Condicao marcada no dente.
enum ToothCondition {
  caries(1, 'Cárie'),
  restoration(2, 'Restauração'),
  missing(3, 'Ausente/extraído'),
  implant(4, 'Implante'),
  crown(5, 'Coroa/prótese'),
  rootCanal(6, 'Canal'),
  extraction(7, 'Extração indicada'),
  fracture(8, 'Fratura'),
  sealant(9, 'Selante'),
  other(10, 'Outro');

  const ToothCondition(this.code, this.label);
  final int code;
  final String label;

  static ToothCondition of(int? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => other);
}

enum ToothSituation {
  existing(1, 'Existente'),
  toTreat(2, 'A tratar'),
  done(3, 'Realizado');

  const ToothSituation(this.code, this.label);
  final int code;
  final String label;

  static ToothSituation of(int? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => existing);
}

class ToothMark {
  const ToothMark({
    required this.nrMark,
    required this.vcTooth,
    required this.condition,
    this.vcFaces,
    this.situation = ToothSituation.existing,
    this.vcNotes,
    this.dtMark,
  });

  factory ToothMark.fromJson(Map<String, dynamic> j) => ToothMark(
    nrMark: _int(j['nr_mark']),
    vcTooth: j['vc_tooth'] as String? ?? '',
    condition: ToothCondition.of(_int(j['it_condition'], 10)),
    vcFaces: j['vc_faces'] as String?,
    situation: ToothSituation.of(_int(j['it_situation'], 1)),
    vcNotes: j['vc_notes'] as String?,
    dtMark: _date(j['dt_mark']),
  );

  final int nrMark;
  final String vcTooth;
  final ToothCondition condition;
  final String? vcFaces;
  final ToothSituation situation;
  final String? vcNotes;
  final DateTime? dtMark;
}

/// Dentes na numeracao FDI, na ordem em que aparecem no odontograma
/// (visto de frente: direita do paciente a esquerda da tela).
abstract final class Teeth {
  static const permanentUpper = [
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
  static const permanentLower = [
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
  static const deciduousUpper = [
    '55',
    '54',
    '53',
    '52',
    '51',
    '61',
    '62',
    '63',
    '64',
    '65',
  ];
  static const deciduousLower = [
    '85',
    '84',
    '83',
    '82',
    '81',
    '71',
    '72',
    '73',
    '74',
    '75',
  ];

  /// Faces validas: M D O V L I P.
  static const faces = ['M', 'D', 'O', 'V', 'L', 'I', 'P'];

  static bool isValid(String t) =>
      RegExp(r'^([1-4][1-8]|[5-8][1-5])$').hasMatch(t);
}

class PatientClinicalRecord {
  const PatientClinicalRecord({
    this.alerts = const [],
    this.anamneses = const [],
    this.evolutions = const [],
    this.marks = const [],
    this.pendingItems = const [],
    this.doneItems = const [],
    this.canCreate = false,
    this.canUpdate = false,
  });

  factory PatientClinicalRecord.fromJson(Map<String, dynamic> j) {
    final perm = (j['permission'] as Map?) ?? const {};
    return PatientClinicalRecord(
      alerts: [
        for (final a in _list(j['alerts']))
          [
            a['vc_question'] as String? ?? '',
            a['vc_text'] as String?,
          ].whereType<String>().where((s) => s.isNotEmpty).join(': '),
      ],
      anamneses: _list(j['anamneses']).map(PatientAnamnesis.fromJson).toList(),
      evolutions: _list(
        j['evolutions'],
      ).map(ClinicalEvolution.fromJson).toList(),
      marks: _list(j['marks']).map(ToothMark.fromJson).toList(),
      pendingItems: _list(
        j['pending_items'],
      ).map(TreatmentItem.fromJson).toList(),
      doneItems: _list(j['done_items']).map(TreatmentItem.fromJson).toList(),
      canCreate: perm['id_create'] as bool? ?? false,
      canUpdate: perm['id_update'] as bool? ?? false,
    );
  }

  final List<String> alerts;
  final List<PatientAnamnesis> anamneses;
  final List<ClinicalEvolution> evolutions;
  final List<ToothMark> marks;
  final List<TreatmentItem> pendingItems;
  final List<TreatmentItem> doneItems;
  final bool canCreate;
  final bool canUpdate;

  List<ToothMark> marksOf(String tooth) =>
      marks.where((m) => m.vcTooth == tooth).toList();
}
