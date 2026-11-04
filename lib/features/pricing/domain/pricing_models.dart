import '../../../l10n/strings.dart';

/// Regime do imposto de renda usado no preco (od.pricing_param.it_tax_regime).
abstract final class TaxRegime {
  /// Pessoa fisica: IR incide sobre o lucro (carne-leao).
  static const pf = 1;

  /// Pessoa juridica: tributos incidem sobre o faturamento (Simples / Presumido).
  static const pj = 2;

  static String label(int regime) =>
      regime == pj ? Strings.taxRegimePj : Strings.taxRegimePf;
}

/// Tipo da despesa (od.clinic_expense.it_type).
abstract final class ExpenseType {
  static const fixed = 1;
  static const variable = 2;
  static const annual = 3;
  static const marketing = 4;
  static const all = [fixed, variable, annual, marketing];

  static String label(int type) => switch (type) {
    fixed => Strings.expenseFixed,
    variable => Strings.expenseVariable,
    annual => Strings.expenseAnnual,
    marketing => Strings.expenseMarketing,
    _ => '-',
  };
}

/// Origem do preco do material (od.material.it_price_source).
abstract final class PriceSource {
  static const manual = 1;
  static const market = 2;
}

/// Alertas de um procedimento (od.procedure_list.alerts).
abstract final class ProcedureAlert {
  static const noTime = 'NO_TIME';
  static const noMaterial = 'NO_MATERIAL';
  static const materialNoPrice = 'MATERIAL_NO_PRICE';
  static const percentTooHigh = 'PERCENT_TOO_HIGH';
  static const priceBelowCost = 'PRICE_BELOW_COST';
  static const priceBelowMin = 'PRICE_BELOW_MIN';
  static const priceBelowSuggested = 'PRICE_BELOW_SUGGESTED';

  /// Alertas do valor cobrado: a tela mostra no chip de situacao do preco.
  static const priceAlerts = {
    priceBelowCost,
    priceBelowMin,
    priceBelowSuggested,
  };

  static String label(String code) => switch (code) {
    noTime => Strings.alertNoTime,
    noMaterial => Strings.alertNoMaterial,
    materialNoPrice => Strings.alertMaterialNoPrice,
    percentTooHigh => Strings.alertPercentTooHigh,
    priceBelowCost => Strings.alertPriceBelowCost,
    priceBelowMin => Strings.alertPriceBelowMin,
    priceBelowSuggested => Strings.alertPriceBelowSuggested,
    _ => code,
  };
}

/// Situacao do valor cobrado hoje x calculo (od.fn_pricing_calc.it_price_status).
abstract final class PriceStatus {
  /// Sem valor cobrado informado.
  static const none = 0;

  /// Cobrado >= preco sugerido.
  static const ok = 1;

  /// Cobre custos e taxas, mas o lucro e menor que o desejado.
  static const belowSuggested = 2;

  /// Paga o custo direto, mas nao cobre cartao, comissao e impostos.
  static const belowMin = 3;

  /// Nao paga nem o custo direto (prejuizo).
  static const belowCost = 4;

  static String label(int status) => switch (status) {
    ok => Strings.priceStatusOk,
    belowSuggested => Strings.priceStatusBelowSuggested,
    belowMin => Strings.priceStatusBelowMin,
    belowCost => Strings.priceStatusBelowCost,
    _ => Strings.priceStatusNone,
  };

  static String? help(int status) => switch (status) {
    ok => Strings.priceStatusOkHelp,
    belowSuggested => Strings.priceStatusBelowSuggestedHelp,
    belowMin => Strings.priceStatusBelowMinHelp,
    belowCost => Strings.priceStatusBelowCostHelp,
    _ => null,
  };

  /// Status que pedem atencao do dentista.
  static bool isAlert(int status) => status >= belowSuggested;
}

/// od.specialty (aba Especialidades).
class Specialty {
  const Specialty({
    required this.nrSpecialty,
    required this.vcName,
    this.pcProfit,
    this.itStatus = 1,
    this.qtProcedures = 0,
  });

  factory Specialty.fromJson(Map<String, dynamic> json) => Specialty(
    nrSpecialty: _int(json['nr_specialty']),
    vcName: _str(json['vc_name']) ?? '',
    pcProfit: _doubleOrNull(json['pc_profit']),
    itStatus: _int(json['it_status'] ?? 1),
    qtProcedures: _int(json['qt_procedures'] ?? 0),
  );

  final int nrSpecialty;
  final String vcName;

  /// Lucro desejado da especialidade (null = padrao da filial).
  final double? pcProfit;
  final int itStatus;
  final int qtProcedures;

  bool get isActive => itStatus == 1;
}

/// od.pricing_param (percentuais em pontos: 4 = 4%).
class PricingParams {
  const PricingParams({
    required this.nrCompany,
    required this.nrBranch,
    this.qtRooms = 1,
    this.qtHoursWeek = 40,
    this.qtWeeksMonth = 4.33,
    this.pcOccupancy = 70,
    this.vlProfessionalHour = 0,
    this.pcCard = 4,
    this.pcCommission = 0,
    this.itTaxRegime = TaxRegime.pf,
    this.pcTaxPf = 27.5,
    this.pcTaxPj = 11.33,
    this.pcProfit = 30,
    this.vlStructureHourManual,
    this.idSaved = false,
  });

  factory PricingParams.fromJson(Map<String, dynamic> json) => PricingParams(
    nrCompany: _int(json['nr_company']),
    nrBranch: _int(json['nr_branch']),
    qtRooms: _int(json['qt_rooms'] ?? 1),
    qtHoursWeek: _double(json['qt_hours_week'] ?? 40),
    qtWeeksMonth: _double(json['qt_weeks_month'] ?? 4.33),
    pcOccupancy: _double(json['pc_occupancy'] ?? 70),
    vlProfessionalHour: _double(json['vl_professional_hour'] ?? 0),
    pcCard: _double(json['pc_card'] ?? 0),
    pcCommission: _double(json['pc_commission'] ?? 0),
    itTaxRegime: _int(json['it_tax_regime'] ?? TaxRegime.pf),
    pcTaxPf: _double(json['pc_tax_pf'] ?? 0),
    pcTaxPj: _double(json['pc_tax_pj'] ?? 0),
    pcProfit: _double(json['pc_profit'] ?? 0),
    vlStructureHourManual: _doubleOrNull(json['vl_structure_hour_manual']),
    idSaved: json['id_saved'] == true,
  );

  final int nrCompany;
  final int nrBranch;
  final int qtRooms;
  final double qtHoursWeek;
  final double qtWeeksMonth;
  final double pcOccupancy;
  final double vlProfessionalHour;
  final double pcCard;
  final double pcCommission;
  final int itTaxRegime;
  final double pcTaxPf;
  final double pcTaxPj;
  final double pcProfit;

  /// Custo da estrutura por hora digitado (null = usa o calculo das despesas).
  final double? vlStructureHourManual;
  final bool idSaved;

  /// IR do regime escolhido.
  double get pcTax => itTaxRegime == TaxRegime.pj ? pcTaxPj : pcTaxPf;

  double pcTaxFor(int regime) => regime == TaxRegime.pj ? pcTaxPj : pcTaxPf;

  /// Horas produtivas por mes = salas x horas/semana x semanas/mes x ocupacao.
  double get qtProductiveHours =>
      qtRooms * qtHoursWeek * qtWeeksMonth * pcOccupancy / 100;

  Map<String, dynamic> toJson() => {
    'qt_rooms': qtRooms,
    'qt_hours_week': qtHoursWeek,
    'qt_weeks_month': qtWeeksMonth,
    'pc_occupancy': pcOccupancy,
    'vl_professional_hour': vlProfessionalHour,
    'pc_card': pcCard,
    'pc_commission': pcCommission,
    'it_tax_regime': itTaxRegime,
    'pc_tax_pf': pcTaxPf,
    'pc_tax_pj': pcTaxPj,
    'pc_profit': pcProfit,
    'vl_structure_hour_manual': vlStructureHourManual,
  };

  PricingParams copyWith({
    int? qtRooms,
    double? qtHoursWeek,
    double? qtWeeksMonth,
    double? pcOccupancy,
    double? vlProfessionalHour,
    double? pcCard,
    double? pcCommission,
    int? itTaxRegime,
    double? pcTaxPf,
    double? pcTaxPj,
    double? pcProfit,
    double? vlStructureHourManual,
    bool clearStructureManual = false,
    bool? idSaved,
  }) => PricingParams(
    nrCompany: nrCompany,
    nrBranch: nrBranch,
    qtRooms: qtRooms ?? this.qtRooms,
    qtHoursWeek: qtHoursWeek ?? this.qtHoursWeek,
    qtWeeksMonth: qtWeeksMonth ?? this.qtWeeksMonth,
    pcOccupancy: pcOccupancy ?? this.pcOccupancy,
    vlProfessionalHour: vlProfessionalHour ?? this.vlProfessionalHour,
    pcCard: pcCard ?? this.pcCard,
    pcCommission: pcCommission ?? this.pcCommission,
    itTaxRegime: itTaxRegime ?? this.itTaxRegime,
    pcTaxPf: pcTaxPf ?? this.pcTaxPf,
    pcTaxPj: pcTaxPj ?? this.pcTaxPj,
    pcProfit: pcProfit ?? this.pcProfit,
    vlStructureHourManual: clearStructureManual
        ? null
        : (vlStructureHourManual ?? this.vlStructureHourManual),
    idSaved: idSaved ?? this.idSaved,
  );
}

/// Resumo calculado no banco (od.fn_pricing_context.summary).
class PricingSummary {
  const PricingSummary({
    this.vlFixedMonthly = 0,
    this.vlVariableMonthly = 0,
    this.vlAnnualEventual = 0,
    this.vlMarketingMonthly = 0,
    this.vlMonthlyCost = 0,
    this.qtHoursMonth = 0,
    this.qtProductiveHours = 0,
    this.vlStructureHour = 0,
    this.vlStructureHourCalc = 0,
    this.pcFees = 0,
    this.pcTax = 0,
    this.pcTotal = 0,
    this.itTaxRegime,
  });

  factory PricingSummary.fromJson(Map<String, dynamic> json) => PricingSummary(
    vlFixedMonthly: _double(json['vl_fixed_monthly'] ?? 0),
    vlVariableMonthly: _double(json['vl_variable_monthly'] ?? 0),
    vlAnnualEventual: _double(json['vl_annual_eventual'] ?? 0),
    vlMarketingMonthly: _double(json['vl_marketing_monthly'] ?? 0),
    vlMonthlyCost: _double(json['vl_monthly_cost'] ?? 0),
    qtHoursMonth: _double(json['qt_hours_month'] ?? 0),
    qtProductiveHours: _double(json['qt_productive_hours'] ?? 0),
    vlStructureHour: _double(json['vl_structure_hour'] ?? 0),
    vlStructureHourCalc: _double(
      json['vl_structure_hour_calc'] ?? json['vl_structure_hour'] ?? 0,
    ),
    pcFees: _double(json['pc_fees'] ?? 0),
    pcTax: _double(json['pc_tax'] ?? 0),
    pcTotal: _double(json['pc_total'] ?? 0),
    itTaxRegime: json['it_tax_regime'] == null
        ? null
        : _int(json['it_tax_regime']),
  );

  final double vlFixedMonthly;
  final double vlVariableMonthly;
  final double vlAnnualEventual;
  final double vlMarketingMonthly;
  final double vlMonthlyCost;
  final double qtHoursMonth;
  final double qtProductiveHours;

  /// Custo da estrutura por hora em vigor (manual, se informado).
  final double vlStructureHour;

  /// Custo da estrutura por hora calculado pelas despesas.
  final double vlStructureHourCalc;
  final double pcFees;
  final double pcTax;
  final double pcTotal;

  /// Regime usado na lista (procedure_list pode simular o outro).
  final int? itTaxRegime;
}

/// od.clinic_expense (linha editavel na aba Parametros).
class ClinicExpense {
  const ClinicExpense({
    this.nrExpense,
    required this.vcName,
    this.itType = ExpenseType.fixed,
    this.vlAmount = 0,
  });

  factory ClinicExpense.fromJson(Map<String, dynamic> json) => ClinicExpense(
    nrExpense: json['nr_expense'] == null ? null : _int(json['nr_expense']),
    vcName: _str(json['vc_name']) ?? '',
    itType: _int(json['it_type'] ?? ExpenseType.fixed),
    vlAmount: _double(json['vl_amount'] ?? 0),
  );

  final int? nrExpense;
  final String vcName;
  final int itType;
  final double vlAmount;

  /// Quanto pesa no custo MENSAL (anual / 12).
  double get vlMonthly =>
      itType == ExpenseType.annual ? vlAmount / 12 : vlAmount;

  Map<String, dynamic> toJson() => {
    'vc_name': vcName,
    'it_type': itType,
    'vl_amount': vlAmount,
  };

  ClinicExpense copyWith({String? vcName, int? itType, double? vlAmount}) =>
      ClinicExpense(
        nrExpense: nrExpense,
        vcName: vcName ?? this.vcName,
        itType: itType ?? this.itType,
        vlAmount: vlAmount ?? this.vlAmount,
      );
}

/// od.pricing_fee (taxa adicional sobre o preco).
class PricingFee {
  const PricingFee({
    this.nrFee,
    required this.vcName,
    this.vcHint,
    this.pcRate = 0,
    this.idActive = false,
  });

  factory PricingFee.fromJson(Map<String, dynamic> json) => PricingFee(
    nrFee: json['nr_fee'] == null ? null : _int(json['nr_fee']),
    vcName: _str(json['vc_name']) ?? '',
    vcHint: _str(json['vc_hint']),
    pcRate: _double(json['pc_rate'] ?? 0),
    idActive: json['id_active'] == true,
  );

  final int? nrFee;
  final String vcName;
  final String? vcHint;
  final double pcRate;
  final bool idActive;

  Map<String, dynamic> toJson() => {
    'vc_name': vcName,
    'vc_hint': vcHint,
    'pc_rate': pcRate,
    'id_active': idActive,
  };

  PricingFee copyWith({
    String? vcName,
    String? vcHint,
    double? pcRate,
    bool? idActive,
  }) => PricingFee(
    nrFee: nrFee,
    vcName: vcName ?? this.vcName,
    vcHint: vcHint ?? this.vcHint,
    pcRate: pcRate ?? this.pcRate,
    idActive: idActive ?? this.idActive,
  );
}

/// Permissao do usuario na tela (devolvida por pricing_param_get).
class PermissionFlags {
  const PermissionFlags({
    this.idRead = false,
    this.idCreate = false,
    this.idUpdate = false,
  });

  factory PermissionFlags.fromJson(Map<String, dynamic> json) =>
      PermissionFlags(
        idRead: json['id_read'] == true,
        idCreate: json['id_create'] == true,
        idUpdate: json['id_update'] == true,
      );

  final bool idRead;
  final bool idCreate;
  final bool idUpdate;
}

/// Resposta de od.pricing_param_get.
class PricingParamsData {
  const PricingParamsData({
    required this.params,
    required this.summary,
    required this.expenses,
    required this.fees,
    required this.permission,
  });

  factory PricingParamsData.fromJson(
    Map<String, dynamic> json,
  ) => PricingParamsData(
    params: PricingParams.fromJson(_map(json['params'])),
    summary: PricingSummary.fromJson(_map(json['summary'])),
    expenses: [
      for (final e in _list(json['expenses'])) ClinicExpense.fromJson(_map(e)),
    ],
    fees: [for (final f in _list(json['fees'])) PricingFee.fromJson(_map(f))],
    permission: PermissionFlags.fromJson(_map(json['permission'])),
  );

  final PricingParams params;
  final PricingSummary summary;
  final List<ClinicExpense> expenses;
  final List<PricingFee> fees;
  final PermissionFlags permission;
}

/// od.material + custo unitario calculado.
class MaterialItem {
  const MaterialItem({
    required this.nrMaterial,
    required this.vcName,
    this.vcPackage,
    this.vlPackagePrice = 0,
    this.qtYield = 1,
    this.vcUnit,
    this.pcWaste = 0,
    this.vlUnitCost = 0,
    this.itPriceSource = PriceSource.manual,
    this.vcPriceSource,
    this.dhPriceUpdated,
    this.itStatus = 1,
    this.qtProcedures = 0,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    nrMaterial: _int(json['nr_material']),
    vcName: _str(json['vc_name']) ?? '',
    vcPackage: _str(json['vc_package']),
    vlPackagePrice: _double(json['vl_package_price'] ?? 0),
    qtYield: _double(json['qt_yield'] ?? 1),
    vcUnit: _str(json['vc_unit']),
    pcWaste: _double(json['pc_waste'] ?? 0),
    vlUnitCost: _double(json['vl_unit_cost'] ?? 0),
    itPriceSource: _int(json['it_price_source'] ?? PriceSource.manual),
    vcPriceSource: _str(json['vc_price_source']),
    dhPriceUpdated: DateTime.tryParse(_str(json['dh_price_updated']) ?? ''),
    itStatus: _int(json['it_status'] ?? 1),
    qtProcedures: _int(json['qt_procedures'] ?? 0),
  );

  final int nrMaterial;
  final String vcName;
  final String? vcPackage;
  final double vlPackagePrice;
  final double qtYield;
  final String? vcUnit;
  final double pcWaste;
  final double vlUnitCost;
  final int itPriceSource;
  final String? vcPriceSource;
  final DateTime? dhPriceUpdated;
  final int itStatus;
  final int qtProcedures;

  bool get isActive => itStatus == 1;
  bool get isMarketPrice => itPriceSource == PriceSource.market;
  bool get hasPrice => vlPackagePrice > 0;
}

/// MaterialItem usado num procedimento (linha de od.procedure_material).
class ProcedureMaterial {
  const ProcedureMaterial({
    required this.nrMaterial,
    required this.vcName,
    this.vcUnit,
    required this.qtUsed,
    this.vlUnitCost = 0,
    this.vlLineCost = 0,
  });

  factory ProcedureMaterial.fromJson(Map<String, dynamic> json) =>
      ProcedureMaterial(
        nrMaterial: _int(json['nr_material']),
        vcName: _str(json['vc_name']) ?? '',
        vcUnit: _str(json['vc_unit']),
        qtUsed: _double(json['qt_used'] ?? 0),
        vlUnitCost: _double(json['vl_unit_cost'] ?? 0),
        vlLineCost: _double(json['vl_line_cost'] ?? 0),
      );

  factory ProcedureMaterial.fromMaterial(MaterialItem m, double qtUsed) =>
      ProcedureMaterial(
        nrMaterial: m.nrMaterial,
        vcName: m.vcName,
        vcUnit: m.vcUnit,
        qtUsed: qtUsed,
        vlUnitCost: m.vlUnitCost,
        vlLineCost: qtUsed * m.vlUnitCost,
      );

  final int nrMaterial;
  final String vcName;
  final String? vcUnit;
  final double qtUsed;
  final double vlUnitCost;
  final double vlLineCost;

  Map<String, dynamic> toJson() => {
    'nr_material': nrMaterial,
    'qt_used': qtUsed,
  };

  ProcedureMaterial copyWith({double? qtUsed}) => ProcedureMaterial(
    nrMaterial: nrMaterial,
    vcName: vcName,
    vcUnit: vcUnit,
    qtUsed: qtUsed ?? this.qtUsed,
    vlUnitCost: vlUnitCost,
    vlLineCost: (qtUsed ?? this.qtUsed) * vlUnitCost,
  );
}

/// Resultado da formula (od.fn_pricing_calc / PricingCalculator).
class PricingResult {
  const PricingResult({
    required this.vlMaterial,
    required this.vlLab,
    required this.vlStructure,
    required this.vlProfessional,
    required this.vlDirectCost,
    this.vlPrice,
    this.vlPriceMin,
    this.vlCard,
    this.vlCommission,
    this.vlFees,
    this.vlTax,
    this.vlProfit,
    this.pcProfitReal = 0,
    this.pcTotal = 0,
    this.itTaxRegime = TaxRegime.pf,
    this.idValid = true,
    this.vlCurrentPrice,
    this.vlCurrentProfit,
    this.pcCurrentProfit,
    this.vlCurrentDiff,
    this.itPriceStatus = PriceStatus.none,
  });

  factory PricingResult.fromJson(Map<String, dynamic> json) => PricingResult(
    vlMaterial: _double(json['vl_material'] ?? 0),
    vlLab: _double(json['vl_lab'] ?? 0),
    vlStructure: _double(json['vl_structure'] ?? 0),
    vlProfessional: _double(json['vl_professional'] ?? 0),
    vlDirectCost: _double(json['vl_direct_cost'] ?? 0),
    vlPrice: _doubleOrNull(json['vl_price']),
    vlPriceMin: _doubleOrNull(json['vl_price_min']),
    vlCard: _doubleOrNull(json['vl_card']),
    vlCommission: _doubleOrNull(json['vl_commission']),
    vlFees: _doubleOrNull(json['vl_fees']),
    vlTax: _doubleOrNull(json['vl_tax']),
    vlProfit: _doubleOrNull(json['vl_profit']),
    pcProfitReal: _double(json['pc_profit_real'] ?? 0),
    pcTotal: _double(json['pc_total'] ?? 0),
    itTaxRegime: _int(json['it_tax_regime'] ?? TaxRegime.pf),
    idValid: json['id_valid'] != false,
    vlCurrentPrice: _doubleOrNull(json['vl_current_price']),
    vlCurrentProfit: _doubleOrNull(json['vl_current_profit']),
    pcCurrentProfit: _doubleOrNull(json['pc_current_profit']),
    vlCurrentDiff: _doubleOrNull(json['vl_current_diff']),
    itPriceStatus: _int(json['it_price_status'] ?? PriceStatus.none),
  );

  final double vlMaterial;
  final double vlLab;
  final double vlStructure;
  final double vlProfessional;
  final double vlDirectCost;
  final double? vlPrice;
  final double? vlPriceMin;
  final double? vlCard;
  final double? vlCommission;
  final double? vlFees;
  final double? vlTax;
  final double? vlProfit;
  final double pcProfitReal;
  final double pcTotal;
  final int itTaxRegime;
  final bool idValid;

  /// Valor cobrado hoje e o lucro que sobra com ele.
  final double? vlCurrentPrice;
  final double? vlCurrentProfit;
  final double? pcCurrentProfit;

  /// Cobrado - sugerido (negativo = cobra menos que o sugerido).
  final double? vlCurrentDiff;

  /// [PriceStatus] do valor cobrado.
  final int itPriceStatus;
}

/// od.procedure com materiais, preco calculado e alertas.
class Procedure {
  const Procedure({
    required this.nrProcedure,
    this.vcCode,
    required this.vcName,
    this.nrSpecialty,
    this.vcSpecialty,
    this.qtMinutes = 0,
    this.vlLabCost = 0,
    this.vlMaterialOther = 0,
    this.vlCurrentPrice,
    this.pcCommission,
    this.pcProfit,
    this.itStatus = 1,
    this.materials = const [],
    this.pricing,
    this.alerts = const [],
  });

  factory Procedure.fromJson(Map<String, dynamic> json) => Procedure(
    nrProcedure: _int(json['nr_procedure']),
    vcCode: _str(json['vc_code']),
    vcName: _str(json['vc_name']) ?? '',
    nrSpecialty: json['nr_specialty'] == null
        ? null
        : _int(json['nr_specialty']),
    vcSpecialty: _str(json['vc_specialty']),
    qtMinutes: _double(json['qt_minutes'] ?? 0),
    vlLabCost: _double(json['vl_lab_cost'] ?? 0),
    vlMaterialOther: _double(json['vl_material_other'] ?? 0),
    vlCurrentPrice: _doubleOrNull(json['vl_current_price']),
    pcCommission: _doubleOrNull(json['pc_commission']),
    pcProfit: _doubleOrNull(json['pc_profit']),
    itStatus: _int(json['it_status'] ?? 1),
    materials: [
      for (final m in _list(json['materials']))
        ProcedureMaterial.fromJson(_map(m)),
    ],
    pricing: json['pricing'] is Map
        ? PricingResult.fromJson(_map(json['pricing']))
        : null,
    alerts: [for (final a in _list(json['alerts'])) a.toString()],
  );

  final int nrProcedure;
  final String? vcCode;
  final String vcName;
  final int? nrSpecialty;
  final String? vcSpecialty;
  final double qtMinutes;
  final double vlLabCost;
  final double vlMaterialOther;
  final double? vlCurrentPrice;
  final double? pcCommission;
  final double? pcProfit;
  final int itStatus;
  final List<ProcedureMaterial> materials;
  final PricingResult? pricing;
  final List<String> alerts;

  bool get isActive => itStatus == 1;

  /// [PriceStatus] do valor cobrado hoje.
  int get priceStatus => pricing?.itPriceStatus ?? PriceStatus.none;

  /// Alertas tecnicos (sem os do valor cobrado, que viram o chip de situacao).
  List<String> get setupAlerts => [
    for (final a in alerts)
      if (!ProcedureAlert.priceAlerts.contains(a)) a,
  ];

  /// Valor cobrado - preco sugerido (negativo = cobra menos que o sugerido;
  /// null quando algum dos dois falta).
  double? get priceDiff {
    final price = pricing?.vlPrice;
    final current = vlCurrentPrice;
    if (price == null || current == null) return null;
    return current - price;
  }

  String get displayName =>
      vcCode == null || vcCode!.isEmpty ? vcName : '$vcCode · $vcName';
}

/// Resposta de od.procedure_list.
class ProcedureListData {
  const ProcedureListData({
    required this.procedures,
    required this.params,
    required this.summary,
  });

  factory ProcedureListData.fromJson(Map<String, dynamic> json) =>
      ProcedureListData(
        procedures: [
          for (final p in _list(json['procedures']))
            Procedure.fromJson(_map(p)),
        ],
        params: PricingParams.fromJson(_map(json['params'])),
        summary: PricingSummary.fromJson(_map(json['summary'])),
      );

  final List<Procedure> procedures;
  final PricingParams params;
  final PricingSummary summary;
}

/// Oferta encontrada pela Edge Function material-price-lookup.
class PriceOffer {
  const PriceOffer({
    required this.vcStore,
    required this.vcTitle,
    required this.vlPrice,
    this.vcPackage,
    this.vcUrl,
  });

  factory PriceOffer.fromJson(Map<String, dynamic> json) => PriceOffer(
    vcStore: _str(json['vc_store']) ?? '',
    vcTitle: _str(json['vc_title']) ?? '',
    vlPrice: _double(json['vl_price'] ?? 0),
    vcPackage: _str(json['vc_package']),
    vcUrl: _str(json['vc_url']),
  );

  final String vcStore;
  final String vcTitle;
  final double vlPrice;
  final String? vcPackage;
  final String? vcUrl;
}

class PriceLookupResult {
  const PriceLookupResult({
    required this.vcQuery,
    this.vlSuggested,
    this.offers = const [],
  });

  factory PriceLookupResult.fromJson(Map<String, dynamic> json) =>
      PriceLookupResult(
        vcQuery: _str(json['vc_query']) ?? '',
        vlSuggested: _doubleOrNull(json['vl_suggested']),
        offers: [
          for (final o in _list(json['offers'])) PriceOffer.fromJson(_map(o)),
        ],
      );

  final String vcQuery;
  final double? vlSuggested;
  final List<PriceOffer> offers;
}

// --- helpers de parse (jsonb numerico pode chegar como int, double ou string)

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _str(dynamic value) => value?.toString();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<dynamic> _list(dynamic value) => value is List ? value : const [];
