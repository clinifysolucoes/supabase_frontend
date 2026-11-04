import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/pricing/application/pricing_controllers.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';
import 'package:odonto_app/features/pricing/presentation/specialties_tab.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

class _FakeSpecialties extends SpecialtiesController {
  @override
  Future<List<Specialty>> build() async => const [
    Specialty(nrSpecialty: 1, vcName: 'Clínica Geral', qtProcedures: 2),
    Specialty(nrSpecialty: 2, vcName: 'Implante', pcProfit: 20),
  ];
}

Map<String, dynamic> _proc(int nr, String name, int specialty, int status) => {
  'nr_procedure': nr,
  'vc_name': name,
  'nr_specialty': specialty,
  'vc_specialty': 'Clínica Geral',
  'qt_minutes': 60,
  'vl_current_price': 100,
  'it_status': 1,
  'pricing': {
    'vl_direct_cost': 150,
    'vl_price': 300,
    'vl_price_min': 187.5,
    'id_valid': true,
    'vl_current_price': 100,
    'vl_current_profit': -60,
    'it_price_status': status,
  },
  'alerts': [if (status == PriceStatus.belowCost) 'PRICE_BELOW_COST'],
};

final _data = ProcedureListData(
  procedures: [
    Procedure.fromJson(_proc(1, 'Profilaxia', 1, PriceStatus.belowCost)),
    Procedure.fromJson(_proc(2, 'Restauração', 1, PriceStatus.ok)),
  ],
  params: const PricingParams(nrCompany: 1, nrBranch: 1),
  summary: const PricingSummary(),
);

Widget _app(Size size) => ProviderScope(
  overrides: [
    specialtiesProvider.overrideWith(_FakeSpecialties.new),
    specialtyProceduresProvider.overrideWith((ref) async => _data),
    canCreateProvider.overrideWith((ref, code) => true),
    canUpdateProvider.overrideWith((ref, code) => true),
    materialCatalogProvider.overrideWith((ref) async => const []),
    specialtyCatalogProvider.overrideWith(
      (ref) async => const [
        Specialty(nrSpecialty: 1, vcName: 'Clínica Geral'),
        Specialty(nrSpecialty: 2, vcName: 'Implante', pcProfit: 20),
      ],
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(useGoogleFonts: false),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: const Scaffold(body: SpecialtiesTab()),
    ),
  ),
);

void main() {
  for (final size in const [Size(1280, 800), Size(390, 800)]) {
    testWidgets('grade de especialidades e procedimentos ($size)', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(size));
      await tester.pumpAndSettle();

      expect(find.text(Strings.newSpecialty), findsOneWidget);
      expect(find.text('Clínica Geral'), findsOneWidget);
      expect(find.text('Implante'), findsOneWidget);
      expect(
        find.text('1 · ${PriceStatus.label(PriceStatus.belowCost)}'),
        findsOneWidget,
      );

      await tester.tap(find.text('Clínica Geral'));
      await tester.pumpAndSettle();

      expect(find.text(Strings.newProcedure), findsOneWidget);
      expect(find.text('Profilaxia'), findsOneWidget);
      expect(
        find.text(PriceStatus.label(PriceStatus.belowCost)),
        findsOneWidget,
      );

      await tester.tap(find.text(Strings.backToSpecialties));
      await tester.pumpAndSettle();
      expect(find.text(Strings.newSpecialty), findsOneWidget);
    });
  }

  testWidgets('formulario do procedimento mostra o alerta do valor cobrado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const Size(1280, 900)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clínica Geral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profilaxia'));
    await tester.pumpAndSettle();

    // 60 min x (estrutura 0 + hora 0) e sem material: custo direto 0 no
    // simulador; cobrado 100 >= sugerido -> ok
    expect(find.text(Strings.editProcedure), findsOneWidget);
    expect(find.text(Strings.specialty), findsWidgets);
    expect(
      find.textContaining(
        '${Strings.priceCheckTitle}: R\$ 100,00',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(PriceStatus.label(PriceStatus.ok)), findsWidgets);
  });

  testWidgets(
    'janela pequena: Salvar visivel sem rolar e titulo do preco inteiro',
    (tester) async {
      tester.view.physicalSize = const Size(800, 675);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const Size(800, 675)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clínica Geral'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profilaxia'));
      await tester.pumpAndSettle();

      // rodape fixo: o botao esta na tela e responde ao toque
      expect(find.text(Strings.save).hitTestable(), findsOneWidget);
      // o titulo do quadro do valor cobrado nao quebra letra por letra
      final title = find.textContaining(
        Strings.priceCheckTitle,
        findRichText: true,
      );
      expect(title, findsWidgets);
      final box = tester.getSize(title.last);
      expect(
        box.height,
        lessThan(100),
        reason: 'titulo com no maximo 3 linhas',
      );
    },
  );
}
