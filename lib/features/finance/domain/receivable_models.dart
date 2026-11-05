import 'dart:convert';
import 'dart:typed_data';

import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';

/// Formas de pagamento que podem ter taxa e gerar recebiveis.
abstract final class RateMethod {
  static const all = [3, 4, 6, 7];

  /// So o credito parcela.
  static bool installments(int method) => method == 3;
}

/// Taxa de recebimento (od.fin_card_rate, em ad.fin_catalog.rates).
class FinRate {
  const FinRate({
    required this.nrRate,
    required this.vcName,
    required this.itPaymentMethod,
    required this.nrAccount,
    this.qtInstallmentsMin = 1,
    this.qtInstallmentsMax = 1,
    this.pcFee = 0,
    this.vlFeeFixed = 0,
    this.qtDays = 30,
    this.itStatus = 1,
  });

  factory FinRate.fromJson(Map<String, dynamic> j) => FinRate(
    nrRate: _int(j['nr_rate']),
    vcName: j['vc_name']?.toString() ?? '',
    itPaymentMethod: _int(j['it_payment_method'] ?? 3),
    nrAccount: _int(j['nr_account']),
    qtInstallmentsMin: _int(j['qt_installments_min'] ?? 1),
    qtInstallmentsMax: _int(j['qt_installments_max'] ?? 1),
    pcFee: _double(j['pc_fee']),
    vlFeeFixed: _double(j['vl_fee_fixed']),
    qtDays: _int(j['qt_days'] ?? 30),
    itStatus: _int(j['it_status'] ?? 1),
  );

  final int nrRate;
  final String vcName;
  final int itPaymentMethod;
  final int nrAccount;
  final int qtInstallmentsMin;
  final int qtInstallmentsMax;
  final double pcFee;
  final double vlFeeFixed;
  final int qtDays;
  final int itStatus;

  bool get isActive => itStatus == 1;
}

/// Situacao do recebivel (od.fin_receivable.it_status).
abstract final class ReceivableStatus {
  static const pending = 1;
  static const received = 2;
  static const cancelled = 90;

  static String label(int status, {bool overdue = false}) => switch (status) {
    received => Strings.recvStatusReceived,
    cancelled => Strings.finStatusCancelled,
    _ => overdue ? Strings.finStatusOverdue : Strings.recvStatusPending,
  };
}

/// Filtro da lista (ad.fin_receivable_list.vc_status).
enum ReceivableFilter { all, pending, overdue, received, cancelled }

class Receivable {
  const Receivable({
    required this.nrReceivable,
    required this.nrEntry,
    required this.itPaymentMethod,
    required this.vlGross,
    required this.vlNet,
    required this.dtExpected,
    required this.nrAccount,
    this.vcDescription = '',
    this.vcPatient,
    this.vcRate,
    this.nrInstallment = 1,
    this.qtInstallments = 1,
    this.vlFee = 0,
    this.vcAccount,
    this.itStatus = ReceivableStatus.pending,
    this.idOverdue = false,
    this.dtReceived,
    this.vlReceived,
    this.vcReference,
    this.vcCardBrand,
    this.vcCardLast4,
    this.vcAuthorization,
    this.vcHolderName,
    this.vcBankName,
    this.vcCheckNumber,
  });

  factory Receivable.fromJson(Map<String, dynamic> j) => Receivable(
    nrReceivable: _int(j['nr_receivable']),
    nrEntry: _int(j['nr_entry']),
    vcDescription: j['vc_description']?.toString() ?? '',
    vcPatient: j['vc_patient']?.toString(),
    itPaymentMethod: _int(j['it_payment_method'] ?? 3),
    vcRate: j['vc_rate']?.toString(),
    nrInstallment: _int(j['nr_installment'] ?? 1),
    qtInstallments: _int(j['qt_installments'] ?? 1),
    vlGross: _double(j['vl_gross']),
    vlFee: _double(j['vl_fee']),
    vlNet: _double(j['vl_net']),
    dtExpected: _date(j['dt_expected']) ?? DateTime(2000),
    nrAccount: _int(j['nr_account']),
    vcAccount: j['vc_account']?.toString(),
    itStatus: _int(j['it_status'] ?? 1),
    idOverdue: j['id_overdue'] == true,
    dtReceived: _date(j['dt_received']),
    vlReceived: j['vl_received'] == null ? null : _double(j['vl_received']),
    vcReference: j['vc_reference']?.toString(),
    vcCardBrand: j['vc_card_brand']?.toString(),
    vcCardLast4: j['vc_card_last4']?.toString(),
    vcAuthorization: j['vc_authorization']?.toString(),
    vcHolderName: j['vc_holder_name']?.toString(),
    vcBankName: j['vc_bank_name']?.toString(),
    vcCheckNumber: j['vc_check_number']?.toString(),
  );

  final int nrReceivable;
  final int nrEntry;
  final String vcDescription;
  final String? vcPatient;
  final int itPaymentMethod;
  final String? vcRate;
  final int nrInstallment;
  final int qtInstallments;
  final double vlGross;
  final double vlFee;
  final double vlNet;
  final DateTime dtExpected;
  final int nrAccount;
  final String? vcAccount;
  final int itStatus;
  final bool idOverdue;
  final DateTime? dtReceived;
  final double? vlReceived;
  final String? vcReference;
  final String? vcCardBrand;
  final String? vcCardLast4;
  final String? vcAuthorization;
  final String? vcHolderName;
  final String? vcBankName;
  final String? vcCheckNumber;

  /// "Visa •••• 4321 · Aut. A1B2" ou "Cheque 123 · Banco X" (vazio sem dados).
  String get paymentSummary => [
    if (vcCardBrand != null || vcCardLast4 != null)
      [?vcCardBrand, if (vcCardLast4 != null) '•••• $vcCardLast4'].join(' '),
    if (vcAuthorization != null) '${Strings.cardAuthShort} $vcAuthorization',
    if (vcCheckNumber != null) '${Strings.checkShort} $vcCheckNumber',
    ?vcBankName,
    ?vcHolderName,
  ].join(' · ');

  bool get isPending => itStatus == ReceivableStatus.pending;
  bool get isReceived => itStatus == ReceivableStatus.received;
}

class ReceivableList {
  const ReceivableList({
    this.items = const [],
    this.vlGross = 0,
    this.vlFee = 0,
    this.vlNet = 0,
    this.vlPending = 0,
    this.vlReceived = 0,
  });

  factory ReceivableList.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map? ?? const {}).cast<String, dynamic>();
    return ReceivableList(
      items: [
        for (final r in (j['receivables'] as List? ?? const []))
          Receivable.fromJson((r as Map).cast<String, dynamic>()),
      ],
      vlGross: _double(t['vl_gross']),
      vlFee: _double(t['vl_fee']),
      vlNet: _double(t['vl_net']),
      vlPending: _double(t['vl_pending']),
      vlReceived: _double(t['vl_received']),
    );
  }

  final List<Receivable> items;
  final double vlGross;
  final double vlFee;
  final double vlNet;
  final double vlPending;
  final double vlReceived;
}

/// Linha de ad.fin_health_export (um pagamento de paciente).
class HealthRow {
  const HealthRow({
    this.nrEntry = 0,
    this.dhExported,
    required this.dtPaid,
    required this.vlPaid,
    required this.vcPatient,
    this.vcCpf,
    this.vcPayer,
    this.vcPayerCpf,
    this.vcProfessional,
    this.vcDescription,
  });

  factory HealthRow.fromJson(Map<String, dynamic> j) => HealthRow(
    nrEntry: _int(j['nr_entry'] ?? 0),
    dhExported: DateTime.tryParse(
      j['dh_exported']?.toString() ?? '',
    )?.toLocal(),
    dtPaid: _date(j['dt_paid']) ?? DateTime(2000),
    vlPaid: _double(j['vl_paid']),
    vcPatient: j['vc_patient']?.toString() ?? '',
    vcCpf: j['vc_cpf']?.toString(),
    vcPayer: j['vc_payer']?.toString(),
    vcPayerCpf: j['vc_payer_cpf']?.toString(),
    vcProfessional: j['vc_professional']?.toString(),
    vcDescription: j['vc_description']?.toString(),
  );

  final int nrEntry;

  /// Quando foi exportado para a Receita Saude (null = ainda nao).
  final DateTime? dhExported;
  final DateTime dtPaid;
  final double vlPaid;
  final String vcPatient;
  final String? vcCpf;

  /// Responsavel legal (quem paga), quando houver.
  final String? vcPayer;
  final String? vcPayerCpf;
  final String? vcProfessional;
  final String? vcDescription;
}

class HealthExport {
  const HealthExport({
    this.rows = const [],
    this.vlTotal = 0,
    this.qtMissingCpf = 0,
    this.vcCompanyDocument,
  });

  factory HealthExport.fromJson(Map<String, dynamic> j) => HealthExport(
    rows: [
      for (final r in (j['rows'] as List? ?? const []))
        HealthRow.fromJson((r as Map).cast<String, dynamic>()),
    ],
    vlTotal: _double(j['vl_total']),
    qtMissingCpf: _int(j['qt_missing_cpf'] ?? 0),
    vcCompanyDocument: j['vc_company_document']?.toString(),
  );

  final List<HealthRow> rows;
  final double vlTotal;
  final int qtMissingCpf;
  final String? vcCompanyDocument;

  /// CSV (`;`, decimal com virgula, UTF-8 com BOM para o Excel abrir os
  /// acentos): pagador e CPF, beneficiario (paciente) e CPF, data, valor,
  /// profissional e descricao.
  Uint8List toCsv() {
    String cell(String? v) {
      final s = (v ?? '').replaceAll('"', '""');
      return s.contains(';') || s.contains('"') || s.contains('\n')
          ? '"$s"'
          : s;
    }

    String cpf(String? v) =>
        v == null || v.isEmpty ? '' : Masks.format(MaskType.cpf, v);
    final b = StringBuffer()
      ..writeln(
        [
          Strings.healthColPayerCpf,
          Strings.healthColPayer,
          Strings.healthColPatientCpf,
          Strings.healthColPatient,
          Strings.healthColDate,
          Strings.healthColValue,
          Strings.healthColProfessional,
          Strings.healthColDescription,
        ].join(';'),
      );
    for (final r in rows) {
      b.writeln(
        [
          cpf(r.vcPayerCpf ?? r.vcCpf),
          cell(r.vcPayer ?? r.vcPatient),
          cpf(r.vcCpf),
          cell(r.vcPatient),
          Dates.format(r.dtPaid),
          r.vlPaid.toStringAsFixed(2).replaceAll('.', ','),
          cell(r.vcProfessional),
          cell(r.vcDescription),
        ].join(';'),
      );
    }
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$b')]);
  }
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
