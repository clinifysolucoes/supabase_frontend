/// Casos de alinhadores (ad.aligner_list / aligner_save).
library;

import '../../../l10n/strings.dart';

/// Situacao do caso (od.aligner_case.it_status).
enum AlignerStatus {
  started(1, Strings.alignerStarted),
  pendingClinic(2, Strings.alignerPendingClinic),
  pendingCompany(3, Strings.alignerPendingCompany),
  treatment(4, Strings.alignerTreatment),
  finished(5, Strings.alignerFinished),
  cancelled(90, Strings.alignerCancelled);

  const AlignerStatus(this.code, this.label);

  final int code;
  final String label;

  bool get isPending => this == pendingClinic || this == pendingCompany;

  static AlignerStatus of(int code) =>
      values.firstWhere((s) => s.code == code, orElse: () => started);
}

/// Sistemas mais usados (sugestoes do campo; texto livre).
const alignerSystems = [
  'ClearTek',
  'Crystal Aligner',
  'InnovAligner',
  'Invisalign',
  'LineaAlign',
  'Rittes AlignClub',
  'SmileGUIDE',
  'Ortho Aligner',
];

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
DateTime? _date(Object? v) => DateTime.tryParse(v?.toString() ?? '');

class AlignerEvent {
  const AlignerEvent({
    required this.status,
    required this.qtCurrent,
    this.dhEvent,
    this.vcText,
    this.vcUser,
  });

  factory AlignerEvent.fromJson(Map<String, dynamic> j) => AlignerEvent(
    status: AlignerStatus.of(_int(j['it_status'], 1)),
    qtCurrent: _int(j['qt_current']),
    dhEvent: _date(j['dh_event'])?.toLocal(),
    vcText: j['vc_text'] as String?,
    vcUser: j['vc_user'] as String?,
  );

  final AlignerStatus status;
  final int qtCurrent;
  final DateTime? dhEvent;
  final String? vcText;
  final String? vcUser;
}

class AlignerCase {
  const AlignerCase({
    required this.nrCase,
    required this.nrPatient,
    required this.vcPatient,
    required this.vcSystem,
    required this.status,
    this.nrProfessional,
    this.vcProfessional,
    this.vcCaseNumber,
    this.qtAligners = 1,
    this.qtCurrent = 0,
    this.qtDaysChange = 14,
    this.dtStart,
    this.dtFinished,
    this.dtForecast,
    this.vcPending,
    this.vcNotes,
    this.events = const [],
  });

  factory AlignerCase.fromJson(Map<String, dynamic> j) => AlignerCase(
    nrCase: _int(j['nr_case']),
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient'] as String? ?? '',
    vcSystem: j['vc_system'] as String? ?? '',
    status: AlignerStatus.of(_int(j['it_status'], 1)),
    nrProfessional: (j['nr_professional'] as num?)?.toInt(),
    vcProfessional: j['vc_professional'] as String?,
    vcCaseNumber: j['vc_case_number'] as String?,
    qtAligners: _int(j['qt_aligners'], 1),
    qtCurrent: _int(j['qt_current']),
    qtDaysChange: _int(j['qt_days_change'], 14),
    dtStart: _date(j['dt_start']),
    dtFinished: _date(j['dt_finished']),
    dtForecast: _date(j['dt_forecast']),
    vcPending: j['vc_pending'] as String?,
    vcNotes: j['vc_notes'] as String?,
    events: [
      for (final e in (j['events'] as List? ?? const []))
        AlignerEvent.fromJson((e as Map).cast<String, dynamic>()),
    ],
  );

  final int nrCase;
  final int nrPatient;
  final String vcPatient;
  final String vcSystem;
  final AlignerStatus status;
  final int? nrProfessional;
  final String? vcProfessional;
  final String? vcCaseNumber;
  final int qtAligners;
  final int qtCurrent;
  final int qtDaysChange;
  final DateTime? dtStart;
  final DateTime? dtFinished;
  final DateTime? dtForecast;
  final String? vcPending;
  final String? vcNotes;
  final List<AlignerEvent> events;

  double get progress => qtAligners == 0 ? 0 : qtCurrent / qtAligners;
}

class AlignerListData {
  const AlignerListData({this.cases = const [], this.totals = const {}});

  factory AlignerListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AlignerListData(
      cases: [
        for (final c in (j['cases'] as List? ?? const []))
          AlignerCase.fromJson((c as Map).cast<String, dynamic>()),
      ],
      totals: {
        AlignerStatus.started: _int(t['qt_started']),
        AlignerStatus.pendingClinic: _int(t['qt_pending_clinic']),
        AlignerStatus.pendingCompany: _int(t['qt_pending_company']),
        AlignerStatus.treatment: _int(t['qt_treatment']),
        AlignerStatus.finished: _int(t['qt_finished']),
      },
    );
  }

  final List<AlignerCase> cases;
  final Map<AlignerStatus, int> totals;
}
