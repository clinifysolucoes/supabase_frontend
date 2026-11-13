import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/agenda/application/agenda_controllers.dart';
import 'package:odonto_app/features/specialty_charts/domain/chart_models.dart';
import 'package:odonto_app/features/specialty_charts/presentation/perio_tab.dart';
import 'package:odonto_app/features/specialty_charts/presentation/specialty_charts_tab.dart';

final _model = ChartModel.fromJson({
  'nr_model': 2,
  'vc_name': 'Endodontia',
  'id_per_tooth': true,
  'it_status': 1,
  'fields': [
    {'nr_field': 1, 'vc_label': 'Diagnóstico', 'it_type': 7},
    {
      'nr_field': 2,
      'vc_label': 'Dor',
      'it_type': 4,
      'vc_options': 'Ausente|Provocada|Espontânea',
      'id_required': true,
    },
    {'nr_field': 3, 'vc_label': 'Comprimento', 'it_type': 5, 'vc_unit': 'mm'},
    {'nr_field': 4, 'vc_label': 'Fístula', 'it_type': 3},
    {'nr_field': 5, 'vc_label': 'Obturação', 'it_type': 6},
    {'nr_field': 6, 'vc_label': 'Observações', 'it_type': 2},
  ],
});

final _chart = PatientChart.fromJson({
  'nr_chart': 1,
  'nr_model': 2,
  'vc_model': 'Endodontia',
  'vc_tooth': '36, 37',
  'dt_chart': '2026-11-10',
  'vc_professional': 'Dr. Luis',
  'vc_user': 'Ivo',
  'values': [
    {'nr_field': 1, 'vc_label': 'Diagnóstico', 'it_type': 7},
    {'nr_field': 2, 'vc_label': 'Dor', 'it_type': 4, 'vc_value': 'Espontânea'},
    {
      'nr_field': 3,
      'vc_label': 'Comprimento',
      'it_type': 5,
      'vc_unit': 'mm',
      'vc_value': '20.5',
    },
    {'nr_field': 4, 'vc_label': 'Fístula', 'it_type': 3, 'vc_value': 'S'},
    {
      'nr_field': 5,
      'vc_label': 'Obturação',
      'it_type': 6,
      'vc_value': '2026-11-01',
    },
    {'nr_field': 6, 'vc_label': 'Observações', 'it_type': 2},
  ],
});

final _exam = PerioExam.fromJson({
  'nr_exam': 1,
  'dt_exam': '2026-11-12',
  'summary': {
    'qt_teeth': 2,
    'qt_sites': 12,
    'pc_bleeding': 16.7,
    'pc_plaque': 16.7,
    'vl_probing_mean': 2.7,
    'qt_sites_4_5': 1,
    'qt_sites_6': 1,
    'vl_attachment_mean': 2.8,
  },
  'teeth': [
    {
      'vc_tooth': '16',
      'it_mobility': 1,
      'it_furcation': 2,
      'qt_probing': [3, 2, 6, 4, 2, 3],
      'qt_recession': [1, 0, 1, 0, 0, null],
      'id_bleeding': [true, false, true, false, false, false],
    },
    {'vc_tooth': '18', 'id_missing': true},
  ],
});

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [agendaProfessionalsProvider.overrideWith((ref) async => [])],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  test('Modelo, valores e exibicao', () {
    expect(_model.fields[1].type, ChartFieldType.choice);
    expect(_model.fields[1].options, ['Ausente', 'Provocada', 'Espontânea']);
    expect(_model.fields[1].toJson()['vc_options'], hasLength(3));
    expect(_chart.filled, hasLength(4));
    expect(_chart.values[2].display, '20,5 mm');
    expect(_chart.values[3].display, 'Sim');
    expect(_chart.values[4].display, '01/11/2026');
  });

  test('Dente do periograma', () {
    final t = _exam.tooth('16')!;
    expect(t.maxProbing, 6);
    expect(t.recession[5], isNull);
    expect(t.plaque.every((p) => p == null), isTrue);
    final j = t.toJson();
    expect(j['qt_probing'], [3, 2, 6, 4, 2, 3]);
    expect(j.containsKey('id_plaque'), isFalse);
    expect(PerioTooth(vcTooth: '11').hasData, isFalse);
    expect(_exam.tooth('18')!.hasData, isTrue);
    expect(perioUpper, hasLength(16));
    expect(perioColor(6), isNot(perioColor(3)));
  });

  testWidgets('Cartao da ficha mostra os valores', (tester) async {
    await _pump(tester, PatientChartCard(chart: _chart, canUpdate: true));
    expect(find.text('Endodontia · Dente 36, 37'), findsOneWidget);
    await tester.tap(find.text('Endodontia · Dente 36, 37'));
    await tester.pumpAndSettle();
    expect(find.textContaining('20,5 mm', findRichText: true), findsOneWidget);
    expect(find.text('Diagnóstico'), findsOneWidget);
  });

  testWidgets('Formulario monta os campos do modelo', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              PatientChartDialog.show(context, nrPatient: 1, model: _model),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dente *'), findsOneWidget);
    expect(find.text('Dor *'), findsOneWidget);
    expect(find.text('Comprimento (mm)'), findsOneWidget);
    expect(find.text('Fístula'), findsOneWidget);
  });

  testWidgets('Periograma desenha resumo e arcadas', (tester) async {
    await _pump(
      tester,
      ListView(
        children: [
          PerioSummaryView(summary: _exam.summary),
          PerioChartView(teeth: _exam.teeth),
        ],
      ),
    );
    expect(find.text('Bolsas 6 mm ou mais'), findsOneWidget);
    expect(find.text('18 ✕'), findsOneWidget);
    expect(find.text('M1 F2'), findsOneWidget);
  });
}
