import '../../../l10n/strings.dart';
import 'finance_models.dart';

/// Tipo do movimento entre contas (od.fin_transfer.it_type).
abstract final class TransferType {
  static const transfer = 1;
  static const withdrawal = 2; // sangria: sai do caixa
  static const supply = 3; // suprimento: entra no caixa

  static String label(int type) => switch (type) {
    withdrawal => Strings.cashWithdrawal,
    supply => Strings.cashSupply,
    _ => Strings.cashTransfer,
  };
}

/// Sessao de caixa com o resumo (ad.fin_cash_status).
class CashSession {
  const CashSession({
    required this.nrSession,
    required this.nrAccount,
    required this.vcAccount,
    required this.vcUser,
    required this.dhOpen,
    this.nrUser,
    this.dhClose,
    this.itStatus = 1,
    this.vlOpen = 0,
    this.vlIn = 0,
    this.vlOut = 0,
    this.vlTransferIn = 0,
    this.vlTransferOut = 0,
    this.byMethod = const {},
    this.vlExpected = 0,
    this.vlCounted,
    this.vlDifference,
    this.vcNotes,
  });

  factory CashSession.fromJson(Map<String, dynamic> j) => CashSession(
    nrSession: _int(j['nr_session']),
    nrAccount: _int(j['nr_account']),
    vcAccount: j['vc_account']?.toString() ?? '',
    nrUser: j['nr_user'] == null ? null : _int(j['nr_user']),
    vcUser: j['vc_user']?.toString() ?? '',
    dhOpen: _time(j['dh_open']) ?? DateTime(2000),
    dhClose: _time(j['dh_close']),
    itStatus: _int(j['it_status'] ?? 1),
    vlOpen: _double(j['vl_open']),
    vlIn: _double(j['vl_in']),
    vlOut: _double(j['vl_out']),
    vlTransferIn: _double(j['vl_transfer_in']),
    vlTransferOut: _double(j['vl_transfer_out']),
    byMethod: {
      if (j['by_method'] is Map)
        for (final e in (j['by_method'] as Map).entries)
          int.tryParse(e.key.toString()) ?? 0: _double(e.value),
    },
    vlExpected: _double(j['vl_expected']),
    vlCounted: j['vl_counted'] == null ? null : _double(j['vl_counted']),
    vlDifference: j['vl_difference'] == null
        ? null
        : _double(j['vl_difference']),
    vcNotes: j['vc_notes']?.toString(),
  );

  final int nrSession;
  final int nrAccount;
  final String vcAccount;
  final int? nrUser;
  final String vcUser;
  final DateTime dhOpen;
  final DateTime? dhClose;
  final int itStatus;
  final double vlOpen;
  final double vlIn;
  final double vlOut;
  final double vlTransferIn;
  final double vlTransferOut;

  /// Entradas por forma de pagamento (0 = sem forma informada).
  final Map<int, double> byMethod;
  final double vlExpected;
  final double? vlCounted;
  final double? vlDifference;
  final String? vcNotes;

  bool get isOpen => itStatus == 1;
}

/// Conta do tipo caixa e quem esta com ela.
class CashAccount {
  const CashAccount({
    required this.nrAccount,
    required this.vcName,
    this.vlBalance = 0,
    this.nrSession,
    this.vcUser,
  });

  factory CashAccount.fromJson(Map<String, dynamic> j) => CashAccount(
    nrAccount: _int(j['nr_account']),
    vcName: j['vc_name']?.toString() ?? '',
    vlBalance: _double(j['vl_balance']),
    nrSession: j['nr_session'] == null ? null : _int(j['nr_session']),
    vcUser: j['vc_user']?.toString(),
  );

  final int nrAccount;
  final String vcName;
  final double vlBalance;
  final int? nrSession;
  final String? vcUser;

  bool get isFree => nrSession == null;
}

/// Resposta de ad.fin_cash_status.
class CashStatus {
  const CashStatus({
    this.mine,
    this.accounts = const [],
    this.sessions = const [],
    this.permission = const FinPermission(),
    this.idEnabled = true,
  });

  factory CashStatus.fromJson(Map<String, dynamic> j) => CashStatus(
    mine: j['mine'] is Map
        ? CashSession.fromJson((j['mine'] as Map).cast<String, dynamic>())
        : null,
    accounts: [
      for (final a in (j['accounts'] as List? ?? const []))
        CashAccount.fromJson((a as Map).cast<String, dynamic>()),
    ],
    sessions: [
      for (final s in (j['sessions'] as List? ?? const []))
        CashSession.fromJson((s as Map).cast<String, dynamic>()),
    ],
    permission: j['permission'] is Map
        ? FinPermission.fromJson(
            (j['permission'] as Map).cast<String, dynamic>(),
          )
        : const FinPermission(),
    idEnabled: j['id_enabled'] != false,
  );

  final CashSession? mine;
  final List<CashAccount> accounts;
  final List<CashSession> sessions;
  final FinPermission permission;

  /// Caixa do dia ligado nas configuracoes da filial.
  final bool idEnabled;
}

/// Lancamento ja gerado por um atendimento (ad.appointment_checkout_get).
class CheckoutEntry {
  const CheckoutEntry({
    required this.nrEntry,
    required this.itKind,
    required this.vcDescription,
    required this.vlAmount,
    required this.dtDue,
    this.itStatus = EntryStatus.open,
    this.dtPaid,
  });

  factory CheckoutEntry.fromJson(Map<String, dynamic> j) => CheckoutEntry(
    nrEntry: _int(j['nr_entry']),
    itKind: _int(j['it_kind'] ?? 1),
    vcDescription: j['vc_description']?.toString() ?? '',
    vlAmount: _double(j['vl_amount']),
    dtDue: _date(j['dt_due']) ?? DateTime(2000),
    itStatus: _int(j['it_status'] ?? 1),
    dtPaid: _date(j['dt_paid']),
  );

  final int nrEntry;
  final int itKind;
  final String vcDescription;
  final double vlAmount;
  final DateTime dtDue;
  final int itStatus;
  final DateTime? dtPaid;
}

/// Dados para fechar uma consulta (ad.appointment_checkout_get).
class CheckoutData {
  const CheckoutData({
    required this.nrAppointment,
    this.vcPatient,
    this.vcProfessional,
    this.nrProfessional,
    this.vcProcedure,
    this.vlPrice,
    this.pcCommission = 0,
    this.idDone = false,
    this.idConfigured = true,
    this.entries = const [],
    this.nrCategory,
    this.categories = const [],
    this.accounts = const [],
    this.nrSessionAccount,
  });

  factory CheckoutData.fromJson(Map<String, dynamic> j) {
    final a = (j['appointment'] as Map? ?? const {}).cast<String, dynamic>();
    return CheckoutData(
      nrAppointment: _int(a['nr_appointment']),
      vcPatient: a['vc_patient']?.toString(),
      vcProfessional: a['vc_professional']?.toString(),
      nrProfessional: a['nr_professional'] == null
          ? null
          : _int(a['nr_professional']),
      vcProcedure: a['vc_procedure']?.toString(),
      vlPrice: a['vl_price'] == null ? null : _double(a['vl_price']),
      pcCommission: _double(a['pc_commission']),
      idDone: j['id_done'] == true,
      idConfigured: j['id_configured'] != false,
      entries: [
        for (final e in (j['entries'] as List? ?? const []))
          CheckoutEntry.fromJson((e as Map).cast<String, dynamic>()),
      ],
      nrCategory: j['nr_category'] == null ? null : _int(j['nr_category']),
      categories: [
        for (final c in (j['categories'] as List? ?? const []))
          (
            nr: _int((c as Map)['nr_category']),
            name: c['vc_name']?.toString() ?? '',
          ),
      ],
      accounts: [
        for (final c in (j['accounts'] as List? ?? const []))
          FinAccount.fromJson((c as Map).cast<String, dynamic>()),
      ],
      nrSessionAccount: j['nr_session_account'] == null
          ? null
          : _int(j['nr_session_account']),
    );
  }

  final int nrAppointment;
  final String? vcPatient;
  final String? vcProfessional;
  final int? nrProfessional;
  final String? vcProcedure;

  /// Valor cobrado hoje (precificacao); null se nao houver.
  final double? vlPrice;

  /// Comissao efetiva: do procedimento ou o padrao da filial (pontos, 10 = 10%).
  final double pcCommission;
  final bool idDone;
  final bool idConfigured;
  final List<CheckoutEntry> entries;
  final int? nrCategory;
  final List<({int nr, String name})> categories;
  final List<FinAccount> accounts;

  /// Conta do caixa aberto do usuario (sugestao para receber agora).
  final int? nrSessionAccount;
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

DateTime? _time(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();
