/// Abas Agendamentos, Financeiro e Plano de tratamento da ficha
/// (ad.patient_summary_get). Cada parte vem null sem permissao da tela dela.
library;

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '')?.toLocal();
List<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).cast<Map<String, dynamic>>();

class PatientAppointment {
  const PatientAppointment({
    required this.nrAppointment,
    required this.dhStart,
    required this.dhEnd,
    required this.itStatus,
    this.itOrigin = 1,
    this.vcProfessional,
    this.vcProfessionalColor,
    this.vcProcedure,
    this.vcNotes,
    this.vcWaReply,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> j) =>
      PatientAppointment(
        nrAppointment: _int(j['nr_appointment']),
        dhStart: _date(j['dh_start']) ?? DateTime.now(),
        dhEnd: _date(j['dh_end']) ?? DateTime.now(),
        itStatus: _int(j['it_status'], 1),
        itOrigin: _int(j['it_origin'], 1),
        vcProfessional: j['vc_professional'] as String?,
        vcProfessionalColor: j['vc_professional_color'] as String?,
        vcProcedure: j['vc_procedure'] as String?,
        vcNotes: j['vc_notes'] as String?,
        vcWaReply: j['vc_wa_reply'] as String?,
      );

  final int nrAppointment;
  final DateTime dhStart;
  final DateTime dhEnd;
  final int itStatus;
  final int itOrigin;
  final String? vcProfessional;
  final String? vcProfessionalColor;
  final String? vcProcedure;
  final String? vcNotes;
  final String? vcWaReply;

  bool isUpcoming(DateTime now) => dhStart.isAfter(now);
}

class PatientEntry {
  const PatientEntry({
    required this.nrEntry,
    required this.vcDescription,
    required this.vlAmount,
    this.vlPaid,
    this.dtDue,
    this.dtPaid,
    required this.itStatus,
    this.itPaymentMethod,
    this.nrInstallment,
    this.qtInstallments,
    this.nrReceipt,
    this.vcReceiptNumber,
  });

  factory PatientEntry.fromJson(Map<String, dynamic> j) => PatientEntry(
    nrEntry: _int(j['nr_entry']),
    vcDescription: j['vc_description'] as String? ?? '',
    vlAmount: _num(j['vl_amount']),
    vlPaid: (j['vl_paid'] as num?)?.toDouble(),
    dtDue: DateTime.tryParse(j['dt_due'] as String? ?? ''),
    dtPaid: DateTime.tryParse(j['dt_paid'] as String? ?? ''),
    itStatus: _int(j['it_status'], 1),
    itPaymentMethod: (j['it_payment_method'] as num?)?.toInt(),
    nrInstallment: (j['nr_installment'] as num?)?.toInt(),
    qtInstallments: (j['qt_installments'] as num?)?.toInt(),
    nrReceipt: (j['nr_receipt'] as num?)?.toInt(),
    vcReceiptNumber: j['vc_receipt_number'] as String?,
  );

  final int nrEntry;
  final String vcDescription;
  final double vlAmount;
  final double? vlPaid;
  final DateTime? dtDue;
  final DateTime? dtPaid;

  /// 1 em aberto | 2 pago
  final int itStatus;
  final int? itPaymentMethod;
  final int? nrInstallment;
  final int? qtInstallments;
  final int? nrReceipt;
  final String? vcReceiptNumber;

  bool get isPaid => itStatus == 2;

  /// Descricao com a parcela, sem repetir quando ja vem nela ("(1/2)").
  String get title {
    final n = nrInstallment, q = qtInstallments;
    if (n == null || q == null || q <= 1) return vcDescription;
    final tag = '($n/$q)';
    return vcDescription.contains(tag) ? vcDescription : '$vcDescription $tag';
  }

  bool isOverdue(DateTime today) =>
      itStatus == 1 &&
      dtDue != null &&
      dtDue!.isBefore(DateTime(today.year, today.month, today.day));
}

class PatientReceipt {
  const PatientReceipt({
    required this.nrReceipt,
    required this.vcNumber,
    required this.nrEntry,
    required this.vlAmount,
    this.dtPaid,
    this.vcDescription,
    this.itStatus = 1,
  });

  factory PatientReceipt.fromJson(Map<String, dynamic> j) => PatientReceipt(
    nrReceipt: _int(j['nr_receipt']),
    vcNumber: j['vc_number'] as String? ?? '',
    nrEntry: _int(j['nr_entry']),
    vlAmount: _num(j['vl_amount']),
    dtPaid: DateTime.tryParse(j['dt_paid'] as String? ?? ''),
    vcDescription: j['vc_description'] as String?,
    itStatus: _int(j['it_status'], 1),
  );

  final int nrReceipt;
  final String vcNumber;
  final int nrEntry;
  final double vlAmount;
  final DateTime? dtPaid;
  final String? vcDescription;
  final int itStatus;

  bool get isCancelled => itStatus == 90;
}

class PatientFinance {
  const PatientFinance({
    this.entries = const [],
    this.receipts = const [],
    this.vlOpen = 0,
    this.vlOverdue = 0,
    this.qtOverdue = 0,
    this.vlPaid = 0,
  });

  factory PatientFinance.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? const {};
    return PatientFinance(
      entries: _list(j['entries']).map(PatientEntry.fromJson).toList(),
      receipts: _list(j['receipts']).map(PatientReceipt.fromJson).toList(),
      vlOpen: _num(t['vl_open']),
      vlOverdue: _num(t['vl_overdue']),
      qtOverdue: _int(t['qt_overdue']),
      vlPaid: _num(t['vl_paid']),
    );
  }

  final List<PatientEntry> entries;
  final List<PatientReceipt> receipts;
  final double vlOpen;
  final double vlOverdue;
  final int qtOverdue;
  final double vlPaid;
}

class PlanItem {
  const PlanItem({
    required this.nrItem,
    required this.vcDescription,
    this.vcTooth,
    this.vlTotal = 0,
    this.dtDone,
  });

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    nrItem: _int(j['nr_item']),
    vcDescription: j['vc_description'] as String? ?? '',
    vcTooth: j['vc_tooth'] as String?,
    vlTotal: _num(j['vl_total']),
    dtDone: DateTime.tryParse(j['dt_done'] as String? ?? ''),
  );

  final int nrItem;
  final String vcDescription;
  final String? vcTooth;
  final double vlTotal;
  final DateTime? dtDone;

  bool get isDone => dtDone != null;
}

class TreatmentPlan {
  const TreatmentPlan({
    required this.nrBudget,
    this.vcTitle,
    this.dtBudget,
    this.vcProfessional,
    this.vlTotal = 0,
    this.items = const [],
  });

  factory TreatmentPlan.fromJson(Map<String, dynamic> j) => TreatmentPlan(
    nrBudget: _int(j['nr_budget']),
    vcTitle: j['vc_title'] as String?,
    dtBudget: DateTime.tryParse(j['dt_budget'] as String? ?? ''),
    vcProfessional: j['vc_professional'] as String?,
    vlTotal: _num(j['vl_total']),
    items: _list(j['items']).map(PlanItem.fromJson).toList(),
  );

  final int nrBudget;
  final String? vcTitle;
  final DateTime? dtBudget;
  final String? vcProfessional;
  final double vlTotal;
  final List<PlanItem> items;

  int get qtDone => items.where((i) => i.isDone).length;

  /// 0..1
  double get progress => items.isEmpty ? 0 : qtDone / items.length;
}

class PatientSummary {
  const PatientSummary({
    this.appointments,
    this.finance,
    this.plan,
    this.canAgenda = false,
    this.canFinance = false,
    this.canBudgets = false,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> j) {
    final p = (j['permission'] as Map?) ?? const {};
    return PatientSummary(
      appointments: j['appointments'] == null
          ? null
          : _list(j['appointments']).map(PatientAppointment.fromJson).toList(),
      finance: j['finance'] == null
          ? null
          : PatientFinance.fromJson(
              (j['finance'] as Map).cast<String, dynamic>(),
            ),
      plan: j['plan'] == null
          ? null
          : _list(j['plan']).map(TreatmentPlan.fromJson).toList(),
      canAgenda: p['id_agenda'] as bool? ?? false,
      canFinance: p['id_finance'] as bool? ?? false,
      canBudgets: p['id_budgets'] as bool? ?? false,
    );
  }

  final List<PatientAppointment>? appointments;
  final PatientFinance? finance;
  final List<TreatmentPlan>? plan;
  final bool canAgenda;
  final bool canFinance;
  final bool canBudgets;
}
