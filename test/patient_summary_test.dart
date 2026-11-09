import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/patients/domain/patient_summary_models.dart';
import 'package:odonto_app/features/patients/presentation/patient_summary_tabs.dart';

final _json = {
  'appointments': [
    {
      'nr_appointment': 2,
      'dh_start': '2999-01-10T13:00:00Z',
      'dh_end': '2999-01-10T14:00:00Z',
      'it_status': 1,
      'vc_professional': 'Dra. Ana',
    },
    {
      'nr_appointment': 1,
      'dh_start': '2020-01-10T13:00:00Z',
      'dh_end': '2020-01-10T14:00:00Z',
      'it_status': 7,
      'vc_professional': 'Dra. Ana',
    },
  ],
  'finance': {
    'entries': [
      {
        'nr_entry': 1,
        'vc_description': 'Orçamento 3',
        'vl_amount': 150,
        'dt_due': '2020-01-10',
        'it_status': 1,
        'nr_installment': 1,
        'qt_installments': 2,
      },
      {
        'nr_entry': 2,
        'vc_description': 'Consulta',
        'vl_amount': 200,
        'vl_paid': 200,
        'dt_paid': '2026-11-01',
        'it_status': 2,
        'it_payment_method': 2,
        'nr_receipt': 5,
        'vc_receipt_number': 'R-5',
      },
    ],
    'totals': {
      'vl_open': 150,
      'vl_overdue': 150,
      'qt_overdue': 1,
      'vl_paid': 200,
    },
    'receipts': [
      {
        'nr_receipt': 5,
        'vc_number': 'R-5',
        'nr_entry': 2,
        'vl_amount': 200,
        'dt_paid': '2026-11-01',
      },
    ],
  },
  'plan': [
    {
      'nr_budget': 3,
      'vc_title': 'Reabilitação',
      'vl_total': 300,
      'items': [
        {
          'nr_item': 1,
          'vc_description': 'Restauração',
          'vl_total': 200,
          'dt_done': '2026-11-02',
        },
        {'nr_item': 2, 'vc_description': 'Limpeza', 'vl_total': 100},
      ],
    },
  ],
  'permission': {'id_agenda': true, 'id_finance': true, 'id_budgets': true},
};

Future<void> _pump(
  WidgetTester tester,
  Widget tab,
  Map<String, dynamic> json,
) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientSummaryProvider.overrideWith(
          (ref, arg) async => PatientSummary.fromJson(json),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: tab)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  test('Resumo do paciente le as tres partes', () {
    final s = PatientSummary.fromJson(_json);
    expect(s.appointments, hasLength(2));
    expect(s.finance!.vlOverdue, 150);
    expect(s.finance!.entries.first.isOverdue(DateTime(2026, 11, 9)), isTrue);
    expect(s.finance!.entries[1].isPaid, isTrue);
    expect(s.plan!.single.qtDone, 1);
    expect(s.plan!.single.progress, 0.5);
  });

  test('Sem permissao a parte vem null', () {
    final s = PatientSummary.fromJson({
      'appointments': null,
      'finance': null,
      'plan': null,
      'permission': {'id_agenda': false},
    });
    expect(s.appointments, isNull);
    expect(s.finance, isNull);
    expect(s.canAgenda, isFalse);
  });

  testWidgets('Abas desenham sem erro', (tester) async {
    await _pump(tester, const PatientAppointmentsTab(nrPatient: 1), _json);
    expect(find.text('Próximas consultas'), findsWidgets);
    await _pump(tester, const PatientFinanceTab(nrPatient: 1), _json);
    expect(find.text('Recibos'), findsOneWidget);
    await _pump(tester, const TreatmentPlanTab(nrPatient: 1), _json);
    expect(find.text('1 de 2 realizados'), findsOneWidget);
  });
}
