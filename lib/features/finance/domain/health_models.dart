import '../../../l10n/strings.dart';

/// Situacao da guia (od.health_guide.it_status).
abstract final class GuideStatus {
  static const open = 1;
  static const invoiced = 2;
  static const paid = 3;
  static const cancelled = 90;

  static String label(int status) => switch (status) {
    invoiced => Strings.guideInvoiced,
    paid => Strings.guidePaid,
    cancelled => Strings.finStatusCancelled,
    _ => Strings.guideOpen,
  };
}

/// Filtro da lista (ad.health_guide_list.vc_status).
enum GuideFilter { all, open, invoiced, paid, cancelled }

class PlanPrice {
  const PlanPrice({
    required this.nrProcedure,
    required this.vlPrice,
    this.vcProcedure = '',
    this.vcCode,
    this.vlPrivate,
  });

  factory PlanPrice.fromJson(Map<String, dynamic> j) => PlanPrice(
    nrProcedure: _int(j['nr_procedure']),
    vcProcedure: j['vc_procedure']?.toString() ?? '',
    vcCode: j['vc_code']?.toString(),
    vlPrice: _double(j['vl_price']),
    vlPrivate: j['vl_private'] == null ? null : _double(j['vl_private']),
  );

  final int nrProcedure;
  final String vcProcedure;
  final String? vcCode;
  final double vlPrice;

  /// Valor particular cobrado hoje (para comparar).
  final double? vlPrivate;

  Map<String, dynamic> toJson() => {
    'nr_procedure': nrProcedure,
    'vl_price': vlPrice,
    'vc_code': vcCode,
  };
}

class HealthPlan {
  const HealthPlan({
    required this.nrPlan,
    required this.vcName,
    this.vcAns,
    this.vcDocument,
    this.qtPaymentDays = 30,
    this.nrAccount,
    this.vcAccount,
    this.vcNotes,
    this.itStatus = 1,
    this.qtOpen = 0,
    this.qtInvoiced = 0,
    this.vlInvoiced = 0,
    this.prices = const [],
  });

  factory HealthPlan.fromJson(Map<String, dynamic> j) => HealthPlan(
    nrPlan: _int(j['nr_plan']),
    vcName: j['vc_name']?.toString() ?? '',
    vcAns: j['vc_ans']?.toString(),
    vcDocument: j['vc_document']?.toString(),
    qtPaymentDays: _int(j['qt_payment_days'] ?? 30),
    nrAccount: j['nr_account'] == null ? null : _int(j['nr_account']),
    vcAccount: j['vc_account']?.toString(),
    vcNotes: j['vc_notes']?.toString(),
    itStatus: _int(j['it_status'] ?? 1),
    qtOpen: _int(j['qt_open'] ?? 0),
    qtInvoiced: _int(j['qt_invoiced'] ?? 0),
    vlInvoiced: _double(j['vl_invoiced']),
    prices: [
      for (final p in (j['prices'] as List? ?? const []))
        PlanPrice.fromJson((p as Map).cast<String, dynamic>()),
    ],
  );

  final int nrPlan;
  final String vcName;
  final String? vcAns;
  final String? vcDocument;
  final int qtPaymentDays;
  final int? nrAccount;
  final String? vcAccount;
  final String? vcNotes;
  final int itStatus;
  final int qtOpen;
  final int qtInvoiced;
  final double vlInvoiced;
  final List<PlanPrice> prices;

  bool get isActive => itStatus == 1;

  /// Preco do convenio para o procedimento (null = fora da tabela).
  double? priceOf(int nrProcedure) {
    for (final p in prices) {
      if (p.nrProcedure == nrProcedure) return p.vlPrice;
    }
    return null;
  }
}

class GuideItem {
  const GuideItem({
    required this.nrProcedure,
    this.nrItem = 0,
    this.vcProcedure = '',
    this.vcTooth,
    this.qtQuantity = 1,
    this.vlUnit = 0,
    this.vlTotal = 0,
    this.vlDenied = 0,
  });

  factory GuideItem.fromJson(Map<String, dynamic> j) => GuideItem(
    nrItem: _int(j['nr_item']),
    nrProcedure: _int(j['nr_procedure']),
    vcProcedure: j['vc_procedure']?.toString() ?? '',
    vcTooth: j['vc_tooth']?.toString(),
    qtQuantity: _int(j['qt_quantity'] ?? 1),
    vlUnit: _double(j['vl_unit']),
    vlTotal: _double(j['vl_total']),
    vlDenied: _double(j['vl_denied']),
  );

  final int nrItem;
  final int nrProcedure;
  final String vcProcedure;
  final String? vcTooth;
  final int qtQuantity;
  final double vlUnit;
  final double vlTotal;
  final double vlDenied;
}

class HealthGuide {
  const HealthGuide({
    required this.nrGuide,
    required this.nrPlan,
    required this.nrPatient,
    required this.dtService,
    this.vcPlan = '',
    this.vcPatient = '',
    this.nrProfessional,
    this.vcProfessional,
    this.vcGuideNumber,
    this.vcCardNumber,
    this.vlTotal = 0,
    this.itStatus = GuideStatus.open,
    this.dtInvoiced,
    this.dtDue,
    this.dtPaid,
    this.vlPaid,
    this.vlDenied,
    this.vcNotes,
    this.items = const [],
  });

  factory HealthGuide.fromJson(Map<String, dynamic> j) => HealthGuide(
    nrGuide: _int(j['nr_guide']),
    nrPlan: _int(j['nr_plan']),
    vcPlan: j['vc_plan']?.toString() ?? '',
    nrPatient: _int(j['nr_patient']),
    vcPatient: j['vc_patient']?.toString() ?? '',
    nrProfessional: j['nr_professional'] == null
        ? null
        : _int(j['nr_professional']),
    vcProfessional: j['vc_professional']?.toString(),
    vcGuideNumber: j['vc_guide_number']?.toString(),
    vcCardNumber: j['vc_card_number']?.toString(),
    dtService: _date(j['dt_service']) ?? DateTime(2000),
    vlTotal: _double(j['vl_total']),
    itStatus: _int(j['it_status'] ?? 1),
    dtInvoiced: _date(j['dt_invoiced']),
    dtDue: _date(j['dt_due']),
    dtPaid: _date(j['dt_paid']),
    vlPaid: j['vl_paid'] == null ? null : _double(j['vl_paid']),
    vlDenied: j['vl_denied'] == null ? null : _double(j['vl_denied']),
    vcNotes: j['vc_notes']?.toString(),
    items: [
      for (final i in (j['items'] as List? ?? const []))
        GuideItem.fromJson((i as Map).cast<String, dynamic>()),
    ],
  );

  final int nrGuide;
  final int nrPlan;
  final String vcPlan;
  final int nrPatient;
  final String vcPatient;
  final int? nrProfessional;
  final String? vcProfessional;
  final String? vcGuideNumber;
  final String? vcCardNumber;
  final DateTime dtService;
  final double vlTotal;
  final int itStatus;
  final DateTime? dtInvoiced;
  final DateTime? dtDue;
  final DateTime? dtPaid;
  final double? vlPaid;
  final double? vlDenied;
  final String? vcNotes;
  final List<GuideItem> items;

  bool get isOpen => itStatus == GuideStatus.open;
  bool get isInvoiced => itStatus == GuideStatus.invoiced;
  bool get isPaid => itStatus == GuideStatus.paid;
}

class GuideList {
  const GuideList({
    this.guides = const [],
    this.vlOpen = 0,
    this.vlInvoiced = 0,
    this.vlPaid = 0,
    this.vlDenied = 0,
  });

  factory GuideList.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map? ?? const {}).cast<String, dynamic>();
    return GuideList(
      guides: [
        for (final g in (j['guides'] as List? ?? const []))
          HealthGuide.fromJson((g as Map).cast<String, dynamic>()),
      ],
      vlOpen: _double(t['vl_open']),
      vlInvoiced: _double(t['vl_invoiced']),
      vlPaid: _double(t['vl_paid']),
      vlDenied: _double(t['vl_denied']),
    );
  }

  final List<HealthGuide> guides;
  final double vlOpen;
  final double vlInvoiced;
  final double vlPaid;
  final double vlDenied;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic v) {
  final p = DateTime.tryParse(v?.toString() ?? '');
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

/// Resposta de ad.health_plan_list: convenios e o que os formularios usam.
class PlanCatalog {
  const PlanCatalog({
    this.plans = const [],
    this.procedures = const [],
    this.professionals = const [],
  });

  factory PlanCatalog.fromJson(Map<String, dynamic> j) => PlanCatalog(
    plans: [
      for (final p in (j['plans'] as List? ?? const []))
        HealthPlan.fromJson((p as Map).cast<String, dynamic>()),
    ],
    procedures: [
      for (final p in (j['procedures'] as List? ?? const []))
        (
          nr: _int((p as Map)['nr_procedure']),
          name: p['vc_name']?.toString() ?? '',
        ),
    ],
    professionals: [
      for (final p in (j['professionals'] as List? ?? const []))
        (
          nr: _int((p as Map)['nr_professional']),
          name: p['vc_name']?.toString() ?? '',
        ),
    ],
  );

  final List<HealthPlan> plans;
  final List<({int nr, String name})> procedures;
  final List<({int nr, String name})> professionals;

  List<HealthPlan> get activePlans => [
    for (final p in plans)
      if (p.isActive) p,
  ];
}
