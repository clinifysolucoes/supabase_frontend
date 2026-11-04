import '../../../l10n/strings.dart';

/// Receita (a receber) ou despesa (a pagar): od.fin_entry.it_kind e
/// od.fin_category.it_kind.
abstract final class EntryKind {
  static const receivable = 1;
  static const payable = 2;
}

/// Situacao do lancamento (od.fin_entry.it_status).
abstract final class EntryStatus {
  static const open = 1;
  static const paid = 2;
  static const cancelled = 90;

  static String label(int status, {bool overdue = false}) => switch (status) {
    paid => Strings.finStatusPaid,
    cancelled => Strings.finStatusCancelled,
    _ => overdue ? Strings.finStatusOverdue : Strings.finStatusOpen,
  };
}

/// Filtro de situacao da lista (ad.fin_entry_list.vc_status).
enum EntryFilter { all, open, overdue, paid, cancelled }

/// Tipo de custo da despesa (od.fin_category.it_cost_type).
abstract final class CostType {
  static const fixed = 1;
  static const variable = 2;
  static const investment = 3;
  static const other = 4;
  static const all = [fixed, variable, investment, other];

  static String label(int? type) => switch (type) {
    fixed => Strings.costFixed,
    variable => Strings.costVariable,
    investment => Strings.costInvestment,
    other => Strings.costOther,
    _ => '-',
  };
}

/// Forma de pagamento (od.fin_entry.it_payment_method).
abstract final class PaymentMethod {
  static const all = [1, 2, 3, 4, 5, 6, 7, 9];

  static String label(int? method) => switch (method) {
    1 => Strings.payCash,
    2 => Strings.payPix,
    3 => Strings.payCredit,
    4 => Strings.payDebit,
    5 => Strings.payTransfer,
    6 => Strings.payBoleto,
    7 => Strings.payCheck,
    9 => Strings.payOther,
    _ => '-',
  };
}

/// Tipo da conta (od.fin_account.it_type).
abstract final class AccountType {
  static const cash = 1;
  static const bank = 2;
  static const safe = 3;
  static const all = [cash, bank, safe];

  static String label(int type) => switch (type) {
    cash => Strings.accountCash,
    bank => Strings.accountBank,
    safe => Strings.accountSafe,
    _ => '-',
  };
}

class FinAccount {
  const FinAccount({
    required this.nrAccount,
    required this.vcName,
    this.itType = AccountType.cash,
    this.vlOpening = 0,
    this.vlBalance = 0,
    this.itStatus = 1,
  });

  factory FinAccount.fromJson(Map<String, dynamic> j) => FinAccount(
    nrAccount: _int(j['nr_account']),
    vcName: _str(j['vc_name']) ?? '',
    itType: _int(j['it_type'] ?? 1),
    vlOpening: _double(j['vl_opening']),
    vlBalance: _double(j['vl_balance']),
    itStatus: _int(j['it_status'] ?? 1),
  );

  final int nrAccount;
  final String vcName;
  final int itType;
  final double vlOpening;
  final double vlBalance;
  final int itStatus;

  bool get isActive => itStatus == 1;
}

class FinCategory {
  const FinCategory({
    required this.nrCategory,
    required this.vcName,
    required this.itKind,
    this.itCostType,
    this.itStatus = 1,
    this.qtEntries = 0,
  });

  factory FinCategory.fromJson(Map<String, dynamic> j) => FinCategory(
    nrCategory: _int(j['nr_category']),
    vcName: _str(j['vc_name']) ?? '',
    itKind: _int(j['it_kind'] ?? 1),
    itCostType: j['it_cost_type'] == null ? null : _int(j['it_cost_type']),
    itStatus: _int(j['it_status'] ?? 1),
    qtEntries: _int(j['qt_entries'] ?? 0),
  );

  final int nrCategory;
  final String vcName;
  final int itKind;
  final int? itCostType;
  final int itStatus;
  final int qtEntries;

  bool get isActive => itStatus == 1;
}

class FinSupplier {
  const FinSupplier({
    required this.nrSupplier,
    required this.vcName,
    this.vcDocument,
    this.vcPhone,
    this.vcEmail,
    this.vcNotes,
    this.itStatus = 1,
  });

  factory FinSupplier.fromJson(Map<String, dynamic> j) => FinSupplier(
    nrSupplier: _int(j['nr_supplier']),
    vcName: _str(j['vc_name']) ?? '',
    vcDocument: _str(j['vc_document']),
    vcPhone: _str(j['vc_phone']),
    vcEmail: _str(j['vc_email']),
    vcNotes: _str(j['vc_notes']),
    itStatus: _int(j['it_status'] ?? 1),
  );

  final int nrSupplier;
  final String vcName;
  final String? vcDocument;
  final String? vcPhone;
  final String? vcEmail;
  final String? vcNotes;
  final int itStatus;

  bool get isActive => itStatus == 1;
}

/// Permissao do usuario na tela FINANCE.
class FinPermission {
  const FinPermission({
    this.idRead = false,
    this.idCreate = false,
    this.idUpdate = false,
  });

  factory FinPermission.fromJson(Map<String, dynamic> j) => FinPermission(
    idRead: j['id_read'] == true,
    idCreate: j['id_create'] == true,
    idUpdate: j['id_update'] == true,
  );

  final bool idRead;
  final bool idCreate;
  final bool idUpdate;
}

/// Resposta de ad.fin_catalog.
class FinCatalog {
  const FinCatalog({
    this.accounts = const [],
    this.categories = const [],
    this.suppliers = const [],
    this.permission = const FinPermission(),
  });

  factory FinCatalog.fromJson(Map<String, dynamic> j) => FinCatalog(
    accounts: [
      for (final a in _list(j['accounts'])) FinAccount.fromJson(_map(a)),
    ],
    categories: [
      for (final c in _list(j['categories'])) FinCategory.fromJson(_map(c)),
    ],
    suppliers: [
      for (final s in _list(j['suppliers'])) FinSupplier.fromJson(_map(s)),
    ],
    permission: FinPermission.fromJson(_map(j['permission'])),
  );

  final List<FinAccount> accounts;
  final List<FinCategory> categories;
  final List<FinSupplier> suppliers;
  final FinPermission permission;

  List<FinCategory> categoriesOf(int kind) => [
    for (final c in categories)
      if (c.itKind == kind) c,
  ];
}

/// Lancamento (ad.fin_entry_list.entries).
class FinEntry {
  const FinEntry({
    required this.nrEntry,
    required this.itKind,
    required this.nrCategory,
    required this.vcDescription,
    required this.vlAmount,
    required this.dtDue,
    this.vcCategory,
    this.itCostType,
    this.nrAccount,
    this.vcAccount,
    this.nrSupplier,
    this.vcSupplier,
    this.nrPatient,
    this.vcPatient,
    this.dtCompetence,
    this.itPaymentMethod,
    this.dtPaid,
    this.vlPaid,
    this.itStatus = EntryStatus.open,
    this.idOverdue = false,
    this.nrInstallment = 1,
    this.qtInstallments = 1,
    this.idRecurring = false,
    this.vcNotes,
  });

  factory FinEntry.fromJson(Map<String, dynamic> j) => FinEntry(
    nrEntry: _int(j['nr_entry']),
    itKind: _int(j['it_kind'] ?? 1),
    nrCategory: _int(j['nr_category']),
    vcCategory: _str(j['vc_category']),
    itCostType: j['it_cost_type'] == null ? null : _int(j['it_cost_type']),
    nrAccount: j['nr_account'] == null ? null : _int(j['nr_account']),
    vcAccount: _str(j['vc_account']),
    nrSupplier: j['nr_supplier'] == null ? null : _int(j['nr_supplier']),
    vcSupplier: _str(j['vc_supplier']),
    nrPatient: j['nr_patient'] == null ? null : _int(j['nr_patient']),
    vcPatient: _str(j['vc_patient']),
    vcDescription: _str(j['vc_description']) ?? '',
    vlAmount: _double(j['vl_amount']),
    dtDue: _date(j['dt_due']) ?? DateTime(2000),
    dtCompetence: _date(j['dt_competence']),
    itPaymentMethod: j['it_payment_method'] == null
        ? null
        : _int(j['it_payment_method']),
    dtPaid: _date(j['dt_paid']),
    vlPaid: j['vl_paid'] == null ? null : _double(j['vl_paid']),
    itStatus: _int(j['it_status'] ?? 1),
    idOverdue: j['id_overdue'] == true,
    nrInstallment: _int(j['nr_installment'] ?? 1),
    qtInstallments: _int(j['qt_installments'] ?? 1),
    idRecurring: j['id_recurring'] == true,
    vcNotes: _str(j['vc_notes']),
  );

  final int nrEntry;
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
  final DateTime dtDue;
  final DateTime? dtCompetence;
  final int? itPaymentMethod;
  final DateTime? dtPaid;
  final double? vlPaid;
  final int itStatus;
  final bool idOverdue;
  final int nrInstallment;
  final int qtInstallments;
  final bool idRecurring;
  final String? vcNotes;

  bool get isOpen => itStatus == EntryStatus.open;
  bool get isPaid => itStatus == EntryStatus.paid;
  bool get isCancelled => itStatus == EntryStatus.cancelled;
  bool get isGrouped => qtInstallments > 1;

  /// Fornecedor (a pagar) ou paciente (a receber).
  String? get counterpart => vcSupplier ?? vcPatient;
}

class FinTotals {
  const FinTotals({
    this.vlOpen = 0,
    this.vlOverdue = 0,
    this.vlPaid = 0,
    this.vlCancelled = 0,
    this.qtTotal = 0,
    this.byCostType = const {},
  });

  factory FinTotals.fromJson(Map<String, dynamic> j) => FinTotals(
    vlOpen: _double(j['vl_open']),
    vlOverdue: _double(j['vl_overdue']),
    vlPaid: _double(j['vl_paid']),
    vlCancelled: _double(j['vl_cancelled']),
    qtTotal: _int(j['qt_total'] ?? 0),
    byCostType: {
      for (final e in _map(j['by_cost_type']).entries)
        int.tryParse(e.key) ?? 0: _double(e.value),
    },
  );

  final double vlOpen;
  final double vlOverdue;
  final double vlPaid;
  final double vlCancelled;
  final int qtTotal;
  final Map<int, double> byCostType;
}

/// Resposta de ad.fin_entry_list.
class FinEntryList {
  const FinEntryList({
    this.entries = const [],
    this.totals = const FinTotals(),
  });

  factory FinEntryList.fromJson(Map<String, dynamic> j) => FinEntryList(
    entries: [for (final e in _list(j['entries'])) FinEntry.fromJson(_map(e))],
    totals: FinTotals.fromJson(_map(j['totals'])),
  );

  final List<FinEntry> entries;
  final FinTotals totals;
}

/// Resposta de ad.fin_overview.
class FinOverview {
  const FinOverview({
    this.idConfigured = false,
    this.vlBalance = 0,
    this.accounts = const [],
    this.todayReceivable = 0,
    this.todayPayable = 0,
    this.overdueReceivable = 0,
    this.overdueReceivableQt = 0,
    this.overduePayable = 0,
    this.overduePayableQt = 0,
    this.monthReceived = 0,
    this.monthPaid = 0,
    this.monthToReceive = 0,
    this.monthToPay = 0,
    this.next = const [],
    this.permission = const FinPermission(),
  });

  factory FinOverview.fromJson(Map<String, dynamic> j) {
    final today = _map(j['today']);
    final overdue = _map(j['overdue']);
    final month = _map(j['month']);
    return FinOverview(
      idConfigured: j['id_configured'] == true,
      vlBalance: _double(j['vl_balance']),
      accounts: [
        for (final a in _list(j['accounts'])) FinAccount.fromJson(_map(a)),
      ],
      todayReceivable: _double(today['vl_receivable']),
      todayPayable: _double(today['vl_payable']),
      overdueReceivable: _double(overdue['vl_receivable']),
      overdueReceivableQt: _int(overdue['qt_receivable'] ?? 0),
      overduePayable: _double(overdue['vl_payable']),
      overduePayableQt: _int(overdue['qt_payable'] ?? 0),
      monthReceived: _double(month['vl_received']),
      monthPaid: _double(month['vl_paid']),
      monthToReceive: _double(month['vl_to_receive']),
      monthToPay: _double(month['vl_to_pay']),
      next: [for (final e in _list(j['next'])) FinEntry.fromJson(_map(e))],
      permission: FinPermission.fromJson(_map(j['permission'])),
    );
  }

  final bool idConfigured;
  final double vlBalance;
  final List<FinAccount> accounts;
  final double todayReceivable;
  final double todayPayable;
  final double overdueReceivable;
  final int overdueReceivableQt;
  final double overduePayable;
  final int overduePayableQt;
  final double monthReceived;
  final double monthPaid;
  final double monthToReceive;
  final double monthToPay;
  final List<FinEntry> next;
  final FinPermission permission;
}

/// Um dia do fluxo de caixa (ad.fin_cashflow.days).
class CashflowDay {
  const CashflowDay({
    required this.day,
    this.vlIn = 0,
    this.vlOut = 0,
    this.vlInPlanned = 0,
    this.vlOutPlanned = 0,
    this.vlBalance = 0,
    this.vlProjected = 0,
  });

  factory CashflowDay.fromJson(Map<String, dynamic> j) => CashflowDay(
    day: _date(j['dt']) ?? DateTime(2000),
    vlIn: _double(j['vl_in']),
    vlOut: _double(j['vl_out']),
    vlInPlanned: _double(j['vl_in_planned']),
    vlOutPlanned: _double(j['vl_out_planned']),
    vlBalance: _double(j['vl_balance']),
    vlProjected: _double(j['vl_projected']),
  );

  final DateTime day;
  final double vlIn;
  final double vlOut;
  final double vlInPlanned;
  final double vlOutPlanned;
  final double vlBalance;
  final double vlProjected;

  bool get hasMovement =>
      vlIn != 0 || vlOut != 0 || vlInPlanned != 0 || vlOutPlanned != 0;
}

class Cashflow {
  const Cashflow({
    this.vlOpening = 0,
    this.days = const [],
    this.vlIn = 0,
    this.vlOut = 0,
    this.vlInPlanned = 0,
    this.vlOutPlanned = 0,
  });

  factory Cashflow.fromJson(Map<String, dynamic> j) {
    final t = _map(j['totals']);
    return Cashflow(
      vlOpening: _double(j['vl_opening']),
      days: [for (final d in _list(j['days'])) CashflowDay.fromJson(_map(d))],
      vlIn: _double(t['vl_in']),
      vlOut: _double(t['vl_out']),
      vlInPlanned: _double(t['vl_in_planned']),
      vlOutPlanned: _double(t['vl_out_planned']),
    );
  }

  final double vlOpening;
  final List<CashflowDay> days;
  final double vlIn;
  final double vlOut;
  final double vlInPlanned;
  final double vlOutPlanned;
}

/// Movimento do extrato (ad.fin_statement.movements).
class StatementLine {
  const StatementLine({
    required this.nrEntry,
    required this.dtPaid,
    required this.itKind,
    required this.vcDescription,
    required this.vlValue,
    required this.vlBalance,
    this.vcCategory,
    this.vcAccount,
    this.itPaymentMethod,
  });

  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
    nrEntry: _int(j['nr_entry']),
    dtPaid: _date(j['dt_paid']) ?? DateTime(2000),
    itKind: _int(j['it_kind'] ?? 1),
    vcDescription: _str(j['vc_description']) ?? '',
    vcCategory: _str(j['vc_category']),
    vcAccount: _str(j['vc_account']),
    itPaymentMethod: j['it_payment_method'] == null
        ? null
        : _int(j['it_payment_method']),
    vlValue: _double(j['vl_value']),
    vlBalance: _double(j['vl_balance']),
  );

  final int nrEntry;
  final DateTime dtPaid;
  final int itKind;
  final String vcDescription;
  final String? vcCategory;
  final String? vcAccount;
  final int? itPaymentMethod;
  final double vlValue;
  final double vlBalance;
}

class Statement {
  const Statement({
    this.vlStart = 0,
    this.vlEnd = 0,
    this.vlIn = 0,
    this.vlOut = 0,
    this.lines = const [],
  });

  factory Statement.fromJson(Map<String, dynamic> j) => Statement(
    vlStart: _double(j['vl_start']),
    vlEnd: _double(j['vl_end']),
    vlIn: _double(j['vl_in']),
    vlOut: _double(j['vl_out']),
    lines: [
      for (final m in _list(j['movements'])) StatementLine.fromJson(_map(m)),
    ],
  );

  final double vlStart;
  final double vlEnd;
  final double vlIn;
  final double vlOut;
  final List<StatementLine> lines;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

String? _str(dynamic v) => v?.toString();

/// `yyyy-MM-dd` -> data local (sem fuso).
DateTime? _date(dynamic v) {
  final p = DateTime.tryParse(v?.toString() ?? '');
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

List<dynamic> _list(dynamic v) => v is List ? v : const [];
