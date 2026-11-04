import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/pricing_models.dart';

/// Campos editaveis de um material (od.material_save).
class MaterialDraft {
  const MaterialDraft({
    required this.vcName,
    this.vcPackage,
    this.vlPackagePrice = 0,
    this.qtYield = 1,
    this.vcUnit,
    this.pcWaste = 0,
    this.itPriceSource = PriceSource.manual,
    this.vcPriceSource,
    this.itStatus,
  });

  final String vcName;
  final String? vcPackage;
  final double vlPackagePrice;
  final double qtYield;
  final String? vcUnit;
  final double pcWaste;
  final int itPriceSource;
  final String? vcPriceSource;

  /// Somente na alteracao (1 ativo | 90 inativo).
  final int? itStatus;

  Map<String, dynamic> toJson() => {
    'vc_name': vcName,
    'vc_package': vcPackage,
    'vl_package_price': vlPackagePrice,
    'qt_yield': qtYield,
    'vc_unit': vcUnit,
    'pc_waste': pcWaste,
    'it_price_source': itPriceSource,
    'vc_price_source': vcPriceSource,
    if (itStatus != null) 'it_status': itStatus,
  };
}

/// Campos editaveis de uma especialidade (od.specialty_save).
class SpecialtyDraft {
  const SpecialtyDraft({required this.vcName, this.pcProfit, this.itStatus});

  final String vcName;

  /// Lucro desejado (null = padrao da filial).
  final double? pcProfit;

  /// Somente na alteracao (1 ativa | 90 inativa).
  final int? itStatus;

  Map<String, dynamic> toJson() => {
    'vc_name': vcName,
    'pc_profit': pcProfit,
    if (itStatus != null) 'it_status': itStatus,
  };
}

/// Campos editaveis de um procedimento (od.procedure_save).
class ProcedureDraft {
  const ProcedureDraft({
    this.vcCode,
    required this.vcName,
    this.nrSpecialty,
    this.qtMinutes = 0,
    this.vlLabCost = 0,
    this.vlMaterialOther = 0,
    this.vlCurrentPrice,
    this.pcCommission,
    this.pcProfit,
    this.itStatus,
    this.materials = const [],
  });

  final String? vcCode;
  final String vcName;
  final int? nrSpecialty;
  final double qtMinutes;
  final double vlLabCost;
  final double vlMaterialOther;
  final double? vlCurrentPrice;
  final double? pcCommission;
  final double? pcProfit;
  final int? itStatus;
  final List<ProcedureMaterial> materials;

  Map<String, dynamic> toJson() => {
    'vc_code': vcCode,
    'vc_name': vcName,
    'nr_specialty': nrSpecialty,
    'qt_minutes': qtMinutes,
    'vl_lab_cost': vlLabCost,
    'vl_material_other': vlMaterialOther,
    'vl_current_price': vlCurrentPrice,
    'pc_commission': pcCommission,
    'pc_profit': pcProfit,
    if (itStatus != null) 'it_status': itStatus,
    'materials': [for (final m in materials) m.toJson()],
  };
}

/// RPCs da tela de precificacao (schema `ad`, dados em `od`) e a Edge Function de preco de mercado.
class PricingRepository {
  PricingRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<PricingParamsData> params({
    required int nrCompany,
    required int nrBranch,
  }) async {
    final json = await _gateway.rpc('pricing_param_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
    });
    return PricingParamsData.fromJson(json);
  }

  Future<void> saveParams({
    required int nrCompany,
    required int nrBranch,
    PricingParams? params,
    List<ClinicExpense>? expenses,
    List<PricingFee>? fees,
  }) async {
    await _gateway.rpc('pricing_param_save', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      if (params != null) 'params': params.toJson(),
      if (expenses != null) 'expenses': [for (final e in expenses) e.toJson()],
      if (fees != null) 'fees': [for (final f in fees) f.toJson()],
    });
  }

  Future<List<MaterialItem>> materials({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
    String? search,
  }) async {
    final json = await _gateway.rpc('material_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'id_include_inactive': includeInactive,
      if (search != null && search.trim().isNotEmpty) 'vc_search': search,
    });
    final items = json['materials'];
    if (items is! List) return const [];
    return [
      for (final m in items)
        MaterialItem.fromJson((m as Map).cast<String, dynamic>()),
    ];
  }

  Future<int> createMaterial({
    required int nrCompany,
    required int nrBranch,
    required MaterialDraft draft,
  }) async {
    final json = await _gateway.rpc('material_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...draft.toJson(),
    });
    return (json['nr_material'] as num).toInt();
  }

  Future<void> updateMaterial({
    required int nrCompany,
    required int nrBranch,
    required int nrMaterial,
    required MaterialDraft draft,
  }) async {
    await _gateway.rpc('material_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_material': nrMaterial,
      ...draft.toJson(),
    });
  }

  Future<List<Specialty>> specialties({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async {
    final json = await _gateway.rpc('specialty_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'id_include_inactive': includeInactive,
    });
    final items = json['specialties'];
    if (items is! List) return const [];
    return [
      for (final s in items)
        Specialty.fromJson((s as Map).cast<String, dynamic>()),
    ];
  }

  Future<int> createSpecialty({
    required int nrCompany,
    required int nrBranch,
    required SpecialtyDraft draft,
  }) async {
    final json = await _gateway.rpc('specialty_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...draft.toJson(),
    });
    return (json['nr_specialty'] as num).toInt();
  }

  Future<void> updateSpecialty({
    required int nrCompany,
    required int nrBranch,
    required int nrSpecialty,
    required SpecialtyDraft draft,
  }) async {
    await _gateway.rpc('specialty_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_specialty': nrSpecialty,
      ...draft.toJson(),
    });
  }

  Future<ProcedureListData> procedures({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
    String? search,
    int? nrSpecialty,
    int? itTaxRegime,
  }) async {
    final json = await _gateway.rpc('procedure_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'id_include_inactive': includeInactive,
      if (search != null && search.trim().isNotEmpty) 'vc_search': search,
      if (nrSpecialty != null) 'nr_specialty': nrSpecialty,
      if (itTaxRegime != null) 'it_tax_regime': itTaxRegime,
    });
    return ProcedureListData.fromJson(json);
  }

  Future<int> createProcedure({
    required int nrCompany,
    required int nrBranch,
    required ProcedureDraft draft,
  }) async {
    final json = await _gateway.rpc('procedure_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      ...draft.toJson(),
    });
    return (json['nr_procedure'] as num).toInt();
  }

  Future<void> updateProcedure({
    required int nrCompany,
    required int nrBranch,
    required int nrProcedure,
    required ProcedureDraft draft,
  }) async {
    await _gateway.rpc('procedure_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_procedure': nrProcedure,
      ...draft.toJson(),
    });
  }

  /// Pesquisa de preco de mercado (Edge Function material-price-lookup).
  /// Nao grava nada: o usuario escolhe a oferta e salva o material.
  Future<PriceLookupResult> lookupPrice({
    required int nrCompany,
    required int nrBranch,
    required String query,
  }) async {
    final json = await _gateway.invokeFunction('material-price-lookup', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'vc_query': query.trim(),
    });
    return PriceLookupResult.fromJson(json);
  }
}

final pricingRepositoryProvider = Provider<PricingRepository>(
  (ref) => PricingRepository(ref.watch(supabaseGatewayProvider)),
);
