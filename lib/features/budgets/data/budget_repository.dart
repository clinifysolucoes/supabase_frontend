import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/budget_models.dart';

/// RPCs dos orcamentos (ad.budget_*).
class BudgetRepository {
  BudgetRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<BudgetListData> list({
    required int nrCompany,
    required int nrBranch,
    int? nrPatient,
    BudgetFilter filter = BudgetFilter.all,
    String? search,
  }) async => BudgetListData.fromJson(
    await _gateway.rpc('budget_list', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_patient': ?nrPatient,
      'vc_status': filter.code,
      if (search != null && search.isNotEmpty) 'vc_search': search,
    }),
  );

  Future<Budget> get({
    required int nrCompany,
    required int nrBranch,
    required int nrBudget,
  }) async => Budget.fromJson(
    await _gateway.rpc('budget_get', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_budget': nrBudget,
    }),
  );

  /// Cria ([nrBudget] null) ou altera.
  Future<Budget> save({
    required int nrCompany,
    required int nrBranch,
    int? nrBudget,
    required Map<String, dynamic> fields,
  }) async => Budget.fromJson(
    await _gateway.rpc('budget_save', {
      'vc_action': nrBudget == null ? 'I' : 'U',
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_budget': ?nrBudget,
      ...fields,
    }),
  );

  Future<Budget> status({
    required int nrCompany,
    required int nrBranch,
    required int nrBudget,
    required String action,
    Map<String, dynamic> extra = const {},
  }) async => Budget.fromJson(
    await _gateway.rpc('budget_status', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'nr_budget': nrBudget,
      'vc_action': action,
      ...extra,
    }),
  );
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(supabaseGatewayProvider)),
);
