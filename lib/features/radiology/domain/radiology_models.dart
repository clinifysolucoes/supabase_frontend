/// Exames de imagem: centros radiologicos e pedidos de exame
/// (ad.radiology_list / radiology_save / radiology_center_save).
library;

import '../../../l10n/strings.dart';

/// Situacao do pedido (od.radiology_request.it_status).
enum RadiologyStatus {
  requested(1, Strings.rxRequestedOne, Strings.rxRequested),
  scheduled(2, Strings.rxScheduledOne, Strings.rxScheduled),
  done(3, Strings.rxDoneOne, Strings.rxDone),
  report(4, Strings.rxReport, Strings.rxReport),
  cancelled(90, Strings.rxCancelledOne, Strings.rxCancelled);

  const RadiologyStatus(this.code, this.label, this.plural);

  final int code;
  final String label;

  /// Rotulo dos filtros (no plural).
  final String plural;

  static RadiologyStatus of(int code) =>
      values.firstWhere((s) => s.code == code, orElse: () => requested);
}

/// Exames mais pedidos (atalhos; o texto e livre).
const radiologyExams = [
  'Panorâmica',
  'Periapical',
  'Interproximal (bite-wing)',
  'Oclusal',
  'Tomografia Cone Beam',
  'Telerradiografia lateral',
  'Telerradiografia frontal',
  'Documentação ortodôntica',
  'ATM',
  'Escaneamento intraoral',
  'Fotografias',
  'Modelos de estudo',
];

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
DateTime? _date(Object? v) => DateTime.tryParse(v?.toString() ?? '');

class RadiologyCenter {
  const RadiologyCenter({
    required this.nrCenter,
    required this.vcName,
    this.vcPhone,
    this.vcEmail,
    this.vcAddress,
    this.vcNotes,
    this.itIntegration = 0,
    this.vcExternalCode,
    this.itStatus = 1,
  });

  factory RadiologyCenter.fromJson(Map<String, dynamic> j) => RadiologyCenter(
    nrCenter: _int(j['nr_center']),
    vcName: j['vc_name'] as String? ?? '',
    vcPhone: j['vc_phone'] as String?,
    vcEmail: j['vc_email'] as String?,
    vcAddress: j['vc_address'] as String?,
    vcNotes: j['vc_notes'] as String?,
    itIntegration: _int(j['it_integration']),
    vcExternalCode: j['vc_external_code'] as String?,
    itStatus: _int(j['it_status'], 1),
  );

  final int nrCenter;
  final String vcName;
  final String? vcPhone;
  final String? vcEmail;
  final String? vcAddress;
  final String? vcNotes;

  /// 0 manual | 1 integracao automatica (preparada; precisa de contrato e chave).
  final int itIntegration;
  final String? vcExternalCode;
  final int itStatus;

  bool get isActive => itStatus == 1;
}

class RadiologyRequest {
  const RadiologyRequest({
    required this.nrRequest,
    required this.nrPatient,
    required this.vcPatient,
    required this.status,
    required this.exams,
    this.nrCenter,
    this.vcCenter,
    this.nrProfessional,
    this.vcProfessional,
    this.dtRequest,
    this.vcRegion,
    this.vcNotes,
    this.dtScheduled,
    this.dtDone,
    this.dtReport,
    this.vcReportUrl,
  });

  factory RadiologyRequest.fromJson(Map<String, dynamic> j) => RadiologyRequest(
    nrRequest: _int(j['nr_request']),
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient'] as String? ?? '',
    status: RadiologyStatus.of(_int(j['it_status'], 1)),
    exams: [for (final e in (j['ar_exams'] as List? ?? const [])) '$e'],
    nrCenter: (j['nr_center'] as num?)?.toInt(),
    vcCenter: j['vc_center'] as String?,
    nrProfessional: (j['nr_professional'] as num?)?.toInt(),
    vcProfessional: j['vc_professional'] as String?,
    dtRequest: _date(j['dt_request']),
    vcRegion: j['vc_region'] as String?,
    vcNotes: j['vc_notes'] as String?,
    dtScheduled: _date(j['dt_scheduled']),
    dtDone: _date(j['dt_done']),
    dtReport: _date(j['dt_report']),
    vcReportUrl: j['vc_report_url'] as String?,
  );

  final int nrRequest;
  final int nrPatient;
  final String vcPatient;
  final RadiologyStatus status;
  final List<String> exams;
  final int? nrCenter;
  final String? vcCenter;
  final int? nrProfessional;
  final String? vcProfessional;
  final DateTime? dtRequest;
  final String? vcRegion;
  final String? vcNotes;
  final DateTime? dtScheduled;
  final DateTime? dtDone;
  final DateTime? dtReport;
  final String? vcReportUrl;
}

class RadiologyListData {
  const RadiologyListData({
    this.requests = const [],
    this.centers = const [],
    this.totals = const {},
  });

  factory RadiologyListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RadiologyListData(
      requests: [
        for (final r in (j['requests'] as List? ?? const []))
          RadiologyRequest.fromJson((r as Map).cast<String, dynamic>()),
      ],
      centers: [
        for (final c in (j['centers'] as List? ?? const []))
          RadiologyCenter.fromJson((c as Map).cast<String, dynamic>()),
      ],
      totals: {
        RadiologyStatus.requested: _int(t['qt_requested']),
        RadiologyStatus.scheduled: _int(t['qt_scheduled']),
        RadiologyStatus.done: _int(t['qt_done']),
        RadiologyStatus.report: _int(t['qt_report']),
      },
    );
  }

  final List<RadiologyRequest> requests;
  final List<RadiologyCenter> centers;
  final Map<RadiologyStatus, int> totals;

  List<RadiologyCenter> get activeCenters => [
    for (final c in centers)
      if (c.isActive) c,
  ];
}
