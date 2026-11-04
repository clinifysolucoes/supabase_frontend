import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/pricing/domain/pricing_calculator.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';
import 'package:odonto_app/shared/formatters/numbers.dart';

/// Mesmo exemplo de tests/06_pricing.sql (repositorio supabase):
///   2 salas x 40 h x 4 semanas = 320 h; ocupacao 50% -> 160 h produtivas
///   despesas 8000 + 1000 + 2400/12 + 800 = 10000 -> estrutura 62,50/h
///   hora clinica 60; cartao 4 + comissao 6 + ISS 5 = 15%; lucro 25; PJ 10 / PF 27,5
///   procedimento: 30 min, lab 20, materiais 3x2 + 2x1 + outros 2 = 10
void main() {
  const base = PricingInput(
    vlMaterial: 10,
    vlLab: 20,
    qtMinutes: 30,
    vlStructureHour: 62.5,
    vlProfessionalHour: 60,
    pcCard: 4,
    pcCommission: 6,
    pcFees: 5,
    itTaxRegime: TaxRegime.pj,
    pcTax: 10,
    pcProfit: 25,
  );

  group('PricingCalculator', () {
    test('custo direto', () {
      final r = PricingCalculator.calculate(base);
      expect(r.vlStructure, 31.25);
      expect(r.vlProfessional, 30);
      expect(r.vlDirectCost, 91.25);
    });

    test('PJ: IR sobre o faturamento', () {
      final r = PricingCalculator.calculate(base);
      expect(r.idValid, isTrue);
      expect(r.vlPrice, 182.50);
      expect(r.vlPriceMin, 121.67);
      expect(r.vlCard, 7.30);
      expect(r.vlCommission, 10.95);
      expect(r.vlFees, 9.13);
      expect(r.vlTax, 18.25);
      expect(r.vlProfit, 45.62);
      expect(r.pcProfitReal, 25.0);
      expect(r.pcTotal, 50.0);
    });

    test('PF: IR sobre o lucro', () {
      final r = PricingCalculator.calculate(
        const PricingInput(
          vlMaterial: 10,
          vlLab: 20,
          qtMinutes: 30,
          vlStructureHour: 62.5,
          vlProfessionalHour: 60,
          pcCard: 4,
          pcCommission: 6,
          pcFees: 5,
          itTaxRegime: TaxRegime.pf,
          pcTax: 27.5,
          pcProfit: 25,
        ),
      );
      expect(r.vlPrice, 180.63);
      expect(r.pcProfitReal, 25.0);
      // IR = 27,5% x (preco - custo - 15% do preco)
      final base = r.vlPrice! - 91.25 - 0.15 * r.vlPrice!;
      expect((r.vlTax! - 0.275 * base).abs(), lessThan(0.02));
    });

    // Mesmo exemplo de tests/08_specialties.sql: custo direto 150, preco 250,
    // minimo 187,50 (PJ 10%, cartao + comissao 10%, lucro 20%).
    PricingResult current(double? price, {int regime = TaxRegime.pj}) =>
        PricingCalculator.calculate(
          PricingInput(
            vlMaterial: 30,
            qtMinutes: 60,
            vlStructureHour: 60,
            vlProfessionalHour: 60,
            pcCard: 4,
            pcCommission: 6,
            itTaxRegime: regime,
            pcTax: regime == TaxRegime.pj ? 10 : 27.5,
            pcProfit: 20,
            vlCurrentPrice: price,
          ),
        );

    test('valor cobrado: situacao e lucro atual', () {
      final ok = current(260);
      expect(ok.vlPrice, 250);
      expect(ok.vlPriceMin, 187.5);
      expect(ok.itPriceStatus, PriceStatus.ok);
      expect(ok.vlCurrentDiff, 10);
      expect(ok.vlCurrentProfit, 58);
      expect(ok.pcCurrentProfit, 22.31);

      expect(current(250).itPriceStatus, PriceStatus.ok);
      expect(current(200).itPriceStatus, PriceStatus.belowSuggested);
      expect(current(160).itPriceStatus, PriceStatus.belowMin);
      final loss = current(120);
      expect(loss.itPriceStatus, PriceStatus.belowCost);
      expect(loss.vlCurrentProfit, -54);
      // PF: IR sobre o lucro, que e negativo -> IR zero
      expect(current(120, regime: TaxRegime.pf).vlCurrentProfit, -42);
      final none = current(null);
      expect(none.itPriceStatus, PriceStatus.none);
      expect(none.vlCurrentProfit, isNull);
    });

    test('percentuais >= 100% invalidam o preco', () {
      final r = PricingCalculator.calculate(
        const PricingInput(
          vlMaterial: 100,
          pcCard: 4,
          pcCommission: 6,
          pcFees: 5,
          itTaxRegime: TaxRegime.pj,
          pcTax: 10,
          pcProfit: 90,
        ),
      );
      expect(r.idValid, isFalse);
      expect(r.vlPrice, isNull);
      expect(r.vlDirectCost, 100);
    });

    test('custo unitario, custo mensal e estrutura por hora', () {
      expect(PricingCalculator.unitCost(100, 50, 0), 2.0);
      expect(PricingCalculator.unitCost(90, 100, 10), 1.0);
      expect(PricingCalculator.unitCost(10, 0, 0), 0);
      expect(
        PricingCalculator.monthlyCost(const [
          ClinicExpense(
            vcName: 'Aluguel',
            itType: ExpenseType.fixed,
            vlAmount: 8000,
          ),
          ClinicExpense(
            vcName: 'Limpeza',
            itType: ExpenseType.variable,
            vlAmount: 1000,
          ),
          ClinicExpense(
            vcName: '13º',
            itType: ExpenseType.annual,
            vlAmount: 2400,
          ),
          ClinicExpense(
            vcName: 'Anúncios',
            itType: ExpenseType.marketing,
            vlAmount: 800,
          ),
        ]),
        10000,
      );
      expect(
        PricingCalculator.structureHour(
          monthlyCost: 10000,
          rooms: 2,
          hoursWeek: 40,
          weeksMonth: 4,
          pcOccupancy: 50,
        ),
        62.5,
      );
      expect(
        PricingCalculator.activeFees(const [
          PricingFee(vcName: 'ISS', pcRate: 5, idActive: true),
          PricingFee(vcName: 'Inadimplência', pcRate: 3, idActive: false),
        ]),
        5,
      );
    });

    test('arredondamento metade para cima como o Postgres', () {
      expect(PricingCalculator.round2(9.125), 9.13);
      expect(PricingCalculator.round2(1.005), 1.01);
      expect(PricingCalculator.round4(0.44444444), 0.4444);
    });
  });

  group('Numbers', () {
    test('parse pt-BR e en', () {
      expect(Numbers.parse('1.234,56'), 1234.56);
      expect(Numbers.parse('1234.56'), 1234.56);
      expect(Numbers.parse('12,5'), 12.5);
      expect(Numbers.parse('R\$ 10'), 10);
      expect(Numbers.parse('1.234'), 1234);
      expect(Numbers.parse(''), isNull);
      expect(Numbers.parse('abc'), isNull);
    });

    test('formatacao', () {
      expect(Numbers.money(1234.5), 'R\$ 1.234,50');
      expect(Numbers.money(null), '-');
      expect(Numbers.percent(12.5), '12,5%');
      expect(Numbers.percent(4, decimals: 2), '4%');
      expect(Numbers.qty(2.5), '2,5');
      expect(Numbers.minutes(90), '1h 30min');
      expect(Numbers.minutes(45), '45min');
      expect(Numbers.toField(4.33), '4,33');
      expect(Numbers.toField(40), '40');
      expect(Numbers.toField(null), '');
    });
  });
}
