import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/pricing/data/pricing_repository.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';

void main() {
  group('PricingParamsData', () {
    test(
      'parse de pricing_param_get (padroes, despesas, taxas, permissao)',
      () {
        final d = PricingParamsData.fromJson({
          'params': {
            'nr_company': 1,
            'nr_branch': 1,
            'qt_rooms': 2,
            'qt_hours_week': '40.00',
            'qt_weeks_month': 4,
            'pc_occupancy': 50,
            'vl_professional_hour': 60,
            'pc_card': 4,
            'pc_commission': 6,
            'it_tax_regime': 2,
            'pc_tax_pf': 27.5,
            'pc_tax_pj': 10,
            'pc_profit': 25,
            'id_saved': false,
          },
          'summary': {
            'vl_monthly_cost': 10000,
            'qt_hours_month': 320,
            'qt_productive_hours': 160,
            'vl_structure_hour': 62.5,
            'pc_fees': 5,
            'pc_tax': 10,
            'pc_total': 50,
          },
          'expenses': [
            {
              'nr_expense': null,
              'vc_name': 'Aluguel',
              'it_type': 1,
              'vl_amount': 0,
            },
            {
              'nr_expense': 2,
              'vc_name': '13º',
              'it_type': 3,
              'vl_amount': 2400,
            },
          ],
          'fees': [
            {
              'nr_fee': null,
              'vc_name': 'ISS',
              'vc_hint': 'x',
              'pc_rate': 5,
              'id_active': false,
            },
          ],
          'permission': {
            'id_read': true,
            'id_create': true,
            'id_update': false,
          },
        });
        expect(d.params.idSaved, isFalse);
        expect(d.params.qtHoursWeek, 40);
        expect(d.params.pcTax, 10);
        expect(d.params.pcTaxFor(TaxRegime.pf), 27.5);
        expect(d.params.qtProductiveHours, 160);
        expect(d.summary.vlStructureHour, 62.5);
        expect(d.expenses.last.vlMonthly, 200);
        expect(d.expenses.first.nrExpense, isNull);
        expect(d.fees.single.idActive, isFalse);
        expect(d.permission.idUpdate, isFalse);
        expect(d.params.toJson()['it_tax_regime'], 2);
        expect(d.params.copyWith(pcProfit: 30).toJson()['pc_profit'], 30);
        expect(d.params.vlStructureHourManual, isNull);
        expect(d.summary.vlStructureHourCalc, 62.5);
        final manual = d.params.copyWith(vlStructureHourManual: 70);
        expect(manual.toJson()['vl_structure_hour_manual'], 70);
        expect(
          manual
              .copyWith(clearStructureManual: true)
              .toJson()['vl_structure_hour_manual'],
          isNull,
        );
      },
    );
  });

  group('Procedure', () {
    final json = {
      'nr_procedure': 1,
      'vc_code': '1.0',
      'vc_name': 'Restauração 1 face',
      'nr_specialty': 2,
      'vc_specialty': 'Clínica Geral',
      'qt_minutes': 30,
      'vl_lab_cost': 20,
      'vl_material_other': 2,
      'vl_current_price': 150,
      'pc_commission': null,
      'pc_profit': null,
      'it_status': 1,
      'materials': [
        {
          'nr_material': 1,
          'vc_name': 'Luva',
          'vc_unit': 'par',
          'qt_used': 3,
          'vl_unit_cost': 2,
          'vl_line_cost': 6,
        },
      ],
      'pricing': {
        'vl_material': 10,
        'vl_lab': 20,
        'vl_structure': 31.25,
        'vl_professional': 30,
        'vl_direct_cost': 91.25,
        'vl_price': 182.5,
        'vl_price_min': 121.67,
        'vl_card': 7.3,
        'vl_commission': 10.95,
        'vl_fees': 9.13,
        'vl_tax': 18.25,
        'vl_profit': 45.62,
        'pc_profit_real': 25,
        'pc_total': 50,
        'it_tax_regime': 2,
        'id_valid': true,
        'vl_current_price': 150,
        'vl_current_profit': 19.45,
        'pc_current_profit': 12.97,
        'vl_current_diff': -32.5,
        'it_price_status': 2,
      },
      'alerts': ['NO_TIME', 'PRICE_BELOW_SUGGESTED'],
    };

    test('parse, displayName, priceDiff e alertas', () {
      final p = Procedure.fromJson(json);
      expect(p.displayName, '1.0 · Restauração 1 face');
      expect(p.priceDiff, -32.5);
      expect(p.nrSpecialty, 2);
      expect(p.vcSpecialty, 'Clínica Geral');
      expect(p.priceStatus, PriceStatus.belowSuggested);
      expect(p.pricing!.vlCurrentDiff, -32.5);
      expect(p.setupAlerts, ['NO_TIME']);
      expect(PriceStatus.isAlert(p.priceStatus), isTrue);
      expect(p.pcCommission, isNull);
      expect(p.materials.single.vlLineCost, 6);
      expect(p.pricing!.vlPrice, 182.5);
      expect(p.alerts, ['NO_TIME', 'PRICE_BELOW_SUGGESTED']);
      expect(
        ProcedureAlert.label('PRICE_BELOW_COST'),
        'Cobrado abaixo do custo',
      );
      expect(ProcedureAlert.label('NO_TIME'), 'Sem tempo');
    });

    test('preco invalido vem nulo', () {
      final p = Procedure.fromJson({
        ...json,
        'pricing': {'vl_direct_cost': 100, 'vl_price': null, 'id_valid': false},
      });
      expect(p.pricing!.idValid, isFalse);
      expect(p.pricing!.vlPrice, isNull);
      expect(p.priceDiff, isNull);
    });

    test('Specialty e SpecialtyDraft', () {
      final s = Specialty.fromJson({
        'nr_specialty': 3,
        'vc_name': 'Implante',
        'pc_profit': '20.00',
        'it_status': 1,
        'qt_procedures': 4,
      });
      expect(s.pcProfit, 20);
      expect(s.qtProcedures, 4);
      expect(s.isActive, isTrue);
      expect(
        Specialty.fromJson({'nr_specialty': 1, 'vc_name': 'X'}).pcProfit,
        isNull,
      );
      expect(const SpecialtyDraft(vcName: 'HOF').toJson(), {
        'vc_name': 'HOF',
        'pc_profit': null,
      });
      expect(
        const SpecialtyDraft(
          vcName: 'HOF',
          pcProfit: 20,
          itStatus: 90,
        ).toJson(),
        {'vc_name': 'HOF', 'pc_profit': 20, 'it_status': 90},
      );
    });

    test('ProcedureDraft e MaterialDraft para o save', () {
      final draft = ProcedureDraft(
        vcName: 'X',
        nrSpecialty: 5,
        qtMinutes: 30,
        materials: [
          ProcedureMaterial.fromMaterial(
            const MaterialItem(nrMaterial: 7, vcName: 'Luva', vlUnitCost: 2),
            3,
          ),
        ],
      ).toJson();
      expect(draft['materials'], [
        {'nr_material': 7, 'qt_used': 3},
      ]);
      expect(draft.containsKey('it_status'), isFalse);
      expect(draft['vc_code'], isNull);
      expect(draft['nr_specialty'], 5);

      final m = const MaterialDraft(
        vcName: 'Luva',
        vlPackagePrice: 100,
        qtYield: 50,
        itStatus: 90,
      ).toJson();
      expect(m['it_status'], 90);
      expect(m['it_price_source'], PriceSource.manual);
    });
  });

  group('MaterialItem e pesquisa de preco', () {
    test('parse do material', () {
      final m = MaterialItem.fromJson({
        'nr_material': 2,
        'vc_name': 'Resina',
        'vc_package': 'Seringa 4 g',
        'vl_package_price': 90,
        'qt_yield': 100,
        'vc_unit': '0,1 g',
        'pc_waste': 10,
        'vl_unit_cost': '1.0000',
        'it_price_source': 2,
        'vc_price_source': 'Loja',
        'dh_price_updated': '2026-10-14T10:00:00+00:00',
        'it_status': 1,
        'qt_procedures': 1,
      });
      expect(m.isMarketPrice, isTrue);
      expect(m.hasPrice, isTrue);
      expect(m.vlUnitCost, 1.0);
      expect(m.dhPriceUpdated?.toUtc().hour, 10);
    });

    test('parse da Edge Function', () {
      final r = PriceLookupResult.fromJson({
        'vc_query': 'luva',
        'vl_suggested': 38.5,
        'offers': [
          {
            'vc_store': 'Loja A',
            'vc_title': 'Luva M',
            'vl_price': 35,
            'vc_package': 'Caixa 100',
            'vc_url': 'https://a',
          },
          {'vc_store': 'Loja B', 'vc_title': 'Luva M', 'vl_price': 42},
        ],
      });
      expect(r.vlSuggested, 38.5);
      expect(r.offers.length, 2);
      expect(r.offers.last.vcUrl, isNull);
    });

    test('rotulos', () {
      expect(TaxRegime.label(TaxRegime.pj), 'Pessoa jurídica');
      expect(ExpenseType.label(ExpenseType.annual), 'Eventuais anuais');
    });
  });
}
