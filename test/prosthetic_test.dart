import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/prosthetic/domain/prosthetic_models.dart';
import 'package:odonto_app/features/prosthetic/presentation/prosthetic_page.dart';

final _json = {
  'works': [
    {
      'nr_work': 1,
      'nr_patient': 3,
      'vc_patient': 'Ana Prot',
      'vc_description': 'Coroa metalocerâmica',
      'vc_tooth': '16',
      'vc_shade': 'A2',
      'nr_supplier': 4,
      'vc_lab': 'Lab Sorriso',
      'it_stage': 2,
      'dt_sent': '2026-11-01',
      'dt_expected': '2026-11-05',
      'vl_cost': 300,
      'id_late': true,
      'steps': [
        {
          'nr_step': 1,
          'it_stage': 1,
          'dt_step': '2026-10-30',
          'vc_user': 'Rui',
        },
        {
          'nr_step': 2,
          'it_stage': 2,
          'dt_step': '2026-11-01',
          'vc_notes': 'Moldagem enviada',
        },
      ],
    },
    {
      'nr_work': 2,
      'nr_patient': 5,
      'vc_patient': 'Beto',
      'vc_description': 'Placa',
      'vc_lab': 'Lab do Zé',
      'vc_lab_free': 'Lab do Zé',
      'it_stage': 5,
      'nr_entry': 9,
      'steps': [],
    },
  ],
  'totals': {
    'qt_to_send': 0,
    'qt_at_lab': 1,
    'qt_trial': 0,
    'qt_ready': 0,
    'qt_late': 1,
  },
  'labs': [
    {'nr_supplier': 4, 'vc_name': 'Lab Sorriso'},
  ],
  'id_truncated': false,
};

void main() {
  test('Le a lista, os totais e as regras do trabalho', () {
    final d = ProstheticListData.fromJson(_json);
    expect(d.works, hasLength(2));
    expect(d.qtLate, 1);
    expect(d.labs.single.name, 'Lab Sorriso');
    final w = d.works.first;
    expect(w.idLate, isTrue);
    expect(w.steps.last.vcNotes, 'Moldagem enviada');
    expect(w.willCreatePayable, isTrue);
    expect(w.isClosed, isFalse);
    expect(d.works.last.isClosed, isTrue);
    expect(d.works.last.willCreatePayable, isFalse);
  });

  test('Proxima etapa sugerida', () {
    expect(ProstheticStage.next(ProstheticStage.toSend), ProstheticStage.atLab);
    expect(
      ProstheticStage.next(ProstheticStage.atLab),
      ProstheticStage.received,
    );
    expect(ProstheticStage.next(ProstheticStage.trial), ProstheticStage.atLab);
    expect(
      ProstheticStage.next(ProstheticStage.received),
      ProstheticStage.installed,
    );
  });

  testWidgets('Cartoes desenham e abrem o historico', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = ProstheticListData.fromJson(_json);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final w in d.works) ProstheticCard(work: w, labs: d.labs),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Coroa metalocerâmica'), findsOneWidget);
    expect(find.text('Atrasados'), findsOneWidget);
    expect(find.text('Conta a pagar'), findsOneWidget);
    await tester.tap(find.text('Coroa metalocerâmica'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Moldagem enviada'), findsOneWidget);
  });
}
