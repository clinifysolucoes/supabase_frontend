import '../../../l10n/strings.dart';
import '../../finance/domain/receipt_models.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int? _i(Object? v) => (v as num?)?.toInt();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');
String? _s(Object? v) {
  final t = v?.toString();
  return t == null || t.isEmpty ? null : t;
}

/// Situacao do orcamento (od.budget.it_status).
abstract final class BudgetStatus {
  static const open = 1;
  static const pending = 2;
  static const accepted = 3;
  static const refused = 4;
  static const cancelled = 90;

  static String label(int s) => switch (s) {
    open => Strings.budgetOpen,
    pending => Strings.budgetPending,
    accepted => Strings.budgetAccepted,
    refused => Strings.budgetRefused,
    cancelled => Strings.budgetCancelled,
    _ => '-',
  };
}

/// Filtro da lista (vc_status de ad.budget_list).
enum BudgetFilter {
  all('all'),
  open('open'),
  pending('pending'),
  accepted('accepted'),
  refused('refused'),
  cancelled('cancelled'),
  expired('expired');

  const BudgetFilter(this.code);
  final String code;

  String get label => switch (this) {
    all => Strings.budgetAll,
    open => Strings.budgetOpen,
    pending => Strings.budgetPending,
    accepted => Strings.budgetAcceptedShort,
    refused => Strings.budgetRefused,
    cancelled => Strings.budgetCancelled,
    expired => Strings.budgetExpired,
  };
}

/// Linha da lista de orcamentos.
class BudgetSummary {
  const BudgetSummary({
    required this.nrBudget,
    required this.nrPatient,
    this.vcPatient = '',
    this.vcProfessional,
    this.vcTitle,
    required this.dtBudget,
    required this.dtValid,
    this.idExpired = false,
    this.vlGross = 0,
    this.vlDiscount = 0,
    this.vlTotal = 0,
    this.itStatus = BudgetStatus.open,
    this.qtItems = 0,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
    nrBudget: _i(j['nr_budget'])!,
    nrPatient: _i(j['nr_patient'])!,
    vcPatient: _s(j['vc_patient']) ?? '',
    vcProfessional: _s(j['vc_professional']),
    vcTitle: _s(j['vc_title']),
    dtBudget: _date(j['dt_budget']) ?? DateTime(2000),
    dtValid: _date(j['dt_valid']) ?? DateTime(2000),
    idExpired: j['id_expired'] == true,
    vlGross: _d(j['vl_gross']),
    vlDiscount: _d(j['vl_discount']),
    vlTotal: _d(j['vl_total']),
    itStatus: _i(j['it_status']) ?? BudgetStatus.open,
    qtItems: _i(j['qt_items']) ?? 0,
  );

  final int nrBudget;
  final int nrPatient;
  final String vcPatient;
  final String? vcProfessional;
  final String? vcTitle;
  final DateTime dtBudget;
  final DateTime dtValid;
  final bool idExpired;
  final double vlGross;
  final double vlDiscount;
  final double vlTotal;
  final int itStatus;
  final int qtItems;

  String get title => vcTitle ?? Strings.budgetNumber(nrBudget);
}

class BudgetListData {
  const BudgetListData({
    this.budgets = const [],
    this.qtOpen = 0,
    this.qtPending = 0,
    this.qtAccepted = 0,
    this.vlOpen = 0,
    this.vlAccepted = 0,
    this.pcMaxDiscount = 10,
  });

  factory BudgetListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BudgetListData(
      budgets: [
        for (final b in (j['budgets'] as List? ?? const []))
          BudgetSummary.fromJson((b as Map).cast<String, dynamic>()),
      ],
      qtOpen: _i(t['qt_open']) ?? 0,
      qtPending: _i(t['qt_pending']) ?? 0,
      qtAccepted: _i(t['qt_accepted']) ?? 0,
      vlOpen: _d(t['vl_open']),
      vlAccepted: _d(t['vl_accepted']),
      pcMaxDiscount: (j['pc_max_discount'] as num?)?.toDouble() ?? 10,
    );
  }

  final List<BudgetSummary> budgets;
  final int qtOpen;
  final int qtPending;
  final int qtAccepted;
  final double vlOpen;
  final double vlAccepted;
  final double pcMaxDiscount;
}

/// Item do orcamento.
class BudgetItem {
  const BudgetItem({
    this.nrProcedure,
    required this.vcDescription,
    this.vcTooth,
    this.qtQuantity = 1,
    this.vlUnit = 0,
  });

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
    nrProcedure: _i(j['nr_procedure']),
    vcDescription: _s(j['vc_description']) ?? '',
    vcTooth: _s(j['vc_tooth']),
    qtQuantity: _d(j['qt_quantity']),
    vlUnit: _d(j['vl_unit']),
  );

  final int? nrProcedure;
  final String vcDescription;
  final String? vcTooth;
  final double qtQuantity;
  final double vlUnit;

  double get vlTotal => (qtQuantity * vlUnit * 100).roundToDouble() / 100;

  BudgetItem copyWith({
    String? vcDescription,
    String? vcTooth,
    double? qtQuantity,
    double? vlUnit,
  }) => BudgetItem(
    nrProcedure: nrProcedure,
    vcDescription: vcDescription ?? this.vcDescription,
    vcTooth: vcTooth ?? this.vcTooth,
    qtQuantity: qtQuantity ?? this.qtQuantity,
    vlUnit: vlUnit ?? this.vlUnit,
  );

  Map<String, dynamic> toJson() => {
    'nr_procedure': ?nrProcedure,
    'vc_description': vcDescription,
    'vc_tooth': vcTooth,
    'qt_quantity': qtQuantity,
    'vl_unit': vlUnit,
  };
}

/// Conta a receber gerada pelo orcamento aprovado.
class BudgetEntry {
  const BudgetEntry({
    required this.nrEntry,
    this.vcDescription = '',
    this.vlAmount = 0,
    required this.dtDue,
    this.itStatus = 1,
  });

  factory BudgetEntry.fromJson(Map<String, dynamic> j) => BudgetEntry(
    nrEntry: _i(j['nr_entry'])!,
    vcDescription: _s(j['vc_description']) ?? '',
    vlAmount: _d(j['vl_amount']),
    dtDue: _date(j['dt_due']) ?? DateTime(2000),
    itStatus: _i(j['it_status']) ?? 1,
  );

  final int nrEntry;
  final String vcDescription;
  final double vlAmount;
  final DateTime dtDue;
  final int itStatus;
}

/// Orcamento completo (ad.budget_get).
class Budget {
  const Budget({
    required this.nrBudget,
    required this.nrPatient,
    this.vcPatient = '',
    this.vcPatientCpf,
    this.vcPatientMobile,
    this.nrProfessional,
    this.vcProfessional,
    this.vcTitle,
    required this.dtBudget,
    required this.dtValid,
    this.idExpired = false,
    this.vlGross = 0,
    this.vlDiscount = 0,
    this.pcDiscount = 0,
    this.vlTotal = 0,
    this.qtInstallments,
    this.itPaymentMethod,
    this.vcNotes,
    this.itStatus = BudgetStatus.open,
    this.idDiscountApproved = false,
    this.vcUserDiscount,
    this.items = const [],
    this.entries = const [],
    this.issuer = const ReceiptIssuer(),
    this.pcMaxDiscount = 10,
    this.canUpdate = false,
    this.canApproveDiscount = false,
  });

  factory Budget.fromJson(Map<String, dynamic> j) {
    final b = (j['budget'] as Map).cast<String, dynamic>();
    final p = (j['permission'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Budget(
      nrBudget: _i(b['nr_budget'])!,
      nrPatient: _i(b['nr_patient'])!,
      vcPatient: _s(b['vc_patient']) ?? '',
      vcPatientCpf: _s(b['vc_patient_cpf']),
      vcPatientMobile: _s(b['vc_patient_mobile']),
      nrProfessional: _i(b['nr_professional']),
      vcProfessional: _s(b['vc_professional']),
      vcTitle: _s(b['vc_title']),
      dtBudget: _date(b['dt_budget']) ?? DateTime(2000),
      dtValid: _date(b['dt_valid']) ?? DateTime(2000),
      idExpired: b['id_expired'] == true,
      vlGross: _d(b['vl_gross']),
      vlDiscount: _d(b['vl_discount']),
      pcDiscount: _d(b['pc_discount']),
      vlTotal: _d(b['vl_total']),
      qtInstallments: _i(b['qt_installments']),
      itPaymentMethod: _i(b['it_payment_method']),
      vcNotes: _s(b['vc_notes']),
      itStatus: _i(b['it_status']) ?? BudgetStatus.open,
      idDiscountApproved: b['id_discount_approved'] == true,
      vcUserDiscount: _s(b['vc_user_discount']),
      items: [
        for (final i in (j['items'] as List? ?? const []))
          BudgetItem.fromJson((i as Map).cast<String, dynamic>()),
      ],
      entries: [
        for (final e in (j['entries'] as List? ?? const []))
          BudgetEntry.fromJson((e as Map).cast<String, dynamic>()),
      ],
      issuer: ReceiptIssuer.fromJson(
        (j['issuer'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      pcMaxDiscount: (j['pc_max_discount'] as num?)?.toDouble() ?? 10,
      canUpdate: p['id_update'] == true,
      canApproveDiscount: p['id_approve_discount'] == true,
    );
  }

  final int nrBudget;
  final int nrPatient;
  final String vcPatient;
  final String? vcPatientCpf;
  final String? vcPatientMobile;
  final int? nrProfessional;
  final String? vcProfessional;
  final String? vcTitle;
  final DateTime dtBudget;
  final DateTime dtValid;
  final bool idExpired;
  final double vlGross;
  final double vlDiscount;
  final double pcDiscount;
  final double vlTotal;
  final int? qtInstallments;
  final int? itPaymentMethod;
  final String? vcNotes;
  final int itStatus;
  final bool idDiscountApproved;
  final String? vcUserDiscount;
  final List<BudgetItem> items;
  final List<BudgetEntry> entries;
  final ReceiptIssuer issuer;
  final double pcMaxDiscount;
  final bool canUpdate;
  final bool canApproveDiscount;

  String get title => vcTitle ?? Strings.budgetNumber(nrBudget);
  bool get isEditable =>
      itStatus == BudgetStatus.open || itStatus == BudgetStatus.pending;
}
