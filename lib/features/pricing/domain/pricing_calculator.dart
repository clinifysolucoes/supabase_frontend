import 'pricing_models.dart';

/// Entrada da formula (percentuais em pontos: 4 = 4%).
class PricingInput {
  const PricingInput({
    this.vlMaterial = 0,
    this.vlLab = 0,
    this.qtMinutes = 0,
    this.vlStructureHour = 0,
    this.vlProfessionalHour = 0,
    this.pcCard = 0,
    this.pcCommission = 0,
    this.pcFees = 0,
    this.itTaxRegime = TaxRegime.pf,
    this.pcTax = 0,
    this.pcProfit = 0,
    this.vlCurrentPrice,
  });

  final double vlMaterial;
  final double vlLab;
  final double qtMinutes;
  final double vlStructureHour;
  final double vlProfessionalHour;
  final double pcCard;
  final double pcCommission;
  final double pcFees;
  final int itTaxRegime;
  final double pcTax;
  final double pcProfit;

  /// Valor cobrado hoje (opcional): gera o lucro atual e o [PriceStatus].
  final double? vlCurrentPrice;
}

/// Copia fiel de `od.fn_pricing_calc` para a simulacao ao vivo na tela.
/// O banco continua sendo a fonte oficial (procedure_list recalcula sempre);
/// `test/pricing_calculator_test.dart` usa o mesmo exemplo de
/// `tests/06_pricing.sql` do repositorio supabase.
///
///   estrutura    = minutos / 60 x custo da estrutura por hora
///   profissional = minutos / 60 x hora clinica
///   custo direto = materiais + laboratorio + estrutura + profissional
///   s = cartao + comissao + taxas    m = lucro    r = IR   (fracoes)
///   PJ: preco = custo / (1 - s - r - m)                 (IR sobre o faturamento)
///   PF: preco = (1 - r) x custo / ((1 - r)(1 - s) - m)  (IR sobre o lucro)
///   preco minimo = mesma formula com m = 0
///   valor cobrado C: lucro atual = C - custo - C x s - IR(C)
///     IR(C) PJ = C x r    PF = r x max(0, C - custo - C x s)
///     situacao: abaixo do custo < abaixo do minimo < abaixo do sugerido < ok
abstract final class PricingCalculator {
  static PricingResult calculate(PricingInput i) {
    final regime = i.itTaxRegime == TaxRegime.pj ? TaxRegime.pj : TaxRegime.pf;
    final vlStructure = round2(i.qtMinutes / 60 * i.vlStructureHour);
    final vlProfessional = round2(i.qtMinutes / 60 * i.vlProfessionalHour);
    final vlDirect = round2(
      i.vlMaterial + i.vlLab + vlStructure + vlProfessional,
    );

    final s = (i.pcCard + i.pcCommission + i.pcFees) / 100;
    final m = i.pcProfit / 100;
    final r = i.pcTax / 100;

    final double div;
    final double divMin;
    if (regime == TaxRegime.pj) {
      div = 1 - s - r - m;
      divMin = 1 - s - r;
    } else {
      div = (1 - r) * (1 - s) - m;
      divMin = (1 - r) * (1 - s);
    }
    final pcTotal = round2((s + m + r) * 100);

    if (div <= 0 || divMin <= 0) {
      final cur = _current(i.vlCurrentPrice, vlDirect, s, r, regime);
      return PricingResult(
        vlMaterial: round2(i.vlMaterial),
        vlLab: round2(i.vlLab),
        vlStructure: vlStructure,
        vlProfessional: vlProfessional,
        vlDirectCost: vlDirect,
        pcTotal: pcTotal,
        itTaxRegime: regime,
        idValid: false,
        vlCurrentPrice: cur.price,
        vlCurrentProfit: cur.profit,
        pcCurrentProfit: cur.pcProfit,
        itPriceStatus: cur.price != null && cur.price! < vlDirect
            ? PriceStatus.belowCost
            : PriceStatus.none,
      );
    }

    final double price;
    final double priceMin;
    if (regime == TaxRegime.pj) {
      price = round2(vlDirect / div);
      priceMin = round2(vlDirect / divMin);
    } else {
      price = round2((1 - r) * vlDirect / div);
      priceMin = round2((1 - r) * vlDirect / divMin);
    }
    final vlCard = round2(price * i.pcCard / 100);
    final vlCommission = round2(price * i.pcCommission / 100);
    final vlFees = round2(price * i.pcFees / 100);
    final vlTax = regime == TaxRegime.pj
        ? round2(price * r)
        : round2(r * (price - vlDirect - price * s));
    final vlProfit = round2(
      price - vlDirect - vlCard - vlCommission - vlFees - vlTax,
    );

    final cur = _current(i.vlCurrentPrice, vlDirect, s, r, regime);
    final c = cur.price;
    final status = c == null
        ? PriceStatus.none
        : c < vlDirect
        ? PriceStatus.belowCost
        : c < priceMin
        ? PriceStatus.belowMin
        : c < price
        ? PriceStatus.belowSuggested
        : PriceStatus.ok;

    return PricingResult(
      vlMaterial: round2(i.vlMaterial),
      vlLab: round2(i.vlLab),
      vlStructure: vlStructure,
      vlProfessional: vlProfessional,
      vlDirectCost: vlDirect,
      vlPrice: price,
      vlPriceMin: priceMin,
      vlCard: vlCard,
      vlCommission: vlCommission,
      vlFees: vlFees,
      vlTax: vlTax,
      vlProfit: vlProfit,
      pcProfitReal: price == 0 ? 0 : round2(vlProfit / price * 100),
      pcTotal: pcTotal,
      itTaxRegime: regime,
      idValid: true,
      vlCurrentPrice: c,
      vlCurrentProfit: cur.profit,
      pcCurrentProfit: cur.pcProfit,
      vlCurrentDiff: c == null ? null : round2(c - price),
      itPriceStatus: status,
    );
  }

  /// Lucro que sobra com o valor cobrado hoje (mesma conta do banco).
  static ({double? price, double? profit, double? pcProfit}) _current(
    double? current,
    double vlDirect,
    double s,
    double r,
    int regime,
  ) {
    if (current == null) return (price: null, profit: null, pcProfit: null);
    final c = round2(current);
    final tax = regime == TaxRegime.pj
        ? round2(c * r)
        : round2(r * _max0(c - vlDirect - c * s));
    final profit = round2(round2(c - vlDirect - c * s) - tax);
    return (
      price: c,
      profit: profit,
      pcProfit: c == 0 ? null : round2(profit / c * 100),
    );
  }

  static double _max0(double x) => x < 0 ? 0 : x;

  /// Custo por unidade de uso = preco da embalagem / (rendimento x (1 - perda)).
  static double unitCost(double packagePrice, double yield, double pcWaste) {
    final effective = yield * (1 - pcWaste / 100);
    if (effective <= 0) return 0;
    return round4(packagePrice / effective);
  }

  /// Custo mensal = fixas + variaveis + anuais / 12 + publicidade.
  static double monthlyCost(Iterable<ClinicExpense> expenses) =>
      round2(expenses.fold<double>(0, (sum, e) => sum + e.vlMonthly));

  /// Custo da estrutura por hora produtiva.
  static double structureHour({
    required double monthlyCost,
    required int rooms,
    required double hoursWeek,
    required double weeksMonth,
    required double pcOccupancy,
  }) {
    final productive = rooms * hoursWeek * weeksMonth * pcOccupancy / 100;
    if (productive <= 0) return 0;
    return round2(monthlyCost / productive);
  }

  /// Soma das taxas adicionais ativas (pontos percentuais).
  static double activeFees(Iterable<PricingFee> fees) =>
      fees.where((f) => f.idActive).fold<double>(0, (s, f) => s + f.pcRate);

  /// Arredondamento "metade para longe do zero", como o `round(x, 2)` do Postgres.
  static double round2(double x) => _round(x, 100);

  static double round4(double x) => _round(x, 10000);

  static double _round(double x, int factor) {
    final scaled = x * factor;
    final nudge = scaled >= 0 ? 1e-9 : -1e-9;
    return (scaled + nudge).round() / factor;
  }
}
