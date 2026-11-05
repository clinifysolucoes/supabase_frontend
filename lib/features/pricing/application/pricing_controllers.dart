import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/pricing_repository.dart';
import '../domain/pricing_models.dart';

/// Aba Parametros: parametros, resumo, despesas e taxas da filial atual.
class PricingParamsController
    extends AutoDisposeAsyncNotifier<PricingParamsData?> {
  @override
  Future<PricingParamsData?> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    return ref
        .read(pricingRepositoryProvider)
        .params(nrCompany: nrCompany, nrBranch: nrBranch);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> save({
    PricingParams? params,
    List<ClinicExpense>? expenses,
    List<PricingFee>? fees,
  }) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(pricingRepositoryProvider)
        .saveParams(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          params: params,
          expenses: expenses,
          fees: fees,
        );
    ref.invalidate(proceduresProvider);
    ref.invalidate(specialtyProceduresProvider);
    await refresh();
  }
}

final pricingParamsProvider =
    AsyncNotifierProvider.autoDispose<
      PricingParamsController,
      PricingParamsData?
    >(PricingParamsController.new);

/// Filtros da aba Materiais.
class MaterialFilters {
  const MaterialFilters({this.search = '', this.includeInactive = false});

  final String search;
  final bool includeInactive;

  MaterialFilters copyWith({String? search, bool? includeInactive}) =>
      MaterialFilters(
        search: search ?? this.search,
        includeInactive: includeInactive ?? this.includeInactive,
      );
}

final materialFiltersProvider = StateProvider.autoDispose<MaterialFilters>(
  (_) => const MaterialFilters(),
);

class MaterialsController extends AutoDisposeAsyncNotifier<List<MaterialItem>> {
  @override
  Future<List<MaterialItem>> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    final filters = ref.watch(materialFiltersProvider);
    if (nrCompany == null || nrBranch == null) return const [];
    return ref
        .read(pricingRepositoryProvider)
        .materials(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          includeInactive: filters.includeInactive,
          search: filters.search,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int?> create(MaterialDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    final nr = await ref
        .read(pricingRepositoryProvider)
        .createMaterial(nrCompany: nrCompany, nrBranch: nrBranch, draft: draft);
    ref.invalidate(proceduresProvider);
    ref.invalidate(specialtyProceduresProvider);
    await refresh();
    return nr;
  }

  Future<void> updateMaterial(int nrMaterial, MaterialDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(pricingRepositoryProvider)
        .updateMaterial(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrMaterial: nrMaterial,
          draft: draft,
        );
    ref.invalidate(proceduresProvider);
    ref.invalidate(specialtyProceduresProvider);
    await refresh();
  }

  /// Pesquisa de preco de mercado (nao altera o estado).
  Future<PriceLookupResult> lookupPrice(String query) {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) {
      return Future.value(PriceLookupResult(vcQuery: query));
    }
    return ref
        .read(pricingRepositoryProvider)
        .lookupPrice(nrCompany: nrCompany, nrBranch: nrBranch, query: query);
  }
}

final materialsProvider =
    AsyncNotifierProvider.autoDispose<MaterialsController, List<MaterialItem>>(
      MaterialsController.new,
    );

/// Catalogo ATIVO completo (sem filtro), para escolher materiais no procedimento.
final materialCatalogProvider = FutureProvider.autoDispose<List<MaterialItem>>((
  ref,
) async {
  final nrCompany = ref.watch(currentCompanyProvider);
  final nrBranch = ref.watch(currentBranchNumberProvider);
  if (nrCompany == null || nrBranch == null) return const [];
  // recarrega quando a lista filtrada muda (criou/alterou material)
  ref.watch(materialsProvider);
  return ref
      .read(pricingRepositoryProvider)
      .materials(nrCompany: nrCompany, nrBranch: nrBranch);
});

/// Filtros da aba Procedimentos.
class ProcedureFilters {
  const ProcedureFilters({
    this.search = '',
    this.nrSpecialty,
    this.includeInactive = false,
    this.itTaxRegime,
  });

  final String search;
  final int? nrSpecialty;
  final bool includeInactive;

  /// Simulacao: null = regime dos parametros.
  final int? itTaxRegime;

  ProcedureFilters copyWith({
    String? search,
    int? nrSpecialty,
    bool clearSpecialty = false,
    bool? includeInactive,
    int? itTaxRegime,
    bool clearRegime = false,
  }) => ProcedureFilters(
    search: search ?? this.search,
    nrSpecialty: clearSpecialty ? null : (nrSpecialty ?? this.nrSpecialty),
    includeInactive: includeInactive ?? this.includeInactive,
    itTaxRegime: clearRegime ? null : (itTaxRegime ?? this.itTaxRegime),
  );
}

final procedureFiltersProvider = StateProvider.autoDispose<ProcedureFilters>(
  (_) => const ProcedureFilters(),
);

class ProceduresController
    extends AutoDisposeAsyncNotifier<ProcedureListData?> {
  @override
  Future<ProcedureListData?> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    final filters = ref.watch(procedureFiltersProvider);
    if (nrCompany == null || nrBranch == null) return null;
    return ref
        .read(pricingRepositoryProvider)
        .procedures(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          includeInactive: filters.includeInactive,
          search: filters.search,
          nrSpecialty: filters.nrSpecialty,
          itTaxRegime: filters.itTaxRegime,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int?> create(ProcedureDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    final nr = await ref
        .read(pricingRepositoryProvider)
        .createProcedure(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          draft: draft,
        );
    ref.invalidate(materialsProvider);
    ref.invalidate(specialtiesProvider);
    await refresh();
    return nr;
  }

  Future<void> updateProcedure(int nrProcedure, ProcedureDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(pricingRepositoryProvider)
        .updateProcedure(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrProcedure: nrProcedure,
          draft: draft,
        );
    ref.invalidate(materialsProvider);
    ref.invalidate(specialtiesProvider);
    await refresh();
  }

  /// Troca so a lista de materiais do procedimento.
  Future<void> updateMaterials(
    int nrProcedure,
    List<ProcedureMaterial> materials,
  ) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(pricingRepositoryProvider)
        .updateProcedureMaterials(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrProcedure: nrProcedure,
          materials: materials,
        );
    ref.invalidate(materialsProvider);
    ref.invalidate(specialtiesProvider);
    ref.invalidate(specialtyProceduresProvider);
    await refresh();
  }
}

final proceduresProvider =
    AsyncNotifierProvider.autoDispose<ProceduresController, ProcedureListData?>(
      ProceduresController.new,
    );

/// Aba Especialidades: mostrar as inativas tambem?
final specialtyShowInactiveProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);

class SpecialtiesController extends AutoDisposeAsyncNotifier<List<Specialty>> {
  @override
  Future<List<Specialty>> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    final includeInactive = ref.watch(specialtyShowInactiveProvider);
    if (nrCompany == null || nrBranch == null) return const [];
    return ref
        .read(pricingRepositoryProvider)
        .specialties(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          includeInactive: includeInactive,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int?> create(SpecialtyDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    final nr = await ref
        .read(pricingRepositoryProvider)
        .createSpecialty(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          draft: draft,
        );
    await refresh();
    return nr;
  }

  Future<void> updateSpecialty(int nrSpecialty, SpecialtyDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(pricingRepositoryProvider)
        .updateSpecialty(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrSpecialty: nrSpecialty,
          draft: draft,
        );
    // o lucro da especialidade muda o preco dos procedimentos dela
    ref.invalidate(proceduresProvider);
    await refresh();
  }
}

final specialtiesProvider =
    AsyncNotifierProvider.autoDispose<SpecialtiesController, List<Specialty>>(
      SpecialtiesController.new,
    );

/// Especialidades ATIVAS (sem filtro), para escolher no procedimento.
final specialtyCatalogProvider = FutureProvider.autoDispose<List<Specialty>>((
  ref,
) async {
  final nrCompany = ref.watch(currentCompanyProvider);
  final nrBranch = ref.watch(currentBranchNumberProvider);
  if (nrCompany == null || nrBranch == null) return const [];
  // recarrega quando a aba Especialidades muda (criou/alterou)
  ref.watch(specialtiesProvider);
  return ref
      .read(pricingRepositoryProvider)
      .specialties(nrCompany: nrCompany, nrBranch: nrBranch);
});

/// Todos os procedimentos ativos (sem filtro) para a aba Especialidades:
/// contagem de alertas por especialidade e a lista ao abrir uma delas.
final specialtyProceduresProvider =
    FutureProvider.autoDispose<ProcedureListData?>((ref) async {
      final nrCompany = ref.watch(currentCompanyProvider);
      final nrBranch = ref.watch(currentBranchNumberProvider);
      if (nrCompany == null || nrBranch == null) return null;
      // recarrega quando as especialidades mudam (lucro altera o preco);
      // procedimentos e parametros invalidam este provider ao salvar
      ref.watch(specialtiesProvider);
      return ref
          .read(pricingRepositoryProvider)
          .procedures(nrCompany: nrCompany, nrBranch: nrBranch);
    });

/// Sugestoes do auto complete do cadastro de procedimento, por especialidade
/// (null = sem especialidade: catalogo inteiro e todos os cadastrados).
final procedureSuggestionsProvider = FutureProvider.autoDispose
    .family<ProcedureSuggestions, int?>((ref, nrSpecialty) async {
      final nrCompany = ref.watch(currentCompanyProvider);
      final nrBranch = ref.watch(currentBranchNumberProvider);
      if (nrCompany == null || nrBranch == null) {
        return const ProcedureSuggestions();
      }
      return ref
          .read(pricingRepositoryProvider)
          .suggestProcedures(
            nrCompany: nrCompany,
            nrBranch: nrBranch,
            nrSpecialty: nrSpecialty,
          );
    });
