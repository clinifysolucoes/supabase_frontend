import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/budgets/application/budget_controllers.dart';
import 'package:odonto_app/features/budgets/data/budget_pdf.dart';
import 'package:odonto_app/features/budgets/domain/budget_models.dart';
import 'package:odonto_app/features/budgets/presentation/budgets_page.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _json = {
  'budget': {
    'nr_budget': 7,
    'nr_patient': 3,
    'vc_patient': 'Ana Orc',
    'vc_patient_cpf': '52998224725',
    'vc_professional': 'Dra. Ana',
    'vc_title': 'Reabilitação',
    'dt_budget': '2030-03-04',
    'dt_valid': '2030-04-03',
    'vl_gross': 5500,
    'vl_discount': 275,
    'pc_discount': 5,
    'vl_total': 5225,
    'qt_installments': 3,
    'it_payment_method': 2,
    'it_status': 2,
  },
  'items': [
    {
      'nr_item': 1,
      'nr_procedure': 4,
      'vc_description': 'Implante unitário',
      'vc_tooth': '16',
      'qt_quantity': 2,
      'vl_unit': 2500,
      'vl_total': 5000,
    },
    {
      'nr_item': 2,
      'vc_description': 'Clareamento',
      'qt_quantity': 1,
      'vl_unit': 500,
      'vl_total': 500,
    },
  ],
  'entries': <dynamic>[],
  'issuer': {'vc_name': 'Clínica', 'vc_city': 'Curitiba', 'vc_state': 'PR'},
  'pc_max_discount': 10,
  'permission': {'id_update': true, 'id_approve_discount': false},
};

void main() {
  test('Budget le orcamento, itens e permissoes', () {
    final b = Budget.fromJson(_json);
    expect(b.title, 'Reabilitação');
    expect(b.items, hasLength(2));
    expect(b.items.first.vlTotal, 5000);
    expect(b.itStatus, BudgetStatus.pending);
    expect(b.isEditable, isTrue);
    expect(b.canApproveDiscount, isFalse);
    expect(b.items.first.toJson()['nr_procedure'], 4);
    expect(b.items.last.toJson().containsKey('nr_procedure'), isFalse);
  });

  test('PDF do orcamento e gerado', () async {
    final bytes = await BudgetPdf.build(Budget.fromJson(_json));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(BudgetPdf.fileName(Budget.fromJson(_json)), 'orcamento_7');
  });

  testWidgets('lista mostra o orcamento com a situacao', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetsProvider.overrideWith(
            (ref, nr) async => BudgetListData.fromJson({
              'budgets': [
                {
                  'nr_budget': 7,
                  'nr_patient': 3,
                  'vc_patient': 'Ana Orc',
                  'vc_title': 'Reabilitação',
                  'dt_budget': '2030-03-04',
                  'dt_valid': '2030-04-03',
                  'vl_total': 5225,
                  'it_status': 1,
                  'qt_items': 2,
                },
              ],
            }),
          ),
          canCreateProvider.overrideWith((ref, code) => true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(useGoogleFonts: false),
          home: const Scaffold(
            body: BudgetList(nrPatient: 3, vcPatient: 'Ana Orc'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reabilitação'), findsOneWidget);
    expect(find.text(Strings.budgetOpen), findsOneWidget);
    expect(find.text(Strings.budgetNew), findsOneWidget);
    expect(find.textContaining('5.225,00'), findsOneWidget);
  });
}
