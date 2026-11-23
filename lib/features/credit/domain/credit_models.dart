/// Consulta de credito (SPC/Serasa) do paciente
/// (ad.credit_check_list + Edge Function credit-check).
library;

import '../../../l10n/strings.dart';

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;

abstract final class CreditProvider {
  static String label(int p) => switch (p) {
    1 => 'Serasa',
    2 => 'SPC Brasil',
    3 => 'Boa Vista',
    _ => '-',
  };
}

class CreditCheck {
  const CreditCheck({
    required this.nrCheck,
    required this.itProvider,
    required this.itStatus,
    this.vcDocumentMasked,
    this.itResult,
    this.qtScore,
    this.qtDebts,
    this.vlDebts,
    this.vcProtocol,
    this.vcError,
    this.vcUser,
    this.dhCreated,
  });

  factory CreditCheck.fromJson(Map<String, dynamic> j) => CreditCheck(
    nrCheck: _int(j['nr_check']),
    itProvider: _int(j['it_provider'], 1),
    itStatus: _int(j['it_status'], 1),
    vcDocumentMasked: j['vc_document_masked'] as String?,
    itResult: (j['it_result'] as num?)?.toInt(),
    qtScore: (j['qt_score'] as num?)?.toInt(),
    qtDebts: (j['qt_debts'] as num?)?.toInt(),
    vlDebts: (j['vl_debts'] as num?)?.toDouble(),
    vcProtocol: j['vc_protocol'] as String?,
    vcError: j['vc_error'] as String?,
    vcUser: j['vc_user'] as String?,
    dhCreated: DateTime.tryParse(j['dh_created'] as String? ?? '')?.toLocal(),
  );

  final int nrCheck;
  final int itProvider;

  /// 1 pendente | 2 concluida | 9 erro
  final int itStatus;
  final String? vcDocumentMasked;

  /// 1 nada consta | 2 com restricoes (so concluida)
  final int? itResult;
  final int? qtScore;
  final int? qtDebts;
  final double? vlDebts;
  final String? vcProtocol;
  final String? vcError;
  final String? vcUser;
  final DateTime? dhCreated;

  bool get isDone => itStatus == 2;
  bool get isError => itStatus == 9;
  bool get hasRestrictions => itResult == 2;

  /// Texto curto do resultado.
  String get label {
    if (isError) {
      return Strings.errorMessage(vcError ?? '', const {}, Strings.creditError);
    }
    if (!isDone) return Strings.creditPending;
    return hasRestrictions ? Strings.creditRestricted : Strings.creditClean;
  }
}

class CreditCheckData {
  const CreditCheckData({
    this.idEnabled = false,
    this.idCanCheck = false,
    this.checks = const [],
  });

  factory CreditCheckData.fromJson(Map<String, dynamic> j) => CreditCheckData(
    idEnabled: j['id_enabled'] == true,
    idCanCheck: j['id_can_check'] == true,
    checks: [
      for (final c in (j['checks'] as List? ?? const []))
        CreditCheck.fromJson((c as Map).cast<String, dynamic>()),
    ],
  );

  final bool idEnabled;
  final bool idCanCheck;
  final List<CreditCheck> checks;
}
