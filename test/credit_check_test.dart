import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/credit/application/credit_controllers.dart';
import 'package:odonto_app/features/credit/domain/credit_models.dart';
import 'package:odonto_app/features/credit/presentation/credit_check_card.dart';
import 'package:odonto_app/l10n/strings.dart';

final _data = CreditCheckData.fromJson({
  'id_enabled': true,
  'id_can_check': true,
  'checks': [
    {
      'nr_check': 2,
      'it_provider': 2,
      'it_status': 2,
      'it_result': 2,
      'qt_score': 420,
      'qt_debts': 2,
      'vl_debts': 1530.46,
      'vc_user': 'Cris',
      'dh_created': '2030-01-10T12:00:00Z',
    },
    {
      'nr_check': 1,
      'it_provider': 1,
      'it_status': 9,
      'vc_error': 'CREDIT_NOT_CONFIGURED',
    },
  ],
});

Widget _app(CreditCheckData d) => ProviderScope(
  overrides: [creditCheckListProvider.overrideWith((ref, _) async => d)],
  child: const MaterialApp(home: Scaffold(body: CreditCheckCard(nrPatient: 1))),
);

void main() {
  test('Modelo da consulta', () {
    final c = _data.checks.first;
    expect(c.isDone && c.hasRestrictions, isTrue);
    expect(c.label, Strings.creditRestricted);
    expect(
      _data.checks.last.label,
      Strings.errorMessage('CREDIT_NOT_CONFIGURED', const {}),
    );
    expect(CreditProvider.label(2), 'SPC Brasil');
  });

  testWidgets('Card mostra as consultas e pede a autorizacao', (tester) async {
    await tester.pumpWidget(_app(_data));
    await tester.pumpAndSettle();
    expect(find.text(Strings.creditTitle), findsOneWidget);
    expect(find.text(Strings.creditRestricted), findsOneWidget);
    expect(find.textContaining('Score 420'), findsOneWidget);
    expect(find.textContaining('falta configurar'), findsOneWidget);

    await tester.tap(find.text(Strings.creditRun));
    await tester.pumpAndSettle();
    expect(find.text(Strings.creditConsent), findsOneWidget);
    // sem marcar a autorizacao o botao fica desligado
    final run = find.widgetWithText(FilledButton, Strings.creditRun);
    if (run.evaluate().isNotEmpty) {
      expect(tester.widget<FilledButton>(run).onPressed, isNull);
    }
  });

  testWidgets('Card some com a consulta desligada e sem historico', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const CreditCheckData()));
    await tester.pumpAndSettle();
    expect(find.text(Strings.creditTitle), findsNothing);
  });
}
