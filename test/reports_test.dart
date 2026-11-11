import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/reports/application/report_controllers.dart';
import 'package:odonto_app/features/reports/domain/report_models.dart';
import 'package:odonto_app/features/reports/presentation/reports_page.dart';

final _noShow = {
  'rows': [
    {
      'dh_start': '2030-03-12T13:00:00Z',
      'vc_patient': 'Ana; Rep',
      'vc_mobile': '41999990000',
      'vc_professional': 'Dra. Rosa',
      'it_status': 7,
    },
    {
      'dh_start': '2030-03-19T13:00:00Z',
      'vc_patient': 'Beto',
      'vc_professional': 'Dr. Luis',
      'it_status': 90,
    },
  ],
  'summary': {
    'qt_total': 3,
    'qt_no_show': 1,
    'qt_cancelled': 1,
    'pc_no_show': 50,
  },
  'by_professional': [
    {
      'nr_professional': 1,
      'vc_professional': 'Dra. Rosa',
      'qt_total': 2,
      'qt_no_show': 1,
      'qt_cancelled': 0,
    },
    {
      'nr_professional': 2,
      'vc_professional': 'Dr. Luis',
      'qt_total': 1,
      'qt_no_show': 0,
      'qt_cancelled': 1,
    },
  ],
  'qt_rows': 2,
  'id_truncated': false,
};

void main() {
  test('Le o resultado e gera o CSV', () {
    final r = ReportResult.fromJson(ReportKind.noShow, _noShow);
    expect(r.qt('qt_total'), 3);
    expect(r.vl('pc_no_show'), 50);
    final csv = utf8.decode(r.toCsv().sublist(3)).split('\n');
    expect(csv.first, 'Data;Paciente;Celular;Profissional;Situação');
    expect(csv[1], contains('"Ana; Rep"'));
    expect(csv[1], endsWith('Faltou'));
    expect(csv[2], endsWith('Cancelado'));
    // data e hora uma vez so (dd/MM/yyyy HH:mm)
    expect(
      csv[1].split(';').first,
      matches(RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}$')),
    );
  });

  test('Periodo inicial e o mes corrente', () {
    final q = ReportQuery.initial(DateTime(2030, 2, 10));
    expect(q.from, DateTime(2030, 2));
    expect(q.to, DateTime(2030, 2, 28));
    expect(ReportRepository.isoDate(q.to), '2030-02-28');
    expect(q.copyWith(nrProfessional: () => 3).nrProfessional, 3);
    expect(q.copyWith(nrProfessional: () => 3).copyWith().nrProfessional, 3);
    expect(ReportKind.birthdays.byProfessional, isFalse);
  });

  testWidgets('Todos os relatorios desenham', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cases = {
      ReportKind.noShow: _noShow,
      ReportKind.birthdays: {
        'rows': [
          {'dt_birthday': '2030-03-15', 'vc_patient': 'Ana', 'qt_age': 40},
        ],
        'summary': {'qt_patients': 1},
      },
      ReportKind.procedures: {
        'rows': [
          {
            'dh_evolution': '2030-03-05T13:30:00Z',
            'vc_patient': 'Ana',
            'vc_procedure': 'Restauração',
            'vl_total': 250,
          },
        ],
        'summary': {'qt_procedures': 1, 'vl_total': 250},
      },
      ReportKind.commissions: {
        'rows': [
          {
            'dt_competence': '2030-03-05',
            'dt_due': '2030-04-10',
            'vc_professional': 'Dra. Rosa',
            'vc_description': 'Comissão',
            'vl_amount': 75,
            'it_status': 1,
          },
        ],
        'summary': {'vl_total': 100, 'vl_paid': 25, 'vl_open': 75},
        'id_truncated': true,
        'qt_rows': 2001,
      },
    };
    for (final e in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportView(result: ReportResult.fromJson(e.key, e.value)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('2001'), findsOneWidget);
  });

  testWidgets('Resumo por profissional aparece com mais de um', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportView(
              result: ReportResult.fromJson(ReportKind.noShow, _noShow),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Por profissional'), findsOneWidget);
    expect(find.text('Taxa de faltas'), findsOneWidget);
  });
}
