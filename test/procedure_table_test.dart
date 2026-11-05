import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/pricing/application/pricing_controllers.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';
import 'package:odonto_app/features/pricing/presentation/procedure_materials_dialog.dart';
import 'package:odonto_app/features/pricing/presentation/procedures_tab.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

Procedure _proc(int nr, String name, String? specialty, {List? materials}) =>
    Procedure.fromJson({
      'nr_procedure': nr,
      'vc_name': name,
      'vc_specialty': specialty,
      'qt_minutes': 30,
      'it_status': 1,
      'materials': materials ?? const [],
      'pricing': {
        'vl_direct_cost': 50,
        'vl_price': 120,
        'vl_price_min': 80,
        'id_valid': true,
      },
    });

class _FakeProcedures extends ProceduresController {
  final saved = <(int, List<ProcedureMaterial>)>[];

  @override
  Future<ProcedureListData?> build() async => null;

  @override
  Future<void> updateMaterials(
    int nrProcedure,
    List<ProcedureMaterial> materials,
  ) async {
    saved.add((nrProcedure, materials));
  }
}

void main() {
  test(
    'agrupa por especialidade em ordem alfabetica, sem especialidade no fim',
    () {
      final groups = groupBySpecialty([
        _proc(1, 'A', 'Ortodontia'),
        _proc(2, 'B', null),
        _proc(3, 'C', 'endodontia'),
        _proc(4, 'D', 'Ortodontia'),
      ]);
      expect(groups.map((g) => g.name), ['endodontia', 'Ortodontia', null]);
      expect(groups[1].items.map((p) => p.nrProcedure), [1, 4]);
    },
  );

  late _FakeProcedures fake;

  Widget app(List<Procedure> items, {Map<String, GlobalKey>? keys}) {
    fake = _FakeProcedures();
    return ProviderScope(
      overrides: [
        proceduresProvider.overrideWith(() => fake),
        canUpdateProvider.overrideWith((ref, code) => true),
        materialCatalogProvider.overrideWith(
          (ref) async => [
            MaterialItem.fromJson({
              'nr_material': 9,
              'vc_name': 'Luva',
              'vc_unit': 'par',
              'vl_unit_cost': 0.5,
            }),
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: Scaffold(
          body: ProcedureTable(items: items, groupKeys: keys, onTap: (_) {}),
        ),
      ),
    );
  }

  testWidgets('cabecalho fixo: a lista rola e o titulo das colunas fica', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app([
        for (var i = 0; i < 30; i++)
          _proc(i + 1, 'Proc $i', i < 15 ? 'Clínica Geral' : 'Prótese'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clínica Geral'), findsOneWidget);
    expect(find.text(Strings.proceduresCount(15)), findsOneWidget);

    final header = find.byKey(const Key('procedure-table-header'));
    final before = tester.getTopLeft(header);
    await tester.drag(find.text('Proc 3'), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      find.text('Proc 0').hitTestable(),
      findsNothing,
      reason: 'a lista rolou',
    );
    expect(tester.getTopLeft(header), before);
    expect(find.text(Strings.procedureName).hitTestable(), findsOneWidget);
  });

  testWidgets('botao de materiais: lista, edita e salva so os materiais', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app([
        _proc(
          7,
          'Profilaxia',
          'Clínica Geral',
          materials: [
            {
              'nr_material': 3,
              'vc_name': 'Pasta profilática',
              'vc_unit': 'g',
              'qt_used': 2,
              'vl_unit_cost': 1.5,
            },
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(Strings.procedureMaterials));
    await tester.pumpAndSettle();
    expect(find.text('Pasta profilática'), findsOneWidget);
    expect(find.text('R\$ 3,00'), findsWidgets);

    await tester.tap(find.text(Strings.editMaterials));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, Strings.quantityUsed),
      '4',
    );
    await tester.pumpAndSettle();
    expect(find.text('R\$ 6,00'), findsWidgets);
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    final (nr, materials) = fake.saved.single;
    expect(nr, 7);
    expect(materials.single.toJson(), {'nr_material': 3, 'qt_used': 4.0});
    expect(find.text(Strings.materialsSaved), findsOneWidget);
  });

  testWidgets('cadastro: Adicionar materiais inclui do catalogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<ProcedureMaterial>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialCatalogProvider.overrideWith(
            (ref) async => [
              MaterialItem.fromJson({
                'nr_material': 9,
                'vc_name': 'Luva',
                'vc_unit': 'par',
                'vl_unit_cost': 0.5,
              }),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(useGoogleFonts: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await ProcedureMaterialsPicker.show(
                      context,
                      materials: const [],
                      title: 'Profilaxia',
                      adding: true,
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
    expect(find.text(Strings.addMaterials), findsOneWidget);
    await tester.tap(find.text(Strings.addMaterial));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luva').last);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, Strings.quantityUsed),
      findsOneWidget,
    );
    await tester.tap(find.text(Strings.confirm));
    await tester.pumpAndSettle();
    expect(result!.single.toJson(), {'nr_material': 9, 'qt_used': 1.0});
  });

  test('posicao de cada grupo: titulos de 40 e linhas de 64', () {
    final items = [
      for (var i = 0; i < 5; i++) _proc(i + 1, 'A$i', 'Clínica Geral'),
      _proc(9, 'B', 'Prótese'),
    ];
    expect(groupOffset(items, 'Clínica Geral'), 0);
    expect(groupOffset(items, 'Prótese'), 40 + 5 * 64);
  });

  testWidgets('ir para especialidade: o seletor rola ate o grupo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proceduresProvider.overrideWith(_ListProcedures.new),
          canCreateProvider.overrideWith((ref, code) => true),
          canUpdateProvider.overrideWith((ref, code) => true),
          specialtyCatalogProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(useGoogleFonts: false),
          home: const Scaffold(body: ProceduresTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Prótese'), findsNothing, reason: 'ainda nao montado');
    await tester.tap(find.text(Strings.jumpToSpecialty));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prótese · 10'));
    await tester.pumpAndSettle();
    expect(find.text('Prótese').hitTestable(), findsOneWidget);
    expect(find.text(Strings.procedureName).hitTestable(), findsOneWidget);
  });
}

class _ListProcedures extends ProceduresController {
  @override
  Future<ProcedureListData?> build() async => ProcedureListData(
    procedures: [
      for (var i = 0; i < 40; i++)
        _proc(i + 1, 'Proc $i', i < 30 ? 'Clínica Geral' : 'Prótese'),
    ],
    params: const PricingParams(nrCompany: 1, nrBranch: 1),
    summary: const PricingSummary(),
  );
}
