import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/budget_repository.dart';
import '../domain/budget_models.dart';

/// Filtro e busca da tela Orcamentos.
final budgetFilterProvider = StateProvider.autoDispose<BudgetFilter>(
  (_) => BudgetFilter.all,
);
final budgetSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Orcamentos da filial ([nrPatient] null) ou de um paciente.
final budgetsProvider = FutureProvider.autoDispose.family<BudgetListData, int?>(
  (ref, nrPatient) async {
    final c = ref.watch(currentCompanyProvider);
    final b = ref.watch(currentBranchNumberProvider);
    if (c == null || b == null) return const BudgetListData();
    return ref
        .read(budgetRepositoryProvider)
        .list(
          nrCompany: c,
          nrBranch: b,
          nrPatient: nrPatient,
          filter: nrPatient == null
              ? ref.watch(budgetFilterProvider)
              : BudgetFilter.all,
          search: nrPatient == null ? ref.watch(budgetSearchProvider) : null,
        );
  },
);

/// Escritas dos orcamentos: chamam a RPC e recarregam as listas.
class BudgetActions {
  BudgetActions(this._ref);

  final Ref _ref;

  ({int c, int b}) get _branch {
    final c = _ref.read(currentCompanyProvider);
    final b = _ref.read(currentBranchNumberProvider);
    if (c == null || b == null) throw StateError('branch');
    return (c: c, b: b);
  }

  BudgetRepository get _repo => _ref.read(budgetRepositoryProvider);

  Future<Budget> get(int nrBudget) {
    final x = _branch;
    return _repo.get(nrCompany: x.c, nrBranch: x.b, nrBudget: nrBudget);
  }

  Future<Budget> save(int? nrBudget, Map<String, dynamic> fields) async {
    final x = _branch;
    final r = await _repo.save(
      nrCompany: x.c,
      nrBranch: x.b,
      nrBudget: nrBudget,
      fields: fields,
    );
    _ref.invalidate(budgetsProvider);
    return r;
  }

  Future<Budget> status(
    int nrBudget,
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final x = _branch;
    final r = await _repo.status(
      nrCompany: x.c,
      nrBranch: x.b,
      nrBudget: nrBudget,
      action: action,
      extra: extra,
    );
    _ref.invalidate(budgetsProvider);
    return r;
  }
}

final budgetActionsProvider = Provider<BudgetActions>(BudgetActions.new);
