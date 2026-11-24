/// Nota fiscal de servico (NFS-e): ad.invoice_list / invoice_save /
/// invoice_settings_get/save + Edge Function invoice-issue.
library;

import '../../../l10n/strings.dart';

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
double _num(Object? v, [double d = 0]) => (v as num?)?.toDouble() ?? d;
DateTime? _date(Object? v) => DateTime.tryParse(v?.toString() ?? '');

/// Situacao da nota (od.invoice.it_status).
enum InvoiceStatus {
  draft(1, Strings.nfDraft, Strings.nfDrafts),
  processing(2, Strings.nfProcessing, Strings.nfProcessing),
  issued(3, Strings.nfIssued, Strings.nfIssuedMany),
  error(8, Strings.nfError, Strings.nfErrors),
  cancelled(90, Strings.nfCancelled, Strings.nfCancelledMany);

  const InvoiceStatus(this.code, this.label, this.plural);

  final int code;
  final String label;
  final String plural;

  /// Ainda pode alterar, emitir ou descartar.
  bool get isOpen => this == draft || this == error;

  static InvoiceStatus of(int code) =>
      values.firstWhere((s) => s.code == code, orElse: () => draft);
}

/// Pendencias de configuracao (od.fn_invoice_missing).
String invoiceMissingLabel(String code) => switch (code) {
  'cnpj' => Strings.nfMissingCnpj,
  'city_registration' => Strings.nfMissingCityRegistration,
  'tax_regime' => Strings.nfMissingTaxRegime,
  'address' => Strings.nfMissingAddress,
  'city_ibge' => Strings.nfMissingIbge,
  'settings' => Strings.nfMissingSettings,
  _ => code,
};

class Invoice {
  const Invoice({
    required this.nrInvoice,
    required this.nrPatient,
    required this.vcPatient,
    required this.status,
    required this.vlService,
    required this.vcDescription,
    required this.vcTakerName,
    required this.vcTakerDocument,
    this.nrEntry,
    this.dtCompetence,
    this.pcIss = 0,
    this.vlIss = 0,
    this.vcTakerEmail,
    this.vcNumber,
    this.vcVerification,
    this.vcPdfUrl,
    this.vcXmlUrl,
    this.vcError,
    this.vcCancelReason,
    this.vcUser,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    nrInvoice: _int(j['nr_invoice']),
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient'] as String? ?? '',
    status: InvoiceStatus.of(_int(j['it_status'], 1)),
    vlService: _num(j['vl_service']),
    vcDescription: j['vc_description'] as String? ?? '',
    vcTakerName: j['vc_taker_name'] as String? ?? '',
    vcTakerDocument: j['vc_taker_document'] as String? ?? '',
    nrEntry: (j['nr_entry'] as num?)?.toInt(),
    dtCompetence: _date(j['dt_competence']),
    pcIss: _num(j['pc_iss']),
    vlIss: _num(j['vl_iss']),
    vcTakerEmail: j['vc_taker_email'] as String?,
    vcNumber: j['vc_number'] as String?,
    vcVerification: j['vc_verification'] as String?,
    vcPdfUrl: j['vc_pdf_url'] as String?,
    vcXmlUrl: j['vc_xml_url'] as String?,
    vcError: j['vc_error'] as String?,
    vcCancelReason: j['vc_cancel_reason'] as String?,
    vcUser: j['vc_user'] as String?,
  );

  final int nrInvoice;
  final int nrPatient;
  final String vcPatient;
  final InvoiceStatus status;
  final double vlService;
  final String vcDescription;
  final String vcTakerName;
  final String vcTakerDocument;
  final int? nrEntry;
  final DateTime? dtCompetence;
  final double pcIss;
  final double vlIss;
  final String? vcTakerEmail;
  final String? vcNumber;
  final String? vcVerification;
  final String? vcPdfUrl;
  final String? vcXmlUrl;
  final String? vcError;
  final String? vcCancelReason;
  final String? vcUser;
}

class InvoiceListData {
  const InvoiceListData({
    this.invoices = const [],
    this.totals = const {},
    this.vlIssued = 0,
    this.idEnabled = false,
    this.missing = const [],
  });

  factory InvoiceListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InvoiceListData(
      invoices: [
        for (final i in (j['invoices'] as List? ?? const []))
          Invoice.fromJson((i as Map).cast<String, dynamic>()),
      ],
      totals: {
        InvoiceStatus.draft: _int(t['qt_draft']),
        InvoiceStatus.processing: _int(t['qt_processing']),
        InvoiceStatus.issued: _int(t['qt_issued']),
        InvoiceStatus.error: _int(t['qt_error']),
      },
      vlIssued: _num(t['vl_issued']),
      idEnabled: j['id_enabled'] == true,
      missing: [for (final m in (j['missing'] as List? ?? const [])) '$m'],
    );
  }

  final List<Invoice> invoices;
  final Map<InvoiceStatus, int> totals;
  final double vlIssued;
  final bool idEnabled;
  final List<String> missing;

  bool get isReady => idEnabled && missing.isEmpty;
}

class InvoiceSettings {
  const InvoiceSettings({
    this.idEnabled = false,
    this.vcCityIbge,
    this.vcServiceCode = '4.12',
    this.vcCityServiceCode,
    this.vcCnae = '8630504',
    this.pcIss = 2,
    this.idIssWithheld = false,
    this.vcRpsSeries = '1',
    this.vcTplDescription = '',
    this.missing = const [],
    this.canUpdate = false,
  });

  factory InvoiceSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InvoiceSettings(
      idEnabled: s['id_enabled'] == true,
      vcCityIbge: s['vc_city_ibge'] as String?,
      vcServiceCode: s['vc_service_code'] as String? ?? '4.12',
      vcCityServiceCode: s['vc_city_service_code'] as String?,
      vcCnae: s['vc_cnae'] as String? ?? '8630504',
      pcIss: _num(s['pc_iss'], 2),
      idIssWithheld: s['id_iss_withheld'] == true,
      vcRpsSeries: s['vc_rps_series'] as String? ?? '1',
      vcTplDescription: s['vc_tpl_description'] as String? ?? '',
      missing: [for (final m in (j['missing'] as List? ?? const [])) '$m'],
      canUpdate:
          ((j['permission'] as Map?) ?? const {})['id_update'] as bool? ??
          false,
    );
  }

  final bool idEnabled;
  final String? vcCityIbge;
  final String vcServiceCode;
  final String? vcCityServiceCode;
  final String vcCnae;
  final double pcIss;
  final bool idIssWithheld;
  final String vcRpsSeries;
  final String vcTplDescription;
  final List<String> missing;
  final bool canUpdate;
}
