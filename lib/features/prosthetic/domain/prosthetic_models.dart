/// Controle Protetico (ad.prosthetic_list / _save / _stage).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();

/// Etapas do trabalho (od.prosthetic_work.it_stage).
abstract final class ProstheticStage {
  static const toSend = 1;
  static const atLab = 2;
  static const trial = 3;
  static const received = 4;
  static const installed = 5;
  static const cancelled = 90;

  static const all = [toSend, atLab, trial, received, installed, cancelled];

  static String label(int s) => switch (s) {
    toSend => Strings.prosStageToSend,
    atLab => Strings.prosStageAtLab,
    trial => Strings.prosStageTrial,
    received => Strings.prosStageReceived,
    installed => Strings.prosStageInstalled,
    cancelled => Strings.prosStageCancelled,
    _ => '-',
  };

  static Color color(int s) => switch (s) {
    toSend => AppColors.muted,
    atLab => AppColors.primary,
    trial => AppColors.warning,
    received => AppColors.accent,
    installed => AppColors.success,
    _ => AppColors.danger,
  };

  static IconData icon(int s) => switch (s) {
    toSend => Icons.inventory_2_outlined,
    atLab => Icons.local_shipping_outlined,
    trial => Icons.front_hand_outlined,
    received => Icons.move_to_inbox_outlined,
    installed => Icons.check_circle_outline_rounded,
    _ => Icons.cancel_outlined,
  };

  /// Proxima etapa sugerida.
  static int next(int s) => switch (s) {
    toSend => atLab,
    atLab => received,
    trial => atLab,
    received => installed,
    _ => s,
  };

  static bool isClosed(int s) => s == installed || s == cancelled;
}

/// Filtros da lista.
enum ProstheticFilter {
  open('open', Strings.prosFilterOpen),
  late('late', Strings.prosFilterLate),
  done('done', Strings.prosFilterDone),
  cancelled('cancelled', Strings.prosFilterCancelled),
  all('all', Strings.prosFilterAll);

  const ProstheticFilter(this.code, this.label);

  final String code;
  final String label;
}

class ProstheticStep {
  const ProstheticStep({
    required this.nrStep,
    required this.itStage,
    this.dtStep,
    this.vcNotes,
    this.vcUser,
  });

  factory ProstheticStep.fromJson(Map<String, dynamic> j) => ProstheticStep(
    nrStep: _int(j['nr_step']),
    itStage: _int(j['it_stage']),
    dtStep: _date(j['dt_step']),
    vcNotes: j['vc_notes'] as String?,
    vcUser: j['vc_user'] as String?,
  );

  final int nrStep;
  final int itStage;
  final DateTime? dtStep;
  final String? vcNotes;
  final String? vcUser;
}

class ProstheticWork {
  const ProstheticWork({
    required this.nrWork,
    required this.nrPatient,
    required this.vcPatient,
    required this.vcDescription,
    required this.itStage,
    this.nrProfessional,
    this.vcProfessional,
    this.nrSupplier,
    this.vcLab,
    this.vcLabFree,
    this.vcTooth,
    this.vcShade,
    this.vcNotes,
    this.dtSent,
    this.dtExpected,
    this.dtReceived,
    this.dtInstalled,
    this.vlCost,
    this.nrEntry,
    this.idLate = false,
    this.steps = const [],
  });

  factory ProstheticWork.fromJson(Map<String, dynamic> j) => ProstheticWork(
    nrWork: _int(j['nr_work']),
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient'] as String? ?? '',
    vcDescription: j['vc_description'] as String? ?? '',
    itStage: _int(j['it_stage']),
    nrProfessional: (j['nr_professional'] as num?)?.toInt(),
    vcProfessional: j['vc_professional'] as String?,
    nrSupplier: (j['nr_supplier'] as num?)?.toInt(),
    vcLab: j['vc_lab'] as String?,
    vcLabFree: j['vc_lab_free'] as String?,
    vcTooth: j['vc_tooth'] as String?,
    vcShade: j['vc_shade'] as String?,
    vcNotes: j['vc_notes'] as String?,
    dtSent: _date(j['dt_sent']),
    dtExpected: _date(j['dt_expected']),
    dtReceived: _date(j['dt_received']),
    dtInstalled: _date(j['dt_installed']),
    vlCost: (j['vl_cost'] as num?)?.toDouble(),
    nrEntry: (j['nr_entry'] as num?)?.toInt(),
    idLate: j['id_late'] as bool? ?? false,
    steps: _list(j['steps']).map(ProstheticStep.fromJson).toList(),
  );

  final int nrWork;
  final int nrPatient;
  final String vcPatient;
  final String vcDescription;
  final int itStage;
  final int? nrProfessional;
  final String? vcProfessional;
  final int? nrSupplier;

  /// Laboratorio para exibir (fornecedor ou nome livre).
  final String? vcLab;

  /// Nome livre (laboratorio sem cadastro).
  final String? vcLabFree;
  final String? vcTooth;
  final String? vcShade;
  final String? vcNotes;
  final DateTime? dtSent;
  final DateTime? dtExpected;
  final DateTime? dtReceived;
  final DateTime? dtInstalled;
  final double? vlCost;
  final int? nrEntry;
  final bool idLate;
  final List<ProstheticStep> steps;

  bool get isClosed => ProstheticStage.isClosed(itStage);

  /// Recebimento vai gerar a conta a pagar do laboratorio.
  bool get willCreatePayable =>
      nrEntry == null && nrSupplier != null && (vlCost ?? 0) > 0;
}

class ProstheticListData {
  const ProstheticListData({
    this.works = const [],
    this.labs = const [],
    this.qtToSend = 0,
    this.qtAtLab = 0,
    this.qtTrial = 0,
    this.qtReady = 0,
    this.qtLate = 0,
    this.idTruncated = false,
  });

  factory ProstheticListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? const {};
    return ProstheticListData(
      works: _list(j['works']).map(ProstheticWork.fromJson).toList(),
      labs: [
        for (final l in _list(j['labs']))
          (id: _int(l['nr_supplier']), name: l['vc_name'] as String? ?? ''),
      ],
      qtToSend: _int(t['qt_to_send']),
      qtAtLab: _int(t['qt_at_lab']),
      qtTrial: _int(t['qt_trial']),
      qtReady: _int(t['qt_ready']),
      qtLate: _int(t['qt_late']),
      idTruncated: j['id_truncated'] as bool? ?? false,
    );
  }

  final List<ProstheticWork> works;
  final List<({int id, String name})> labs;
  final int qtToSend;
  final int qtAtLab;
  final int qtTrial;
  final int qtReady;
  final int qtLate;
  final bool idTruncated;
}
