import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';

/// Genero (od.patient.it_gender).
abstract final class Gender {
  static const male = 1;
  static const female = 2;
  static const other = 3;
  static const all = [male, female, other];

  static String label(int? value) => switch (value) {
    male => Strings.genderMale,
    female => Strings.genderFemale,
    other => Strings.genderOther,
    _ => '-',
  };
}

/// Estado civil (od.patient.it_marital_status).
abstract final class MaritalStatus {
  static const all = [1, 2, 3, 4, 5];

  static String label(int? value) => switch (value) {
    1 => Strings.maritalSingle,
    2 => Strings.maritalMarried,
    3 => Strings.maritalDivorced,
    4 => Strings.maritalWidowed,
    5 => Strings.maritalUnion,
    _ => '-',
  };
}

/// Escolaridade (od.patient.it_education).
abstract final class Education {
  static const all = [1, 2, 3, 4];

  static String label(int? value) => switch (value) {
    1 => Strings.educationElementary,
    2 => Strings.educationHigh,
    3 => Strings.educationCollege,
    4 => Strings.educationPostgraduate,
    _ => '-',
  };
}

/// Como conheceu a clinica (od.patient.it_source).
abstract final class PatientSource {
  static const referral = 4;
  static const all = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 99];

  static String label(int? value) => switch (value) {
    1 => Strings.sourceGoogle,
    2 => Strings.sourceInstagram,
    3 => Strings.sourceFacebook,
    4 => Strings.sourceReferral,
    5 => Strings.sourceSchool,
    6 => Strings.sourceBillboard,
    7 => Strings.sourceFlyer,
    8 => Strings.sourceSign,
    9 => Strings.sourcePlan,
    10 => Strings.sourceRadio,
    11 => Strings.sourceTv,
    12 => Strings.sourceMagazine,
    99 => Strings.sourceOther,
    _ => '-',
  };
}

/// Unidades da federacao, para o campo UF.
const brazilStates = [
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', //
  'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', //
  'SE', 'SP', 'TO',
];

/// Paciente (od.patient), como vem de patient_list / patient_get.
///
/// Os campos principais sao tipados; o resto da ficha fica acessivel por
/// [text] com o nome da coluna (o formulario usa as mesmas chaves que o
/// backend, entao nao ha o que traduzir aqui).
class Patient {
  Patient.fromJson(Map<String, dynamic> json)
    : _json = {...json},
      nrPatient = _int(json['nr_patient']),
      vcName = _str(json['vc_name']) ?? '',
      dtBirth = Dates.fromIso(_str(json['dt_birth'])),
      dtReturnAlert = Dates.fromIso(_str(json['dt_return_alert'])),
      dhCreated = DateTime.tryParse(_str(json['dh_created']) ?? ''),
      itStatus = _int(json['it_status'] ?? 1),
      idNoEmail = json['id_no_email'] == true;

  final Map<String, dynamic> _json;
  final int nrPatient;
  final String vcName;
  final DateTime? dtBirth;
  final DateTime? dtReturnAlert;
  final DateTime? dhCreated;
  final int itStatus;
  final bool idNoEmail;

  /// Valor textual de uma coluna da ficha (`vc_*`), null quando vazio.
  String? text(String column) {
    final v = _json[column];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Valor inteiro de uma coluna `it_*`, null quando vazio.
  int? code(String column) {
    final v = _json[column];
    if (v == null) return null;
    return v is num ? v.toInt() : int.tryParse(v.toString());
  }

  String? get vcNickname => text('vc_nickname');
  String? get vcCpf => text('vc_cpf');
  String? get vcMobile => text('vc_mobile');
  String? get vcPhone => text('vc_phone');
  String? get vcEmail => text('vc_email');
  String? get vcRecordNumber => text('vc_record_number');
  String? get vcReturnAlert => text('vc_return_alert');
  String? get vcReferral => text('vc_referral');
  int? get itGender => code('it_gender');
  int? get itSource => code('it_source');

  bool get isActive => itStatus == 1;

  /// Idade: a do backend (qt_age) ou calculada da data de nascimento.
  int? get age {
    final q = _json['qt_age'];
    if (q is num) return q.toInt();
    return dtBirth == null ? null : Dates.age(dtBirth!);
  }

  bool get isMinor => (age ?? 99) < 18;

  /// "Mariana Souza (Mari)".
  String get displayName =>
      vcNickname == null ? vcName : '$vcName ($vcNickname)';

  /// Iniciais para o avatar: "MS".
  String get initials {
    final parts = vcName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get cpfFormatted =>
      vcCpf == null ? '-' : Masks.format(MaskType.cpf, vcCpf!);
  String get mobileFormatted =>
      vcMobile == null ? '-' : Masks.format(MaskType.phone, vcMobile!);
  String get phoneFormatted =>
      vcPhone == null ? '-' : Masks.format(MaskType.phone, vcPhone!);

  /// Como conheceu, com "Indicação: Fulano" quando houver.
  String get sourceLabel {
    if (itSource == null) return '-';
    final label = PatientSource.label(itSource);
    final by = text('vc_referrer') ?? vcReferral;
    return by == null ? label : '$label: $by';
  }

  bool get hasReturnAlert => dtReturnAlert != null;

  Map<String, dynamic> toJson() => {..._json};
}

/// Nota geral do paciente (od.patient_note).
class PatientNote {
  const PatientNote({
    required this.nrNote,
    required this.vcNote,
    required this.nrUser,
    required this.vcUser,
    this.dhNote,
  });

  factory PatientNote.fromJson(Map<String, dynamic> json) => PatientNote(
    nrNote: _int(json['nr_note']),
    vcNote: _str(json['vc_note']) ?? '',
    nrUser: _int(json['nr_user']),
    vcUser: _str(json['vc_user']) ?? '',
    dhNote: DateTime.tryParse(_str(json['dh_note']) ?? ''),
  );

  final int nrNote;
  final String vcNote;
  final int nrUser;
  final String vcUser;
  final DateTime? dhNote;
}

/// Pagina de patient_list.
class PatientPage {
  const PatientPage({
    required this.patients,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PatientPage.fromJson(Map<String, dynamic> json) => PatientPage(
    patients: [
      for (final p in _list(json['patients'])) Patient.fromJson(_map(p)),
    ],
    total: _int(json['qt_total'] ?? 0),
    page: _int(json['nr_page'] ?? 1),
    pageSize: _int(json['qt_page_size'] ?? 50),
  );

  final List<Patient> patients;
  final int total;
  final int page;
  final int pageSize;

  int get pageCount => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
}

/// Ficha completa (patient_get): paciente + notas.
class PatientRecord {
  const PatientRecord({required this.patient, required this.notes});

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    patient: Patient.fromJson(_map(json['patient'])),
    notes: [
      for (final n in _list(json['notes'])) PatientNote.fromJson(_map(n)),
    ],
  );

  final Patient patient;
  final List<PatientNote> notes;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _str(dynamic value) => value?.toString();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<dynamic> _list(dynamic value) => value is List ? value : const [];
