import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/invoice/application/invoice_controllers.dart';
import 'package:odonto_app/features/invoice/domain/invoice_models.dart';
import 'package:odonto_app/features/invoice/presentation/invoice_settings_section.dart';
import 'package:odonto_app/features/invoice/presentation/invoices_tab.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _data = InvoiceListData.fromJson({
  'invoices': [
    {
      'nr_invoice': 1,
      'nr_patient': 1,
      'vc_patient': 'Ana Nota',
      'it_status': 3,
      'vl_service': 350,
      'vl_iss': 12.25,
      'dt_competence': '2030-01-10',
      'vc_description': 'Serviços odontológicos prestados a Ana Nota.',
      'vc_taker_name': 'Ana Nota',
      'vc_taker_document': '52998224725',
      'vc_number': '2030/123',
      'vc_pdf_url': 'https://emissor.local/n/123.pdf',
    },
    {
      'nr_invoice': 2,
      'nr_patient': 2,
      'vc_patient': 'Beto Menor',
      'it_status': 8,
      'vl_service': 200,
      'vc_description': 'Serviços.',
      'vc_taker_name': 'Carla Mae',
      'vc_taker_document': '39053344705',
      'vc_error': 'INVOICE_NOT_CONFIGURED',
    },
  ],
  'totals': {
    'qt_draft': 0,
    'qt_processing': 0,
    'qt_issued': 1,
    'qt_error': 1,
    'vl_issued': 350,
  },
  'id_enabled': true,
  'missing': ['city_ibge'],
});

void main() {
  test('Modelos da nota fiscal', () {
    expect(_data.invoices.first.status, InvoiceStatus.issued);
    expect(_data.invoices.last.status.isOpen, isTrue);
    expect(_data.totals[InvoiceStatus.error], 1);
    expect(_data.isReady, isFalse);
    expect(invoiceMissingLabel('city_ibge'), Strings.nfMissingIbge);
    expect(InvoiceStatus.of(99), InvoiceStatus.draft);
    final s = InvoiceSettings.fromJson({
      'settings': {
        'id_enabled': true,
        'pc_iss': 3.5,
        'vc_service_code': '4.12',
      },
      'missing': ['address'],
      'permission': {'id_update': true},
    });
    expect(s.pcIss, 3.5);
    expect(s.canUpdate, isTrue);
  });

  testWidgets('Aba lista as notas, pendencias e acoes', (tester) async {
    tester.view.physicalSize = const Size(1300, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceListProvider.overrideWith((ref) async => _data),
          canReadProvider.overrideWith((ref, code) => true),
          canCreateProvider.overrideWith((ref, code) => true),
          canUpdateProvider.overrideWith((ref, code) => true),
        ],
        child: const MaterialApp(home: Scaffold(body: InvoicesTab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(Strings.nfSetupTitle), findsOneWidget);
    expect(find.textContaining('NFS-e 2030/123'), findsOneWidget);
    expect(find.textContaining('Carla Mae'), findsOneWidget);
    expect(find.text(Strings.nfResend), findsOneWidget);
    expect(find.text(Strings.nfCancel), findsOneWidget);
    expect(find.textContaining('ainda não contratado'), findsOneWidget);

    await tester.tap(find.text(Strings.nfNew));
    await tester.pumpAndSettle();
    expect(find.text(Strings.nfTakerHint), findsOneWidget);
  });

  testWidgets('Configuracao mostra o que falta', (tester) async {
    tester.view.physicalSize = const Size(1300, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceSettingsProvider.overrideWith(
            (ref) async => InvoiceSettings.fromJson({
              'settings': {'id_enabled': false},
              'missing': ['cnpj', 'settings'],
              'permission': {'id_update': true},
            }),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: InvoiceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining(Strings.nfMissingCnpj), findsOneWidget);
    expect(find.text(Strings.nfEnabled), findsOneWidget);
    expect(find.text(Strings.nfIbge), findsOneWidget);
  });
}
