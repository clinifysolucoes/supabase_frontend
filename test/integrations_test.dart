import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/integrations/application/integration_controllers.dart';
import 'package:odonto_app/features/integrations/domain/integration_models.dart';
import 'package:odonto_app/features/integrations/presentation/integration_banner.dart';
import 'package:odonto_app/features/integrations/presentation/integrations_section.dart';
import 'package:odonto_app/l10n/strings.dart';

final _map = IntegrationStatusMap.fromJson({
  'items': {
    'email': {
      'configured': true,
      'implemented': true,
      'ready': true,
      'missing': <String>[],
    },
    'sms': {
      'configured': false,
      'implemented': true,
      'missing': ['ZENVIA_API_TOKEN', 'ZENVIA_FROM'],
    },
    'whatsapp': {
      'configured': false,
      'implemented': true,
      'missing': ['WHATSAPP_ENC_KEY'],
    },
    'credit': {'configured': true, 'implemented': false, 'missing': <String>[]},
    'invoice': {
      'configured': false,
      'implemented': false,
      'missing': ['INVOICE_API_KEY'],
    },
    'price_lookup': {
      'configured': true,
      'implemented': true,
      'missing': <String>[],
    },
  },
});

Widget _app(Widget child, [IntegrationStatusMap? map]) => ProviderScope(
  overrides: [
    integrationStatusProvider.overrideWith((ref) async => map ?? _map),
  ],
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  test('Situacao de cada integracao', () {
    expect(_map.of(IntegrationCode.email).state, IntegrationState.ready);
    expect(_map.of(IntegrationCode.sms).state, IntegrationState.pending);
    expect(_map.of(IntegrationCode.credit).state, IntegrationState.preparing);
    expect(
      IntegrationStatusMap.failed.of(IntegrationCode.email).state,
      IntegrationState.unknown,
    );
  });

  testWidgets('Aviso some quando pronto e aparece quando falta', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            IntegrationBanner(
              codes: [IntegrationCode.email],
              pendingText: 'EMAIL PENDENTE',
            ),
            IntegrationBanner(
              codes: [IntegrationCode.invoice],
              pendingText: 'NOTA PENDENTE',
            ),
            IntegrationBanner(
              codes: [IntegrationCode.credit],
              pendingText: 'CREDITO PENDENTE',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EMAIL PENDENTE'), findsNothing);
    expect(find.text('NOTA PENDENTE'), findsOneWidget);
    expect(find.text(Strings.intMissing('INVOICE_API_KEY')), findsOneWidget);
    // credito: chaves cadastradas mas adaptador nao escrito
    expect(find.text('CREDITO PENDENTE'), findsNothing);
    expect(find.text(Strings.intPreparingText), findsOneWidget);
  });

  testWidgets('Sem verificar mostra o aviso de nao verificado', (tester) async {
    await tester.pumpWidget(
      _app(
        const IntegrationBanner(
          codes: [IntegrationCode.email],
          pendingText: 'X',
        ),
        IntegrationStatusMap.failed,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Strings.intUnknownTitle), findsOneWidget);
  });

  testWidgets('Secao Integracoes lista tudo e abre a configuracao', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    IntegrationTarget? opened;
    await tester.pumpWidget(
      _app(IntegrationsSection(onOpen: (t) => opened = t)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final t in [
      Strings.intEmail,
      Strings.intSms,
      Strings.intReview,
      Strings.intWhatsapp,
      Strings.intCredit,
      Strings.intInvoice,
      Strings.intRadiology,
      Strings.intPrice,
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    // e-mail, avaliacao (por e-mail) e pesquisa de preco prontos
    expect(find.text(Strings.intReady), findsNWidgets(3));
    expect(find.text(Strings.intContract), findsOneWidget);
    expect(find.text(Strings.intPreparing), findsOneWidget);
    await tester.tap(find.text(Strings.intOpen).first);
    expect(opened, IntegrationTarget.notify);
  });
}
