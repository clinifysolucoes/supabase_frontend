/// Controle de Indicacao (ad.referral_list / ad.referral_reward_save).
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _numOrNull(Object? v) => (v as num?)?.toDouble();
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();

/// Paciente indicado.
class Referral {
  const Referral({
    required this.nrPatient,
    required this.vcPatient,
    required this.vcReferrer,
    this.dhCreated,
    this.nrReferrer,
    this.idConverted = false,
    this.vlApproved,
    this.dtReward,
    this.vcReward,
    this.vlReward,
    this.vcRewardUser,
  });

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient'] as String? ?? '',
    vcReferrer: j['vc_referrer'] as String? ?? '',
    dhCreated: _date(j['dh_created'])?.toLocal(),
    nrReferrer: (j['nr_referrer'] as num?)?.toInt(),
    idConverted: j['id_converted'] as bool? ?? false,
    vlApproved: _numOrNull(j['vl_approved']),
    dtReward: _date(j['dt_reward']),
    vcReward: j['vc_reward'] as String?,
    vlReward: _numOrNull(j['vl_reward']),
    vcRewardUser: j['vc_reward_user'] as String?,
  );

  final int nrPatient;
  final String vcPatient;
  final String vcReferrer;
  final DateTime? dhCreated;

  /// Paciente que indicou (null = indicado por nome livre).
  final int? nrReferrer;
  final bool idConverted;

  /// Null sem permissao em Orcamentos.
  final double? vlApproved;
  final DateTime? dtReward;
  final String? vcReward;
  final double? vlReward;
  final String? vcRewardUser;

  bool get isRewarded => dtReward != null;

  /// Converteu e ainda nao teve recompensa.
  bool get isPending => idConverted && !isRewarded;
}

/// Quem indicou, no ranking.
class Referrer {
  const Referrer({
    required this.key,
    required this.vcReferrer,
    this.nrReferrer,
    this.qtReferred = 0,
    this.qtConverted = 0,
    this.vlApproved,
    this.vlReceived,
    this.qtRewarded = 0,
    this.qtPending = 0,
  });

  factory Referrer.fromJson(Map<String, dynamic> j) => Referrer(
    key: j['vc_key'] as String? ?? '',
    vcReferrer: j['vc_referrer'] as String? ?? '',
    nrReferrer: (j['nr_referrer'] as num?)?.toInt(),
    qtReferred: _int(j['qt_referred']),
    qtConverted: _int(j['qt_converted']),
    vlApproved: _numOrNull(j['vl_approved']),
    vlReceived: _numOrNull(j['vl_received']),
    qtRewarded: _int(j['qt_rewarded']),
    qtPending: _int(j['qt_pending']),
  );

  final String key;
  final String vcReferrer;
  final int? nrReferrer;
  final int qtReferred;
  final int qtConverted;
  final double? vlApproved;
  final double? vlReceived;
  final int qtRewarded;
  final int qtPending;

  bool get isPatient => nrReferrer != null;
}

class ReferralData {
  const ReferralData({
    this.referrals = const [],
    this.referrers = const [],
    this.bySource = const [],
    this.qtNew = 0,
    this.qtReferred = 0,
    this.qtConverted = 0,
    this.pcConversion = 0,
    this.qtPending = 0,
    this.qtRewarded = 0,
    this.vlRewards = 0,
    this.canUpdate = false,
    this.canBudgets = false,
    this.canFinance = false,
    this.idTruncated = false,
  });

  factory ReferralData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? const {};
    final p = (j['permission'] as Map?) ?? const {};
    return ReferralData(
      referrals: _list(j['referrals']).map(Referral.fromJson).toList(),
      referrers: _list(j['referrers']).map(Referrer.fromJson).toList(),
      bySource: [
        for (final s in _list(j['by_source']))
          (
            source: (s['it_source'] as num?)?.toInt(),
            qtNew: _int(s['qt_new']),
            qtConverted: _int(s['qt_converted']),
          ),
      ],
      qtNew: _int(t['qt_new']),
      qtReferred: _int(t['qt_referred']),
      qtConverted: _int(t['qt_converted']),
      pcConversion: _num(t['pc_conversion']),
      qtPending: _int(t['qt_pending_reward']),
      qtRewarded: _int(t['qt_rewarded']),
      vlRewards: _num(t['vl_rewards']),
      canUpdate: p['id_update'] as bool? ?? false,
      canBudgets: p['id_budgets'] as bool? ?? false,
      canFinance: p['id_finance'] as bool? ?? false,
      idTruncated: j['id_truncated'] as bool? ?? false,
    );
  }

  final List<Referral> referrals;
  final List<Referrer> referrers;
  final List<({int? source, int qtNew, int qtConverted})> bySource;
  final int qtNew;
  final int qtReferred;
  final int qtConverted;
  final double pcConversion;
  final int qtPending;
  final int qtRewarded;
  final double vlRewards;
  final bool canUpdate;
  final bool canBudgets;
  final bool canFinance;
  final bool idTruncated;
}

/// Periodos de atalho (pelo cadastro do paciente indicado).
enum ReferralPeriod { last12, thisYear, lastYear }

({DateTime from, DateTime to}) referralRange(ReferralPeriod p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (p) {
    ReferralPeriod.last12 => (
      from: today.subtract(const Duration(days: 364)),
      to: today,
    ),
    ReferralPeriod.thisYear => (from: DateTime(now.year), to: today),
    ReferralPeriod.lastYear => (
      from: DateTime(now.year - 1),
      to: DateTime(now.year - 1, 12, 31),
    ),
  };
}
