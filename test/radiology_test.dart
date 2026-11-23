import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/radiology/application/radiology_controllers.dart';
import 'package:odonto_app/features/radiology/domain/radiology_models.dart';
import 'package:odonto_app/features/radiology/presentation/radiology_page.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _data = RadiologyListData.fromJson({
  'requests': [
    {
      'nr_request': 1,
      'nr_patient': 1,
      'vc_patient': 'Rui Raio',
      'nr_center': 1,
      'vc_center': 'Radio Imagem',
      'vc_professional': 'Dr. Rx',
      'dt_request': '2030-01-10',
      'ar_exams': ['Panorâmica', 'Tomografia Cone Beam'],
      'vc_region': '36, 37',
      'it_status': 4,
      'dt_done': '2030-01-12',
      'dt_report': '2030-01-15',
      'vc_report_url': 'https://portal.radio.local/laudo/123',
    },
  ],
  'centers': [
    {
      'nr_center': 1,
      'vc_name': 'Radio Imagem',
      'vc_phone': '4133334444',
      'it_integration': 1,
      'it_status': 1,
    },
    {'nr_center': 2, 'vc_name': 'Centro Dois', 'it_status': 90},
  ],
  'totals': {
    'qt_requested': 0,
    'qt_scheduled': 0,
    'qt_done': 0,
    'qt_report': 1,
  },
});

Widget _app() => ProviderScope(
  overrides: [
    radiologyListProvider.overrideWith((ref) async => _data),
    canReadProvider.overrideWith((ref, code) => true),
    canCreateProvider.overrideWith((ref, code) => true),
    canUpdateProvider.overrideWith((ref, code) => true),
  ],
  child: const MaterialApp(home: RadiologyPage()),
);

void main() {
  test('Modelo do pedido e dos centros', () {
    final r = _data.requests.single;
    expect(r.status, RadiologyStatus.report);
    expect(r.exams, ['Panorâmica', 'Tomografia Cone Beam']);
    expect(_data.totals[RadiologyStatus.report], 1);
    expect(_data.activeCenters.map((c) => c.vcName), ['Radio Imagem']);
    expect(RadiologyStatus.of(99), RadiologyStatus.requested);
  });

  testWidgets('Tela lista os pedidos, abre o pedido e os centros', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Rui Raio'), findsOneWidget);
    expect(
      find.textContaining('Panorâmica, Tomografia Cone Beam'),
      findsOneWidget,
    );
    expect(find.text('https://portal.radio.local/laudo/123'), findsOneWidget);

    await tester.tap(find.text('Rui Raio'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.rxEdit), findsOneWidget);
    expect(find.text(Strings.rxReportUrl), findsOneWidget);
    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.rxCenters));
    await tester.pumpAndSettle();
    expect(find.text('Radio Imagem'), findsWidgets);
    expect(find.textContaining('(41) 3333-4444'), findsOneWidget);
    expect(find.textContaining(Strings.statusInactive), findsOneWidget);
  });
}
