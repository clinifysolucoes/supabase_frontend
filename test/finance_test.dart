import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/agenda/domain/agenda_models.dart';
import 'package:odonto_app/features/finance/data/finance_repository.dart';
import 'package:odonto_app/features/finance/domain/bank_models.dart';
import 'package:odonto_app/features/finance/domain/cash_models.dart';
import 'package:odonto_app/features/finance/domain/dre_models.dart';
import 'package:odonto_app/features/finance/domain/health_models.dart';
import 'package:odonto_app/features/finance/domain/phase4_models.dart';
import 'package:odonto_app/features/finance/domain/receivable_models.dart';
import 'package:odonto_app/features/finance/domain/finance_models.dart';
import 'package:odonto_app/features/finance/presentation/checkout_dialog.dart';
import 'package:odonto_app/features/finance/presentation/bank_tab.dart';
import 'package:odonto_app/features/finance/presentation/payment_details_fields.dart';
import 'package:odonto_app/features/finance/presentation/finance_page.dart';
import 'package:odonto_app/features/profiles/application/profiles_controller.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

/// Mesmos formatos das RPCs (tests/12_finance.sql no backend).
final _catalog = {
  'accounts': [
    {
      'nr_account': 1,
      'vc_name': 'Caixa',
      'it_type': 1,
      'vl_opening': 100,
      'vl_balance': 350.5,
      'it_status': 1,
    },
    {
      'nr_account': 2,
      'vc_name': 'Banco',
      'it_type': 2,
      'vl_opening': 0,
      'vl_balance': -20,
      'it_status': 1,
    },
  ],
  'categories': [
    {
      'nr_category': 1,
      'vc_name': 'Tratamentos',
      'it_kind': 1,
      'it_cost_type': null,
      'it_status': 1,
      'qt_entries': 0,
    },
    {
      'nr_category': 4,
      'vc_name': 'Aluguel',
      'it_kind': 2,
      'it_cost_type': 1,
      'it_status': 1,
      'qt_entries': 3,
    },
  ],
  'suppliers': [
    {'nr_supplier': 1, 'vc_name': 'Dental Sul', 'it_status': 1},
  ],
  'rates': [
    {
      'nr_rate': 1,
      'vc_name': 'Crédito 1 a 6x',
      'it_payment_method': 3,
      'qt_installments_min': 1,
      'qt_installments_max': 6,
      'pc_fee': 3.5,
      'vl_fee_fixed': 0,
      'qt_days': 30,
      'nr_account': 2,
      'it_status': 1,
    },
  ],
  'permission': {'id_read': true, 'id_create': true, 'id_update': true},
};

Map<String, dynamic> _entry({
  int nr = 10,
  int status = 1,
  bool overdue = false,
}) => {
  'nr_entry': nr,
  'it_kind': 2,
  'nr_category': 4,
  'vc_category': 'Aluguel',
  'it_cost_type': 1,
  'nr_account': null,
  'nr_supplier': 1,
  'vc_supplier': 'Dental Sul',
  'vc_description': 'Aluguel (1/3)',
  'vl_amount': 1500,
  'dt_due': '2026-11-10',
  'it_status': status,
  'id_overdue': overdue,
  'nr_installment': 1,
  'qt_installments': 3,
  'id_recurring': false,
};

class _FakeRepo implements FinanceRepository {
  bool configured = true;
  int setups = 0;
  EntryDraft? created;
  final settles = <(int, String, Map<String, dynamic>)>[];
  final newCategories = <Map<String, dynamic>>[];
  CheckoutDraft? checkedOut;
  final cashCalls = <(String, Map<String, dynamic>)>[];
  bool cashOpen = false;
  DateTime? healthFrom;
  int? bankAccount;
  bool lastByCompetence = false;
  final healthCalls = <({bool onlyPending, List<int>? entries, bool mark})>[];
  final deletedAttachments = <int>[];
  final savedRegisters = <(String, Map<String, dynamic>)>[];

  @override
  Future<void> setup({required int nrCompany, required int nrBranch}) async {
    setups++;
    configured = true;
  }

  @override
  Future<FinCatalog> catalog({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async => FinCatalog.fromJson({
    ..._catalog,
    'categories': [...(_catalog['categories'] as List), ...newCategories],
  });

  @override
  Future<int?> saveRegister({
    required int nrCompany,
    required int nrBranch,
    required String rpc,
    required String key,
    int? id,
    required Map<String, dynamic> fields,
  }) async {
    savedRegisters.add((rpc, fields));
    if (rpc != 'fin_category_save' || id != null) return id;
    newCategories.add({
      'nr_category': 9,
      'it_status': 1,
      'qt_entries': 0,
      ...fields,
    });
    return 9;
  }

  @override
  Future<FinOverview> overview({
    required int nrCompany,
    required int nrBranch,
  }) async => FinOverview.fromJson({
    'id_configured': configured,
    'vl_balance': 330.5,
    'accounts': _catalog['accounts'],
    'today': {'vl_receivable': 200, 'vl_payable': 0},
    'overdue': {
      'vl_receivable': 0,
      'qt_receivable': 0,
      'vl_payable': 80,
      'qt_payable': 1,
    },
    'month': {
      'vl_received': 1000,
      'vl_paid': 400,
      'vl_to_receive': 500,
      'vl_to_pay': 1500,
    },
    'next': [_entry()],
    'permission': _catalog['permission'],
  });

  @override
  Future<FinEntryList> entries({
    required int nrCompany,
    required int nrBranch,
    required int itKind,
    required DateTime from,
    required DateTime to,
    EntryFilter status = EntryFilter.all,
    int? nrCategory,
    String? search,
    bool byCompetence = false,
    bool onlyInstallments = false,
  }) async => FinEntryList.fromJson({
    '_': lastByCompetence = byCompetence,
    'entries': itKind == EntryKind.payable ? [_entry()] : [],
    'totals': {
      'vl_open': 1500,
      'vl_overdue': 0,
      'vl_paid': 0,
      'vl_cancelled': 0,
      'qt_total': 1,
      'by_cost_type': {'1': 1500},
    },
  });

  @override
  Future<int> createEntry({
    required int nrCompany,
    required int nrBranch,
    required EntryDraft draft,
  }) async {
    created = draft;
    return draft.qtInstallments;
  }

  @override
  Future<void> updateEntry({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required Map<String, dynamic> changes,
  }) async {}

  @override
  Future<void> settle({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required String action,
    Map<String, dynamic> extra = const {},
  }) async => settles.add((nrEntry, action, extra));

  @override
  Future<Cashflow> cashflow({
    required int nrCompany,
    required int nrBranch,
    required DateTime month,
  }) async => const Cashflow();

  String? dreBasis;

  @override
  Future<DreReport> dre({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    String basis = 'competence',
  }) async {
    dreBasis = basis;
    List<double> months(double jan) => [jan, for (var i = 1; i < 12; i++) 0];
    Map<String, dynamic> line(
      String key,
      String label,
      int level,
      double jan,
    ) => {
      'vc_key': key,
      'vc_label': label,
      'it_level': level,
      'it_sign': 1,
      'values': months(jan),
      'vl_total': jan,
      'pc_revenue': jan / 10,
    };
    return DreReport.fromJson({
      'months': [
        for (var m = 1; m <= 12; m++) '2030-${m.toString().padLeft(2, '0')}',
      ],
      'vc_basis': basis,
      'lines': [
        line('gross', 'Receita bruta', 1, 1000),
        line('cat:1', 'Tratamentos', 3, 1000),
        line('variable', '(-) Custos variáveis', 2, 200),
        line('fixed', '(-) Custos fixos', 2, 300),
        line('result', 'Resultado líquido', 1, 500),
      ],
    });
  }

  @override
  Future<Statement> statement({
    required int nrCompany,
    required int nrBranch,
    int? nrAccount,
    required DateTime from,
    required DateTime to,
  }) async => const Statement();

  @override
  Future<CheckoutData> checkoutGet({
    required int nrCompany,
    required int nrBranch,
    required int nrAppointment,
  }) async => CheckoutData.fromJson({
    'appointment': {
      'nr_appointment': nrAppointment,
      'vc_patient': 'Paciente Um',
      'nr_professional': 1,
      'vc_professional': 'Dra. Ana',
      'vc_procedure': 'Limpeza',
      'vl_price': 300,
      'pc_commission': 10,
    },
    'id_done': false,
    'id_configured': true,
    'entries': [],
    'nr_category': 1,
    'categories': [
      {'nr_category': 1, 'vc_name': 'Tratamentos'},
    ],
    'accounts': _catalog['accounts'],
    'nr_session_account': 1,
  });

  @override
  Future<Map<String, dynamic>> checkout({
    required int nrCompany,
    required int nrBranch,
    required CheckoutDraft draft,
  }) async {
    checkedOut = draft;
    return {'nr_appointment': draft.nrAppointment};
  }

  @override
  Future<CashStatus> cashStatus({
    required int nrCompany,
    required int nrBranch,
  }) async => CashStatus.fromJson({
    'mine': cashOpen
        ? {
            'nr_session': 1,
            'nr_account': 1,
            'vc_account': 'Caixa',
            'vc_user': 'Mel',
            'dh_open': '2026-11-04T11:00:00Z',
            'it_status': 1,
            'vl_open': 0,
            'vl_in': 100,
            'vl_out': 0,
            'vl_transfer_in': 0,
            'vl_transfer_out': 80,
            'by_method': {'2': 100},
            'vl_expected': 20,
          }
        : null,
    'accounts': [
      {
        'nr_account': 1,
        'vc_name': 'Caixa',
        'vl_balance': 20,
        'nr_session': cashOpen ? 1 : null,
        'vc_user': cashOpen ? 'Mel' : null,
      },
    ],
    'sessions': [],
    'permission': _catalog['permission'],
  });

  @override
  Future<Map<String, dynamic>> cashCall({
    required int nrCompany,
    required int nrBranch,
    required String rpc,
    required Map<String, dynamic> fields,
  }) async {
    cashCalls.add((rpc, fields));
    if (rpc == 'fin_cash_open') cashOpen = true;
    if (rpc == 'fin_cash_close') {
      cashOpen = false;
      return {'vl_difference': 5};
    }
    return {};
  }

  @override
  Future<ReceivableList> receivables({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    ReceivableFilter status = ReceivableFilter.all,
  }) async => ReceivableList.fromJson({
    'receivables': [
      {
        'nr_receivable': 5,
        'nr_entry': 10,
        'vc_description': 'Clareamento',
        'vc_patient': 'Paciente Um',
        'it_payment_method': 3,
        'vc_rate': 'Crédito 1 a 6x',
        'nr_installment': 1,
        'qt_installments': 2,
        'vl_gross': 150,
        'vl_fee': 5.25,
        'vl_net': 144.75,
        'dt_expected': '2026-12-10',
        'nr_account': 2,
        'vc_account': 'Banco',
        'it_status': 1,
        'id_overdue': false,
      },
    ],
    'totals': {
      'vl_gross': 150,
      'vl_fee': 5.25,
      'vl_net': 144.75,
      'vl_pending': 144.75,
      'vl_received': 0,
      'qt_total': 1,
    },
  });

  @override
  Future<HealthExport> healthExport({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    bool onlyPending = false,
    List<int>? entries,
    bool mark = false,
  }) async {
    healthFrom = from;
    healthCalls.add((onlyPending: onlyPending, entries: entries, mark: mark));
    if (onlyPending && !mark) return const HealthExport();
    return HealthExport.fromJson({
      'rows': [
        {
          'nr_entry': 31,
          'dt_paid': '2026-11-04',
          'vl_paid': 130,
          'vc_patient': 'Paciente A',
          'vc_cpf': '52998224725',
        },
        if (!mark)
          {
            'nr_entry': 32,
            'dt_paid': '2026-11-05',
            'vl_paid': 90,
            'vc_patient': 'Paciente B',
            'vc_cpf': '52998224725',
            'dh_exported': '2026-11-06T10:00:00Z',
          },
      ],
      'vl_total': 130,
    });
  }

  @override
  Future<List<FinRecurrence>> recurrences({
    required int nrCompany,
    required int nrBranch,
    int? itKind,
    bool includeInactive = false,
  }) async => [
    FinRecurrence.fromJson({
      'nr_recurrence': 5,
      'it_kind': 2,
      'nr_category': 4,
      'vc_category': 'Aluguel',
      'vc_description': 'Aluguel clínica',
      'vl_amount': 2800,
      'it_day': 30,
      'dt_start': '2026-01-30',
      'it_status': 1,
      'dt_next': '2026-11-30',
      'qt_open': 12,
      'qt_paid': 10,
    }),
  ];

  @override
  Future<List<PendingCheckout>> pendingCheckouts({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
  }) async => [
    PendingCheckout.fromJson({
      'nr_appointment': 7,
      'dh_start': '2026-11-04T12:00:00Z',
      'vc_patient': 'Paciente Sem Fechar',
      'vc_procedure': 'Limpeza',
    }),
  ];

  @override
  Future<List<FinAttachment>> attachments({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
  }) async => [
    FinAttachment.fromJson({
      'nr_attachment': 3,
      'nr_entry': nrEntry,
      'it_type': 1,
      'vc_name': 'nota.pdf',
      'vc_mime': 'application/pdf',
      'vc_user': 'Mel',
    }),
  ];

  @override
  Future<void> uploadAttachment({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required int itType,
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {}

  @override
  Future<Uint8List> downloadAttachment({
    required int nrCompany,
    required int nrBranch,
    required int nrAttachment,
  }) async => Uint8List(0);

  @override
  Future<void> deleteAttachment({
    required int nrCompany,
    required int nrBranch,
    required int nrAttachment,
  }) async => deletedAttachments.add(nrAttachment);

  @override
  Future<PlanCatalog> healthPlans({
    required int nrCompany,
    required int nrBranch,
  }) async => PlanCatalog.fromJson({
    'plans': [
      {
        'nr_plan': 1,
        'vc_name': 'Odonto Plus',
        'qt_payment_days': 45,
        'nr_account': 2,
        'it_status': 1,
        'prices': [
          {
            'nr_procedure': 1,
            'vc_procedure': 'Limpeza',
            'vl_price': 80,
            'vl_private': 200,
          },
        ],
      },
    ],
    'procedures': [
      {'nr_procedure': 1, 'vc_name': 'Limpeza'},
      {'nr_procedure': 2, 'vc_name': 'Restauração'},
    ],
    'professionals': [
      {'nr_professional': 1, 'vc_name': 'Dra. Ana'},
    ],
  });

  @override
  Future<GuideList> healthGuides({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    GuideFilter status = GuideFilter.all,
  }) async => GuideList.fromJson({
    'guides': [
      {
        'nr_guide': 3,
        'nr_plan': 1,
        'vc_plan': 'Odonto Plus',
        'nr_patient': 1,
        'vc_patient': 'Paciente Convênio',
        'dt_service': '2026-11-03',
        'vl_total': 160,
        'it_status': 2,
        'items': [
          {
            'nr_item': 1,
            'nr_procedure': 1,
            'vc_procedure': 'Limpeza',
            'qt_quantity': 2,
            'vl_unit': 80,
            'vl_total': 160,
          },
        ],
      },
    ],
    'totals': {'vl_invoiced': 160},
  });

  @override
  Future<BankList> bankLines({
    required int nrCompany,
    required int nrBranch,
    required int nrAccount,
    required DateTime from,
    required DateTime to,
  }) async {
    bankAccount = nrAccount;
    return BankList.fromJson({
      'lines': [
        {
          'nr_line': 7,
          'vc_fitid': 'F2',
          'dt_posted': '2026-12-03',
          'vl_amount': 500,
          'vc_memo': 'TED RECEBIDA',
          'it_status': 1,
          'candidates': [
            {
              'it_source': 2,
              'nr_ref': 4,
              'dt_ref': '2026-12-02',
              'vl_value': 500,
              'vc_description': 'Transferência',
              'qt_days': 1,
            },
          ],
        },
      ],
      'totals': {'vl_bank': 500, 'qt_pending': 1},
    });
  }
}

/// Abas rolam: garante que a aba esta visivel antes de tocar.
Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  group('modelos', () {
    test('catalogo, lancamento e totais', () {
      final c = FinCatalog.fromJson(_catalog);
      expect(c.accounts.length, 2);
      expect(c.categoriesOf(EntryKind.payable).single.vcName, 'Aluguel');
      expect(c.categoriesOf(EntryKind.receivable).single.itCostType, isNull);

      final l = FinEntryList.fromJson({
        'entries': [_entry(status: 1, overdue: true)],
        'totals': {
          'vl_open': '1500.00',
          'by_cost_type': {'1': 1500, '2': '20.5'},
        },
      });
      final e = l.entries.single;
      expect(e.dtDue, DateTime(2026, 11, 10));
      expect(e.isGrouped, isTrue);
      expect(e.counterpart, 'Dental Sul');
      expect(EntryStatus.label(e.itStatus, overdue: e.idOverdue), 'Vencido');
      expect(l.totals.vlOpen, 1500);
      expect(l.totals.byCostType, {1: 1500.0, 2: 20.5});
    });

    test('selo financeiro, caixa e fechamento', () {
      final a = Appointment.fromJson({
        'nr_appointment': 1,
        'dh_start': '2026-11-03T12:00:00Z',
        'dh_end': '2026-11-03T13:00:00Z',
        'it_fin_status': 2,
      });
      expect(a.itFinStatus, FinSeal.open);
      expect(FinSeal.label(FinSeal.pending), 'Financeiro pendente');
      final s = CashSession.fromJson({
        'nr_session': 1,
        'nr_account': 1,
        'vc_account': 'Caixa',
        'vc_user': 'Mel',
        'dh_open': '2026-11-04T11:00:00Z',
        'by_method': {'2': '100.5', '0': 3},
        'vl_counted': 25,
        'vl_difference': 5,
      });
      expect(s.byMethod, {2: 100.5, 0: 3.0});
      expect(s.vlDifference, 5);
      final j = const CheckoutDraft(
        nrAppointment: 3,
        vlAmount: 300,
        idPaid: true,
        nrAccount: 1,
        pcCommission: 10,
      ).toJson();
      expect(j['nr_account'], 1);
      expect(j['pc_commission'], 10);
      expect(j.containsKey('nr_category'), isFalse);
      final noCommission = const CheckoutDraft(
        nrAppointment: 3,
        vlAmount: 1,
        idCommission: false,
        pcCommission: 5,
      ).toJson();
      expect(noCommission.containsKey('pc_commission'), isFalse);
      expect(noCommission.containsKey('nr_account'), isFalse);
    });

    test('taxas, recebiveis e CSV da Receita Saude', () {
      final c = FinCatalog.fromJson(_catalog);
      expect(c.rates.single.pcFee, 3.5);
      expect(c.hasRate(3), isTrue);
      expect(c.hasRate(4), isFalse);
      expect(
        FinCatalog.fromJson({
          'accounts': [
            {'nr_account': 9, 'vc_name': 'Recebíveis', 'it_type': 4},
            {'nr_account': 2, 'vc_name': 'Banco', 'it_type': 2},
          ],
        }).payableAccounts.map((a) => a.nrAccount),
        [2],
        reason: 'conta de passagem fora das escolhas',
      );
      expect(AccountType.label(AccountType.receivables), 'Recebíveis');
      final r = Receivable.fromJson({
        'nr_receivable': 1,
        'nr_entry': 1,
        'it_payment_method': 4,
        'vl_gross': '100',
        'vl_net': '98.5',
        'dt_expected': '2026-11-14',
        'nr_account': 2,
        'it_status': 1,
        'id_overdue': true,
      });
      expect(r.isPending, isTrue);
      expect(
        ReceivableStatus.label(r.itStatus, overdue: r.idOverdue),
        'Vencido',
      );
      final x = HealthExport.fromJson({
        'rows': [
          {
            'dt_paid': '2026-11-10',
            'vl_paid': 300,
            'vc_patient': 'Ana; Souza',
            'vc_cpf': '52998224725',
            'vc_professional': 'Dra. Bia',
          },
          {
            'dt_paid': '2026-11-11',
            'vl_paid': 50.5,
            'vc_patient': 'Leo',
            'vc_payer': 'Mãe do Leo',
            'vc_payer_cpf': '11144477735',
          },
        ],
        'qt_missing_cpf': 0,
      });
      final lines = const LineSplitter().convert(
        utf8.decode(x.toCsv().sublist(3)),
      );
      expect(lines.length, 3);
      expect(
        lines[1],
        '529.982.247-25;"Ana; Souza";529.982.247-25;"Ana; Souza";10/11/2026;300,00;Dra. Bia;',
      );
      expect(lines[2], '111.444.777-35;Mãe do Leo;;Leo;11/11/2026;50,50;;');
    });

    test('OFX: SGML e XML, valores, datas e historico', () {
      const sgml = '''
OFXHEADER:100
<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20261201120000[-3:BRT]
<TRNAMT>-1500,00
<FITID>F1
<MEMO>PAG ALUGUEL &amp; CONDOMINIO
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20261203
<TRNAMT>500.00
<FITID>F2
<NAME>TED
<MEMO>TED RECEBIDA
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>''';
      final a = OfxParser.parse(sgml);
      expect(a.length, 2);
      expect(a[0].fitid, 'F1');
      expect(a[0].amount, -1500);
      expect(a[0].posted, DateTime(2026, 12, 1));
      expect(a[0].memo, 'PAG ALUGUEL & CONDOMINIO');
      expect(a[1].memo, 'TED · TED RECEBIDA');
      expect(a[1].toJson()['dt_posted'], '2026-12-03');
      const xml =
          '<OFX><BANKTRANLIST><STMTTRN><TRNTYPE>FEE</TRNTYPE>'
          '<DTPOSTED>20261205</DTPOSTED><TRNAMT>-12.90</TRNAMT>'
          '<FITID>F3</FITID><MEMO>TARIFA</MEMO></STMTTRN>'
          '<STMTTRN><DTPOSTED>2026</DTPOSTED><TRNAMT>1</TRNAMT><FITID>X</FITID></STMTTRN>'
          '</BANKTRANLIST></OFX>';
      final b = OfxParser.parse(xml);
      expect(b.single.amount, -12.9, reason: 'data invalida fica de fora');
      expect(b.single.memo, 'TARIFA');
      final plan = PlanCatalog.fromJson({
        'plans': [
          {
            'nr_plan': 1,
            'vc_name': 'P',
            'prices': [
              {'nr_procedure': 5, 'vl_price': 80},
            ],
          },
        ],
      }).plans.single;
      expect(plan.priceOf(5), 80);
      expect(plan.priceOf(6), isNull);
    });

    test('dados do pagamento: so os campos da forma', () {
      final c = PaymentDetailsController();
      c.brand.text = 'Visa';
      c.last4.text = '4321';
      c.bank.text = 'Banco X';
      c.document.text = '529.982.247-25';
      expect(c.value(PaymentMethod.credit).toJson(), {
        'vc_card_brand': 'Visa',
        'vc_card_last4': '4321',
        'vc_holder_document': '52998224725',
      });
      expect(c.value(PaymentMethod.check).toJson(), {
        'vc_bank_name': 'Banco X',
        'vc_holder_document': '52998224725',
      });
      expect(c.value(1).toJson(), isEmpty);
      c.dispose();
      final a = FinAccount.fromJson({
        'nr_account': 2,
        'vc_name': 'Banco',
        'it_type': 2,
        'vc_bank_code': '001',
        'vc_bank_name': 'Banco do Brasil',
        'vc_agency': '1234',
      });
      expect(
        a.bankSummary,
        '001 Banco do Brasil · ${Strings.bankAgencyShort} 1234',
      );
      expect(FinAttachment.mimeOf('Nota.PDF'), 'application/pdf');
      expect(FinAttachment.mimeOf('x.exe'), isNull);
    });

    test('EntryDraft: parcelada, recorrente e ja paga', () {
      final base = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aluguel',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
      );
      final once = base.toJson();
      expect(once['dt_due'], '2026-11-05');
      expect(once['qt_installments'], 1);
      expect(once.containsKey('id_recurring'), isFalse);
      expect(once.containsKey('id_paid'), isFalse);

      final inst = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aparelho',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
        qtInstallments: 3,
      ).toJson();
      expect(inst['qt_installments'], 3);

      final rec = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aluguel',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
        idRecurring: true,
        qtRepeat: 12,
      ).toJson();
      expect(rec['id_recurring'], isTrue);
      expect(rec['qt_repeat'], 12);
      expect(rec.containsKey('qt_installments'), isFalse);

      final paid = EntryDraft(
        itKind: 1,
        nrCategory: 1,
        vcDescription: 'Consulta',
        vlAmount: 200,
        dtDue: DateTime(2026, 11, 5),
        nrAccount: 1,
        idPaid: true,
        dtPaid: DateTime(2026, 11, 4),
      ).toJson();
      expect(paid['id_paid'], isTrue);
      expect(paid['dt_paid'], '2026-11-04');
      expect(paid['nr_account'], 1);
    });
  });

  group('telas', () {
    late _FakeRepo repo;

    Widget app() => ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repo),
        currentCompanyProvider.overrideWith((ref) => 1),
        currentBranchNumberProvider.overrideWith((ref) => 1),
        canReadProvider.overrideWith((ref, code) => true),
        canCreateProvider.overrideWith((ref, code) => true),
        canUpdateProvider.overrideWith((ref, code) => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: const Scaffold(body: FinancePageBody()),
      ),
    );

    setUp(() => repo = _FakeRepo());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    testWidgets('sem configuracao: botao configura a filial', (tester) async {
      repo.configured = false;
      await pump(tester);
      expect(find.text(Strings.finSetupTitle), findsOneWidget);
      expect(find.widgetWithText(Tab, Strings.tabPayables), findsNothing);
      await tester.tap(find.text(Strings.finSetupAction));
      await tester.pumpAndSettle();
      expect(repo.setups, 1);
      expect(find.widgetWithText(Tab, Strings.tabPayables), findsOneWidget);
    });

    testWidgets('DRE: linhas do ano e troca para caixa', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.widgetWithText(Tab, Strings.tabDre));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, Strings.tabDre));
      await tester.pumpAndSettle();
      expect(find.text('Receita bruta'), findsOneWidget);
      expect(find.text('Resultado líquido'), findsOneWidget);
      expect(find.textContaining('1.000,00'), findsWidgets);
      expect(find.text('Jan/30'), findsOneWidget);
      expect(repo.dreBasis, 'competence');
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text(Strings.dreCash),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.dreBasis, 'cash');
      expect(find.text(Strings.dreCashHint), findsOneWidget);
    });

    testWidgets('visao geral: saldo, vencidos e proximos', (tester) async {
      await pump(tester);
      expect(find.text(Strings.finBalance), findsOneWidget);
      expect(find.textContaining('330,50'), findsOneWidget);
      expect(find.text(Strings.finOverdueCount(1)), findsOneWidget);
      expect(find.text('Aluguel (1/3)'), findsOneWidget);
    });

    testWidgets('a pagar: lista, nova parcelada e baixa', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      await tester.pumpAndSettle();
      expect(find.text('Aluguel (1/3)'), findsOneWidget);
      expect(find.text(Strings.finInstallmentOf(1, 3)), findsOneWidget);

      // nova conta a pagar parcelada em 3
      await tester.tap(find.text(Strings.newPayable));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.finDescription} *'),
          matching: find.byType(TextField),
        ),
        'Autoclave',
      );
      await tester.tap(find.text('${Strings.finCategory} *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aluguel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finRepeatInstallments));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.finTotalAmount} *'),
          matching: find.byType(TextField),
        ),
        '1000',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.finInstallments),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(Strings.finInstallmentsPreview(3, 'R\$ 333,33')),
        findsOneWidget,
      );
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      expect(repo.created?.vcDescription, 'Autoclave');
      expect(repo.created?.nrCategory, 4);
      expect(repo.created?.qtInstallments, 3);
      expect(repo.created?.vlAmount, 1000);

      // baixa pelo detalhe: conta ativa ja vem escolhida
      await tester.tap(find.text('Aluguel (1/3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finPay));
      await tester.pumpAndSettle();
      expect(find.text(Strings.finPayTitle), findsOneWidget);
      await tester.tap(find.text(Strings.finPay).last);
      await tester.pumpAndSettle();
      final (nr, action, extra) = repo.settles.single;
      expect(nr, 10);
      expect(action, 'PAY');
      expect(extra['nr_account'], 1);
      expect(extra['vl_paid'], 1500);
    });

    testWidgets('lancamento: + cria a categoria de despesa e ja escolhe', (
      tester,
    ) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.newPayable));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(Strings.finNewCategory));
      await tester.pumpAndSettle();
      // ja vem como despesa, tipo de custo fixo
      expect(find.text(Strings.finCostType), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.name} *'),
          matching: find.byType(TextField),
        ),
        'Manutenção',
      );
      await tester.tap(find.text(Strings.save).last);
      await tester.pumpAndSettle();
      final c = repo.newCategories.single;
      expect(c['vc_name'], 'Manutenção');
      expect(c['it_kind'], EntryKind.payable);
      expect(c['it_cost_type'], CostType.fixed);
      // de volta ao lancamento, com a categoria nova escolhida
      expect(find.text(Strings.newPayable), findsWidgets);
      expect(find.text('Manutenção'), findsOneWidget);
    });

    testWidgets('cadastros: nova categoria nos dois grupos', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabFinRegisters);
      await tester.pumpAndSettle();
      expect(find.text(Strings.finNewCategory), findsNWidgets(2));
    });

    testWidgets('fechamento: valor da precificacao, comissao e receber agora', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider.overrideWithValue(repo),
            currentCompanyProvider.overrideWith((ref) => 1),
            currentBranchNumberProvider.overrideWith((ref) => 1),
            canReadProvider.overrideWith((ref, code) => true),
            canCreateProvider.overrideWith((ref, code) => true),
            canUpdateProvider.overrideWith((ref, code) => true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(useGoogleFonts: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => CheckoutDialog.show(context, 7),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Paciente Um'), findsOneWidget);
      expect(find.text(Strings.checkoutPriceHint), findsOneWidget);
      // comissao de 10% sobre 300
      expect(find.textContaining('R\$ 30,00'), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.finInstallments),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.confirm));
      await tester.pumpAndSettle();
      final d = repo.checkedOut!;
      expect(d.nrAppointment, 7);
      expect(d.vlAmount, 300);
      expect(d.qtInstallments, 3);
      expect(d.idPaid, isTrue);
      expect(d.nrAccount, 1, reason: 'caixa aberto do usuario');
      expect(d.idCommission, isTrue);
      expect(d.pcCommission, 10);
      expect(d.nrCategory, 1);
    });

    testWidgets('caixa: abre, mostra o resumo e fecha', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.cashTab);
      await tester.pumpAndSettle();
      expect(find.text(Strings.cashClosed), findsOneWidget);
      await tester.tap(find.text(Strings.cashOpenAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.cashOpenAction).last);
      await tester.pumpAndSettle();
      expect(repo.cashCalls.single.$1, 'fin_cash_open');
      expect(repo.cashCalls.single.$2['nr_account'], 1);
      expect(find.text(Strings.cashExpected), findsOneWidget);
      expect(find.text(PaymentMethod.label(2)), findsOneWidget);
      expect(find.text(Strings.cashWith('Mel')), findsOneWidget);

      await tester.tap(find.text(Strings.cashCloseAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.cashCounted),
          matching: find.byType(TextField),
        ),
        '25',
      );
      await tester.pumpAndSettle();
      expect(find.text('${Strings.cashDifference}: R\$ 5,00'), findsOneWidget);
      await tester.tap(find.text(Strings.cashCloseAction).last);
      await tester.pumpAndSettle();
      expect(repo.cashCalls.last.$1, 'fin_cash_close');
      expect(repo.cashCalls.last.$2['vl_counted'], 25);
    });

    testWidgets('baixa de conta a pagar: sem parcelas no cartao', (
      tester,
    ) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      await tester.pumpAndSettle();
      // conta a pagar: sem campo de parcelas no cartao
      await tester.tap(find.text('Aluguel (1/3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finPay));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finPaymentMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.text(PaymentMethod.label(3)).last);
      await tester.pumpAndSettle();
      expect(find.text(Strings.cardInstallments), findsNothing);
    });

    testWidgets('recebiveis: lista e confirma o que caiu', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabReceivablesCards);
      await tester.pumpAndSettle();
      expect(find.text('Paciente Um'), findsOneWidget);
      expect(find.text('R\$ 144,75'), findsWidgets);
      await tester.tap(find.byTooltip(Strings.recvConfirm));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.recvReceivedValue),
          matching: find.byType(TextField),
        ),
        '144',
      );
      await tester.tap(find.text(Strings.confirm));
      await tester.pumpAndSettle();
      final (rpc, fields) = repo.cashCalls.single;
      expect(rpc, 'fin_receivable_settle');
      expect(fields['vc_action'], 'CONFIRM');
      expect(fields['nr_receivable'], 5);
      expect(fields['vl_received'], 144);
      expect(fields['dt_received'], '2026-12-10');
      expect(fields['nr_account'], 2);
    });

    testWidgets('cadastros: taxas e nova taxa', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabFinRegisters);
      await tester.pumpAndSettle();
      expect(find.text('Crédito 1 a 6x'), findsOneWidget);
      await tester.tap(find.text(Strings.rateNew));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.rateName} *'),
          matching: find.byType(TextField),
        ),
        'Débito',
      );
      await tester.tap(find.text(PaymentMethod.label(3)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(PaymentMethod.label(4)).last);
      await tester.pumpAndSettle();
      expect(find.text(Strings.rateInstallmentsMin), findsNothing);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.ratePercent),
          matching: find.byType(TextField),
        ),
        '1,5',
      );
      await tester.tap(find.text(Strings.save).last);
      await tester.pumpAndSettle();
      expect(repo.savedRegisters.single.$1, 'fin_rate_save');
      final fields = repo.savedRegisters.single.$2;
      expect(fields['it_payment_method'], 4);
      expect(fields['pc_fee'], 1.5);
      expect(fields['qt_installments_max'], 1);
      expect(fields['nr_account'], 2, reason: 'banco sugerido');
    });

    testWidgets('extrato: exportacao Receita Saude do mes', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabStatement);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.healthExport));
      await tester.pumpAndSettle();
      // so os pendentes: nenhum no fake
      await tester.tap(find.text(Strings.healthList));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(repo.healthFrom, DateTime(now.year, now.month));
      expect(find.text(Strings.healthEmpty), findsOneWidget);
      // todos: um ja exportado vem desmarcado
      await tester.tap(find.text(Strings.healthOnlyPending));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.healthList));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paciente B'), findsOneWidget);
      expect(find.textContaining(Strings.healthExportedOn('')), findsOneWidget);
      expect(
        find.text(Strings.healthSelected(1, 'R\$ 130,00')),
        findsOneWidget,
      );
      await tester.tap(find.text(Strings.healthGenerate));
      // salvar o arquivo nao termina no teste (sem plugin): so a chamada importa
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final last = repo.healthCalls.last;
      expect(last.mark, isTrue);
      expect(last.entries, [31]);
    });

    testWidgets('a pagar: contas recorrentes e encerrar', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      await tester.tap(find.text(Strings.recurrences));
      await tester.pumpAndSettle();
      expect(find.text('Aluguel clínica'), findsOneWidget);
      expect(
        find.textContaining(Strings.recurrenceCounts(12, 10)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(Strings.recurrenceStop));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.confirm).last);
      await tester.pumpAndSettle();
      final (rpc, fields) = repo.cashCalls.last;
      expect(rpc, 'fin_recurrence_save');
      expect(fields, {'vc_action': 'CANCEL', 'nr_recurrence': 5});
    });

    testWidgets('a pagar: filtro por competencia', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      expect(repo.lastByCompetence, isFalse);
      await tester.tap(find.text(Strings.finByCompetence));
      await tester.pumpAndSettle();
      expect(repo.lastByCompetence, isTrue);
    });

    testWidgets('a receber: atendimentos sem fechamento', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabReceivables);
      expect(find.text(Strings.pendingCheckoutTitle(1)), findsOneWidget);
      await tester.tap(find.text(Strings.pendingCheckoutTitle(1)));
      await tester.pumpAndSettle();
      expect(find.text('Paciente Sem Fechar'), findsOneWidget);
      expect(find.text(Strings.checkoutAction), findsOneWidget);
    });

    testWidgets('lancamento: anexos listados e exclusao', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabPayables);
      await tester.tap(find.text('Aluguel (1/3)'));
      await tester.pumpAndSettle();
      expect(find.text('nota.pdf'), findsOneWidget);
      expect(find.text(Strings.attachAddReceipt), findsOneWidget);
      await tester.tap(find.byTooltip(Strings.remove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.confirm).last);
      await tester.pumpAndSettle();
      expect(repo.deletedAttachments, [3]);
    });

    testWidgets('convenios: guia faturada e pagamento com glosa', (
      tester,
    ) async {
      await pump(tester);
      await openTab(tester, Strings.tabPlans);
      await tester.pumpAndSettle();
      expect(find.text('Paciente Convênio · Odonto Plus'), findsOneWidget);
      expect(find.text('2× Limpeza'), findsOneWidget);
      await tester.tap(find.text(Strings.guidePay));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.guideDenied),
          matching: find.byType(TextField),
        ),
        '40',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${Strings.guidePaidValue}: R\$ 120,00'),
        findsOneWidget,
      );
      await tester.tap(find.text(Strings.confirm));
      await tester.pumpAndSettle();
      final (rpc, fields) = repo.cashCalls.single;
      expect(rpc, 'health_guide_settle');
      expect(fields['vc_action'], 'PAY');
      expect(fields['nr_guides'], [3]);
      expect(fields['denials'], [
        {'nr_item': 1, 'vl_denied': 40.0},
      ]);
    });

    testWidgets('conciliacao: importa OFX e concilia a sugestao', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider.overrideWithValue(repo),
            currentCompanyProvider.overrideWith((ref) => 1),
            currentBranchNumberProvider.overrideWith((ref) => 1),
            canReadProvider.overrideWith((ref, code) => true),
            canCreateProvider.overrideWith((ref, code) => true),
            canUpdateProvider.overrideWith((ref, code) => true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(useGoogleFonts: false),
            home: Scaffold(
              body: BankTab(
                pickOfx: () async =>
                    '<STMTTRN><DTPOSTED>20261203<TRNAMT>500<FITID>F2<MEMO>TED</STMTTRN>',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.bankAccount, 2, reason: 'banco escolhido sozinho');
      expect(find.text('TED RECEBIDA'), findsOneWidget);
      await tester.tap(find.text(Strings.bankImport));
      await tester.pumpAndSettle();
      final (rpc, fields) = repo.cashCalls.single;
      expect(rpc, 'fin_bank_import');
      expect(fields['nr_account'], 2);
      expect((fields['lines'] as List).single, {
        'vc_fitid': 'F2',
        'dt_posted': '2026-12-03',
        'vl_amount': 500.0,
        'vc_memo': 'TED',
      });
      await tester.tap(
        find.textContaining('${Strings.bankMatch}: Transferência'),
      );
      await tester.pumpAndSettle();
      final (rpc2, f2) = repo.cashCalls.last;
      expect(rpc2, 'fin_bank_reconcile');
      expect(f2, {'vc_action': 'MATCH', 'nr_line': 7, 'nr_transfer': 4});
    });

    testWidgets('cadastros: convenio com a tabela de preco', (tester) async {
      await pump(tester);
      await openTab(tester, Strings.tabFinRegisters);
      await tester.pumpAndSettle();
      expect(find.text(Strings.planSummary(1, 45)), findsOneWidget);
      await tester.tap(find.text('Odonto Plus'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.planPrivate('R\$ 200,00')), findsOneWidget);
      await tester.tap(find.text(Strings.save).last);
      await tester.pumpAndSettle();
      final (rpc, fields) = repo.cashCalls.single;
      expect(rpc, 'health_plan_save');
      expect(fields['vc_action'], 'U');
      expect(fields['prices'], [
        {'nr_procedure': 1, 'vl_price': 80.0, 'vc_code': null},
      ]);
    });
  });
}
