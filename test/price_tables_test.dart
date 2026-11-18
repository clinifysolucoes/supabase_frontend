import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/budgets/domain/budget_models.dart';
import 'package:odonto_app/features/pricing/presentation/price_tables_tab.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _tables = [
  PriceTable.fromJson({
    'nr_price_table': 1,
    'vc_name': 'Particular Pinhais',
    'id_default': true,
    'it_status': 1,
    'items': [
      {'nr_procedure': 10, 'vl_price': 180},
    ],
  }),
  PriceTable.fromJson({
    'nr_price_table': 2,
    'vc_name': 'Campanha antiga',
    'it_status': 90,
  }),
];

void main() {
  test('Tabela de preco e orcamento com tabela', () {
    expect(_tables.first.priceOf(10), 180);
    expect(_tables.first.priceOf(11), isNull);
    expect(_tables.last.isActive, isFalse);
    final b = Budget.fromJson({
      'budget': {
        'nr_budget': 1,
        'nr_patient': 1,
        'dt_budget': '2030-03-01',
        'dt_valid': '2030-03-31',
        'nr_price_table': 1,
        'vc_price_table': 'Particular Pinhais',
      },
    });
    expect(b.nrPriceTable, 1);
    expect(b.vcPriceTable, 'Particular Pinhais');
  });

  testWidgets('Aba lista as tabelas', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          priceTablesProvider.overrideWith((ref) async => _tables),
          canCreateProvider.overrideWith((ref, code) => true),
          canUpdateProvider.overrideWith((ref, code) => true),
        ],
        child: const MaterialApp(home: Scaffold(body: PriceTablesTab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Particular Pinhais'), findsOneWidget);
    expect(find.textContaining(Strings.priceTableDefault), findsOneWidget);
    expect(find.text(Strings.priceTableNew), findsOneWidget);
  });
}
