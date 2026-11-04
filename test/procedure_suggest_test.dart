import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/pricing/application/pricing_controllers.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';
import 'package:odonto_app/features/pricing/presentation/procedure_form_dialog.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

/// Mesmo formato de ad.procedure_suggest (tests/09_procedure_suggest.sql).
final _json = {
  'templates': [
    {
      'nr_template': 21,
      'vc_specialty': 'Clínica Geral',
      'vc_code': '5.1',
      'vc_name': 'EXTRAÇÃO SIMPLES',
      'qt_minutes': 90,
      'vl_material_other': 60,
      'vl_lab_cost': 0,
      'vl_reference_price': null,
    },
    {
      'nr_template': 1,
      'vc_specialty': 'Clínica Geral',
      'vc_code': null,
      'vc_name': 'CLAREAMENTO CASEIRO (2 SERINGAS)',
      'qt_minutes': 60,
      'vl_material_other': 70,
      'vl_lab_cost': 0,
      'vl_reference_price': 650,
    },
  ],
  'procedures': [
    {
      'nr_procedure': 3,
      'vc_code': '9',
      'vc_name': 'Extração de siso',
      'vc_specialty': 'Clínica Geral',
      'qt_minutes': 120,
      'vl_lab_cost': 10,
      'vl_material_other': 5,
      'vl_current_price': 400,
      'pc_commission': null,
      'pc_profit': 35,
      'materials': [
        {
          'nr_material': 7,
          'vc_name': 'Luva',
          'vc_unit': 'par',
          'qt_used': 2,
          'vl_unit_cost': 0.4,
        },
      ],
    },
  ],
};

void main() {
  group('ProcedureSuggestions', () {
    final s = ProcedureSuggestions.fromJson(_json);

    test('parse do catalogo e dos cadastrados', () {
      expect(s.templates.first.isTemplate, isTrue);
      expect(s.templates.first.displayName, '5.1 · EXTRAÇÃO SIMPLES');
      expect(s.templates.last.vlPrice, 650);
      final p = s.procedures.single;
      expect(p.isTemplate, isFalse);
      expect(p.vlPrice, 400);
      expect(p.pcProfit, 35);
      expect(p.materials.single.vlLineCost, 0.8);
    });

    test('busca sem acento e sem maiusculas, catalogo primeiro', () {
      expect(foldText('  EXTRAÇÃO '), 'extracao');
      final r = s.search('extracao');
      expect(r.map((x) => x.vcName), ['EXTRAÇÃO SIMPLES', 'Extração de siso']);
      expect(s.search('5.1').single.vcName, 'EXTRAÇÃO SIMPLES');
      expect(s.search(''), isEmpty);
      expect(s.search('extra', limit: 1).length, 1);
    });
  });

  group('formulario: auto complete do nome', () {
    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canCreateProvider.overrideWith((ref, code) => true),
            canUpdateProvider.overrideWith((ref, code) => true),
            materialCatalogProvider.overrideWith((ref) async => const []),
            specialtyCatalogProvider.overrideWith(
              (ref) async => const [
                Specialty(nrSpecialty: 1, vcName: 'Clínica Geral'),
              ],
            ),
            procedureSuggestionsProvider.overrideWith(
              (ref, nrSpecialty) async => ProcedureSuggestions.fromJson(_json),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(useGoogleFonts: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => ProcedureFormDialog.show(
                    context,
                    params: const PricingParams(nrCompany: 1, nrBranch: 1),
                    summary: const PricingSummary(),
                    initialSpecialty: 1,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    TextField field(WidgetTester tester, String label) => tester.widget(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)),
    );

    testWidgets('item da planilha preenche os campos', (tester) async {
      await openForm(tester);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.procedureName),
          matching: find.byType(TextField),
        ),
        'clareamento',
      );
      await tester.pumpAndSettle();

      expect(find.text('CLAREAMENTO CASEIRO (2 SERINGAS)'), findsOneWidget);
      await tester.tap(find.text('CLAREAMENTO CASEIRO (2 SERINGAS)'));
      await tester.pumpAndSettle();

      expect(
        field(tester, Strings.procedureName).controller!.text,
        'CLAREAMENTO CASEIRO (2 SERINGAS)',
      );
      expect(field(tester, Strings.minutes).controller!.text, '60');
      expect(field(tester, Strings.materialOther).controller!.text, '70');
      expect(field(tester, Strings.currentPrice).controller!.text, '650');
    });

    testWidgets('procedimento cadastrado copia valores e materiais', (
      tester,
    ) async {
      await openForm(tester);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.procedureName),
          matching: find.byType(TextField),
        ),
        'siso',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('9 · Extração de siso'));
      await tester.pumpAndSettle();

      expect(
        field(tester, Strings.procedureName).controller!.text,
        'Extração de siso ${Strings.copySuffix}',
      );
      expect(field(tester, Strings.minutes).controller!.text, '120');
      expect(field(tester, Strings.profitOverride).controller!.text, '35');
      expect(find.text('Luva'), findsOneWidget);
    });
  });
}
