import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/dashboard/domain/dashboard_models.dart';
import 'package:odonto_app/features/dashboard/presentation/dashboard_page.dart';

final _full = {
  'agenda': {
    'qt_appointments': 20,
    'qt_attended': 15,
    'qt_no_show': 2,
    'qt_cancelled': 3,
    'pc_no_show': 10,
    'qt_online': 4,
    'qt_appointments_prev': 16,
    'qt_today': 5,
    'qt_today_confirmed': 3,
  },
  'patients': {
    'qt_new': 6,
    'qt_new_prev': 3,
    'qt_active': 120,
    'qt_birthdays_today': 1,
    'qt_procedures': 18,
    'by_source': [
      {'it_source': 2, 'qt': 4},
      {'it_source': null, 'qt': 2},
    ],
    'top_procedures': [
      {'vc_procedure': 'Restauração', 'qt': 8},
      {'vc_procedure': 'Limpeza', 'qt': 5},
    ],
  },
  'budgets': {
    'qt_created': 10,
    'vl_created': 15000,
    'qt_accepted': 4,
    'vl_accepted': 6000,
    'pc_conversion': 40,
    'qt_open': 6,
    'vl_open': 9000,
  },
  'finance': {
    'vl_revenue': 25000,
    'vl_expense': 11000,
    'vl_result': 14000,
    'vl_revenue_prev': 20000,
    'vl_overdue': 800,
    'qt_overdue': 2,
    'vl_payable_week': 1500,
  },
  'series': [
    for (var m = 6; m <= 11; m++)
      {
        'dt_month': '2026-${m.toString().padLeft(2, '0')}-01',
        'qt_attended': m * 2,
        'qt_new_patients': m,
        'vl_revenue': m * 1000,
        'vl_expense': m * 400,
      },
  ],
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DashboardView(data: DashboardData.fromJson(json)),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  test('Le as partes e calcula a variacao', () {
    final d = DashboardData.fromJson(_full);
    expect(d.agenda!.qtAttended, 15);
    expect(d.patients!.bySource.last.source, isNull);
    expect(d.finance!.vlResult, 14000);
    expect(d.series, hasLength(6));
    expect(deltaPercent(25000, 20000), 25);
    expect(deltaPercent(5, 0), isNull);
    expect(d.isEmpty, isFalse);
    expect(DashboardData.fromJson({'series': []}).isEmpty, isTrue);
  });

  test('Periodos de atalho', () {
    final now = DateTime(2026, 1, 15);
    final last = dashboardRange(DashboardPeriod.lastMonth, now);
    expect(last.from, DateTime(2025, 12));
    expect(last.to, DateTime(2025, 12, 31));
    final year = dashboardRange(DashboardPeriod.thisYear, now);
    expect(year.to, DateTime(2026, 12, 31));
  });

  testWidgets('Painel completo desenha sem erro', (tester) async {
    await _pump(tester, _full);
    expect(find.text('Recebido x pago (6 meses)'), findsOneWidget);
    expect(find.text('Procedimentos mais executados'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Não informado'), findsOneWidget);
  });

  testWidgets('So a agenda: sem financeiro nem pacientes', (tester) async {
    await _pump(tester, {
      'agenda': _full['agenda'],
      'patients': null,
      'budgets': null,
      'finance': null,
      'series': [
        {'dt_month': '2026-11-01', 'qt_attended': 3},
      ],
    });
    expect(find.text('Consultas hoje'), findsOneWidget);
    expect(find.text('Recebido'), findsNothing);
    expect(find.text('Pacientes novos'), findsNothing);
    expect(find.text('Consultas atendidas (6 meses)'), findsOneWidget);
  });
}
