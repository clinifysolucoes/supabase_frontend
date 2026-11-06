import '../../finance/domain/receipt_models.dart';

/// Documentos do paciente, modelos e medicamentos
/// (ad.document_template_list / ad.medication_list / ad.patient_document_list).

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

List<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).cast<Map<String, dynamic>>();

/// Tipo de documento.
enum DocumentKind {
  certificate(1, 'Atestado'),
  prescription(2, 'Receituário'),
  contract(3, 'Contrato'),
  attendance(4, 'Declaração de comparecimento'),
  other(9, 'Outro');

  const DocumentKind(this.code, this.label);
  final int code;
  final String label;

  static DocumentKind of(int? code) =>
      values.firstWhere((k) => k.code == code, orElse: () => other);
}

/// Via de uso do medicamento (agrupa o receituario).
enum MedicationUse {
  internal(1, 'Uso interno'),
  external(2, 'Uso externo'),
  topical(3, 'Uso tópico');

  const MedicationUse(this.code, this.label);
  final int code;
  final String label;

  static MedicationUse of(int? code) =>
      values.firstWhere((u) => u.code == code, orElse: () => internal);
}

class DocumentTemplate {
  const DocumentTemplate({
    required this.nrTemplate,
    required this.kind,
    required this.vcName,
    required this.vcBody,
    this.itStatus = 1,
  });

  factory DocumentTemplate.fromJson(Map<String, dynamic> j) => DocumentTemplate(
    nrTemplate: _int(j['nr_template']),
    kind: DocumentKind.of(_int(j['it_kind'], 9)),
    vcName: j['vc_name'] as String? ?? '',
    vcBody: j['vc_body'] as String? ?? '',
    itStatus: _int(j['it_status'], 1),
  );

  final int nrTemplate;
  final DocumentKind kind;
  final String vcName;
  final String vcBody;
  final int itStatus;

  bool get isActive => itStatus == 1;

  /// Extras que o modelo usa e o usuario informa na emissao.
  List<String> get extras => [
    for (final e in DocumentExtras.all)
      if (vcBody.contains('{{$e}}')) e,
  ];
}

abstract final class DocumentExtras {
  static const all = [
    'dias',
    'cid',
    'hora_inicio',
    'hora_fim',
    'valor',
    'texto',
  ];
}

class DocumentTemplateList {
  const DocumentTemplateList({
    this.templates = const [],
    this.fields = const [],
    this.canUpdate = false,
  });

  factory DocumentTemplateList.fromJson(Map<String, dynamic> j) =>
      DocumentTemplateList(
        templates: _list(
          j['templates'],
        ).map(DocumentTemplate.fromJson).toList(),
        fields: ((j['fields'] as List?) ?? const []).cast<String>(),
        canUpdate: (j['permission'] as Map?)?['id_update'] as bool? ?? false,
      );

  final List<DocumentTemplate> templates;
  final List<String> fields;
  final bool canUpdate;
}

class Medication {
  const Medication({
    this.nrMedication,
    required this.vcName,
    this.vcPresentation,
    this.vcDosage,
    this.vcQuantity,
    this.use = MedicationUse.internal,
    this.idControlled = false,
    this.itStatus = 1,
  });

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    nrMedication: (j['nr_medication'] as num?)?.toInt(),
    vcName: j['vc_name'] as String? ?? '',
    vcPresentation: _str(j['vc_presentation']),
    vcDosage: _str(j['vc_dosage']),
    vcQuantity: _str(j['vc_quantity']),
    use: MedicationUse.of(_int(j['it_use'], 1)),
    idControlled: j['id_controlled'] as bool? ?? false,
    itStatus: _int(j['it_status'], 1),
  );

  final int? nrMedication;
  final String vcName;
  final String? vcPresentation;
  final String? vcDosage;
  final String? vcQuantity;
  final MedicationUse use;
  final bool idControlled;
  final int itStatus;

  bool get isActive => itStatus == 1;

  String get title =>
      vcPresentation == null ? vcName : '$vcName $vcPresentation';

  Map<String, dynamic> toItemJson() => {
    'nr_medication': ?nrMedication,
    'vc_name': vcName,
    'vc_presentation': vcPresentation,
    'vc_dosage': vcDosage,
    'vc_quantity': vcQuantity,
    'it_use': use.code,
    'id_controlled': idControlled,
  };

  Medication copyWith({String? vcDosage, String? vcQuantity}) => Medication(
    nrMedication: nrMedication,
    vcName: vcName,
    vcPresentation: vcPresentation,
    vcDosage: vcDosage ?? this.vcDosage,
    vcQuantity: vcQuantity ?? this.vcQuantity,
    use: use,
    idControlled: idControlled,
    itStatus: itStatus,
  );
}

class MedicationList {
  const MedicationList({this.medications = const [], this.canUpdate = false});

  factory MedicationList.fromJson(Map<String, dynamic> j) => MedicationList(
    medications: _list(j['medications']).map(Medication.fromJson).toList(),
    canUpdate: (j['permission'] as Map?)?['id_update'] as bool? ?? false,
  );

  final List<Medication> medications;
  final bool canUpdate;
}

class PatientDocument {
  const PatientDocument({
    required this.nrDocument,
    required this.kind,
    required this.vcTitle,
    this.vcBody,
    this.dtDocument,
    this.vcProfessional,
    this.vcCouncil,
    this.vcUser,
    this.items = const [],
  });

  factory PatientDocument.fromJson(Map<String, dynamic> j) => PatientDocument(
    nrDocument: _int(j['nr_document']),
    kind: DocumentKind.of(_int(j['it_kind'], 9)),
    vcTitle: j['vc_title'] as String? ?? '',
    vcBody: _str(j['vc_body']),
    dtDocument: DateTime.tryParse(j['dt_document'] as String? ?? ''),
    vcProfessional: _str(j['vc_professional']),
    vcCouncil: _str(j['vc_council']),
    vcUser: _str(j['vc_user']),
    items: _list(j['items']).map(Medication.fromJson).toList(),
  );

  final int nrDocument;
  final DocumentKind kind;
  final String vcTitle;
  final String? vcBody;
  final DateTime? dtDocument;
  final String? vcProfessional;
  final String? vcCouncil;
  final String? vcUser;
  final List<Medication> items;

  bool get hasControlled => items.any((i) => i.idControlled);
}

class DocumentPatient {
  const DocumentPatient({this.vcName = '', this.vcCpf, this.vcAddress});

  factory DocumentPatient.fromJson(Map<String, dynamic> j) => DocumentPatient(
    vcName: j['vc_name'] as String? ?? '',
    vcCpf: _str(j['vc_cpf']),
    vcAddress: _str(j['vc_address']),
  );

  final String vcName;
  final String? vcCpf;
  final String? vcAddress;
}

class PatientDocumentList {
  const PatientDocumentList({
    this.documents = const [],
    this.patient = const DocumentPatient(),
    this.issuer = const ReceiptIssuer(),
    this.canCreate = false,
    this.canUpdate = false,
  });

  factory PatientDocumentList.fromJson(Map<String, dynamic> j) {
    final perm = (j['permission'] as Map?) ?? const {};
    return PatientDocumentList(
      documents: _list(j['documents']).map(PatientDocument.fromJson).toList(),
      patient: DocumentPatient.fromJson(
        (j['patient'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      issuer: ReceiptIssuer.fromJson(
        (j['issuer'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canCreate: perm['id_create'] as bool? ?? false,
      canUpdate: perm['id_update'] as bool? ?? false,
    );
  }

  final List<PatientDocument> documents;
  final DocumentPatient patient;
  final ReceiptIssuer issuer;
  final bool canCreate;
  final bool canUpdate;
}
