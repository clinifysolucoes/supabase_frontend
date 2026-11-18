import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/aligners/application/aligner_controllers.dart';
import 'package:odonto_app/features/aligners/domain/aligner_models.dart';
import 'package:odonto_app/features/aligners/presentation/aligners_page.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _data = AlignerListData.fromJson({
  'cases': [
    {
      'nr_case': 1,
      'nr_patient': 1,
      'vc_patient': 'Lia AL',
      'vc_professional': 'Dra. Orto',
      'vc_system': 'ClearTek',
      'vc_case_number': 'CT-123',
      'qt_aligners': 20,
      'qt_current': 2,
      'qt_days_change': 10,
      'dt_start': '2030-01-01',
      'dt_forecast': '2030-07-20',
      'it_status': 3,
      'vc_pending': 'Aguardando o setup',
      'events': [
        {'nr_event': 2, 'it_status': 3, 'qt_current': 2, 'vc_text': 'Setup'},
        {'nr_event': 1, 'it_status': 1, 'qt_current': 0},
      ],
    },
  ],
  'totals': {
    'qt_started': 0,
    'qt_pending_clinic': 0,
    'qt_pending_company': 1,
    'qt_treatment': 0,
    'qt_finished': 0,
  },
});

void main() {
  test('Modelo do caso', () {
    final c = _data.cases.single;
    expect(c.status, AlignerStatus.pendingCompany);
    expect(c.status.isPending, isTrue);
    expect(c.progress, 0.1);
    expect(c.events.first.vcText, 'Setup');
    expect(_data.totals[AlignerStatus.pendingCompany], 1);
    expect(AlignerStatus.of(99), AlignerStatus.started);
  });

  testWidgets('Tela lista os casos e abre o caso', (tester) async {
    tester.view.physicalSize = const Size(1300, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alignerListProvider.overrideWith((ref) async => _data),
          canReadProvider.overrideWith((ref, code) => true),
          canCreateProvider.overrideWith((ref, code) => true),
          canUpdateProvider.overrideWith((ref, code) => true),
        ],
        child: const MaterialApp(home: AlignersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Lia AL'), findsOneWidget);
    expect(find.text(Strings.alignerProgress(2, 20)), findsOneWidget);
    expect(find.text('Aguardando o setup'), findsOneWidget);
    await tester.tap(find.text('Lia AL'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.alignerHistory), findsOneWidget);
    expect(find.text(Strings.alignerPending), findsOneWidget);
  });
}
