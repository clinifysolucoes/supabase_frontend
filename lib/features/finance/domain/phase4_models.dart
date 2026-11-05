import '../../../l10n/strings.dart';

/// Conta recorrente (regra): todo mes no dia [itDay], de [dtStart] ate
/// [dtEnd] (nulo = sem data final). Os lancamentos sao gerados pelo banco.
class FinRecurrence {
  const FinRecurrence({
    required this.nrRecurrence,
    required this.itKind,
    required this.nrCategory,
    required this.vcDescription,
    required this.vlAmount,
    required this.itDay,
    required this.dtStart,
    this.vcCategory,
    this.itCostType,
    this.nrAccount,
    this.vcAccount,
    this.nrSupplier,
    this.vcSupplier,
    this.nrPatient,
    this.vcPatient,
    this.itPaymentMethod,
    this.dtEnd,
    this.itStatus = 1,
    this.vcNotes,
    this.dtNext,
    this.qtOpen = 0,
    this.qtPaid = 0,
  });

  factory FinRecurrence.fromJson(Map<String, dynamic> j) => FinRecurrence(
    nrRecurrence: _int(j['nr_recurrence']),
    itKind: _int(j['it_kind'] ?? 1),
    nrCategory: _int(j['nr_category']),
    vcCategory: _str(j['vc_category']),
    itCostType: _intOrNull(j['it_cost_type']),
    nrAccount: _intOrNull(j['nr_account']),
    vcAccount: _str(j['vc_account']),
    nrSupplier: _intOrNull(j['nr_supplier']),
    vcSupplier: _str(j['vc_supplier']),
    nrPatient: _intOrNull(j['nr_patient']),
    vcPatient: _str(j['vc_patient']),
    vcDescription: _str(j['vc_description']) ?? '',
    vlAmount: _double(j['vl_amount']),
    itDay: _int(j['it_day'] ?? 1),
    itPaymentMethod: _intOrNull(j['it_payment_method']),
    dtStart: _date(j['dt_start']) ?? DateTime(2000),
    dtEnd: _date(j['dt_end']),
    itStatus: _int(j['it_status'] ?? 1),
    vcNotes: _str(j['vc_notes']),
    dtNext: _date(j['dt_next']),
    qtOpen: _int(j['qt_open'] ?? 0),
    qtPaid: _int(j['qt_paid'] ?? 0),
  );

  final int nrRecurrence;
  final int itKind;
  final int nrCategory;
  final String? vcCategory;
  final int? itCostType;
  final int? nrAccount;
  final String? vcAccount;
  final int? nrSupplier;
  final String? vcSupplier;
  final int? nrPatient;
  final String? vcPatient;
  final String vcDescription;
  final double vlAmount;
  final int itDay;
  final int? itPaymentMethod;
  final DateTime dtStart;
  final DateTime? dtEnd;
  final int itStatus;
  final String? vcNotes;

  /// Proximo vencimento em aberto.
  final DateTime? dtNext;
  final int qtOpen;
  final int qtPaid;

  bool get isActive => itStatus == 1;

  /// Fornecedor (a pagar) ou paciente (a receber).
  String? get counterpart => vcSupplier ?? vcPatient;

  static List<FinRecurrence> listFromJson(Map<String, dynamic> j) => [
    for (final r in _list(j['recurrences'])) FinRecurrence.fromJson(_map(r)),
  ];
}

/// Consulta que ja aconteceu e ainda nao foi fechada no financeiro.
class PendingCheckout {
  const PendingCheckout({
    required this.nrAppointment,
    required this.dhStart,
    required this.vcPatient,
    this.vcProfessional,
    this.vcProcedure,
  });

  factory PendingCheckout.fromJson(Map<String, dynamic> j) => PendingCheckout(
    nrAppointment: _int(j['nr_appointment']),
    dhStart:
        DateTime.tryParse(j['dh_start']?.toString() ?? '')?.toLocal() ??
        DateTime(2000),
    vcPatient: _str(j['vc_patient']) ?? '',
    vcProfessional: _str(j['vc_professional']),
    vcProcedure: _str(j['vc_procedure']),
  );

  final int nrAppointment;
  final DateTime dhStart;
  final String vcPatient;
  final String? vcProfessional;
  final String? vcProcedure;

  static List<PendingCheckout> listFromJson(Map<String, dynamic> j) => [
    for (final a in _list(j['appointments'])) PendingCheckout.fromJson(_map(a)),
  ];
}

/// Tipo do anexo.
abstract final class AttachmentType {
  static const document = 1;
  static const receipt = 2;
  static const all = [document, receipt];

  static String label(int t) =>
      t == receipt ? Strings.attachReceipt : Strings.attachDocument;
}

/// Anexo de uma conta (o arquivo fica no Storage).
class FinAttachment {
  const FinAttachment({
    required this.nrAttachment,
    required this.nrEntry,
    required this.vcName,
    this.itType = AttachmentType.document,
    this.vcMime,
    this.qtBytes,
    this.dhCreated,
    this.vcUser,
  });

  factory FinAttachment.fromJson(Map<String, dynamic> j) => FinAttachment(
    nrAttachment: _int(j['nr_attachment']),
    nrEntry: _int(j['nr_entry']),
    itType: _int(j['it_type'] ?? 1),
    vcName: _str(j['vc_name']) ?? '',
    vcMime: _str(j['vc_mime']),
    qtBytes: _intOrNull(j['qt_bytes']),
    dhCreated: DateTime.tryParse(j['dh_created']?.toString() ?? '')?.toLocal(),
    vcUser: _str(j['vc_user']),
  );

  final int nrAttachment;
  final int nrEntry;
  final int itType;
  final String vcName;
  final String? vcMime;
  final int? qtBytes;
  final DateTime? dhCreated;
  final String? vcUser;

  bool get isPdf => vcMime == 'application/pdf';

  static List<FinAttachment> listFromJson(Map<String, dynamic> j) => [
    for (final a in _list(j['attachments'])) FinAttachment.fromJson(_map(a)),
  ];

  /// Tipo do arquivo pela extensao (o banco aceita PDF e imagens).
  static String? mimeOf(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => null,
    };
  }

  static const extensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];

  /// Limite do banco (10 MB).
  static const maxBytes = 10 * 1024 * 1024;
}

/// Dados do pagamento em cartao ou cheque, que vao para os recebiveis.
class PaymentDetails {
  const PaymentDetails({
    this.vcCardBrand,
    this.vcCardLast4,
    this.vcAuthorization,
    this.vcHolderName,
    this.vcHolderDocument,
    this.vcBankName,
    this.vcCheckNumber,
  });

  final String? vcCardBrand;
  final String? vcCardLast4;
  final String? vcAuthorization;
  final String? vcHolderName;
  final String? vcHolderDocument;
  final String? vcBankName;
  final String? vcCheckNumber;

  /// So as chaves preenchidas (o banco ignora as ausentes).
  Map<String, dynamic> toJson() => {
    'vc_card_brand': ?_nz(vcCardBrand),
    'vc_card_last4': ?_nz(vcCardLast4),
    'vc_authorization': ?_nz(vcAuthorization),
    'vc_holder_name': ?_nz(vcHolderName),
    'vc_holder_document': ?_nz(vcHolderDocument),
    'vc_bank_name': ?_nz(vcBankName),
    'vc_check_number': ?_nz(vcCheckNumber),
  };

  static String? _nz(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

int? _intOrNull(dynamic v) => v == null ? null : _int(v);

double _double(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

String? _str(dynamic v) => v?.toString();

DateTime? _date(dynamic v) {
  final p = DateTime.tryParse(v?.toString() ?? '');
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

List<dynamic> _list(dynamic v) => v is List ? v : const [];
