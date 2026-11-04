import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../../../shared/formatters/dates.dart';
import '../domain/finance_models.dart';

/// Novo lancamento (ad.fin_entry_save, vc_action I).
class EntryDraft {
  const EntryDraft({
    required this.itKind,
    required this.nrCategory,
    required this.vcDescription,
    required this.vlAmount,
    required this.dtDue,
    this.dtCompetence,
    this.nrAccount,
    this.nrSupplier,
    this.nrPatient,
    this.itPaymentMethod,
    this.vcNotes,
    this.qtInstallments = 1,
    this.idRecurring = false,
    this.qtRepeat = 12,
    this.idPaid = false,
    this.dtPaid,
  });

  final int itKind;
  final int nrCategory;
  final String vcDescription;

  /// Total (dividido nas parcelas) ou o valor de cada repeticao.
  final double vlAmount;
  final DateTime dtDue;
  final DateTime? dtCompetence;
  final int? nrAccount;
  final int? nrSupplier;
  final int? nrPatient;
  final int? itPaymentMethod;
  final String? vcNotes;
  final int qtInstallments;
  final bool idRecurring;
  final int qtRepeat;
  final bool idPaid;
  final DateTime? dtPaid;

  Map<String, dynamic> toJson() => {
    'it_kind': itKind,
    'nr_category': nrCategory,
    'vc_description': vcDescription,
    'vl_amount': vlAmount,
    'dt_due': Dates.toIso(dtDue),
    if (dtCompetence != null) 'dt_competence': Dates.toIso(dtCompetence!),
    'nr_account': nrAccount,
    'nr_supplier': nrSupplier,
    'nr_patient': nrPatient,
    'it_payment_method': itPaymentMethod,
    'vc_notes': vcNotes,
    if (idRecurring) ...{
      'id_recurring': true,
      'qt_repeat': qtRepeat,
    } else
      'qt_installments': qtInstallments,
    if (idPaid) ...{
      'id_paid': true,
      if (dtPaid != null) 'dt_paid': Dates.toIso(dtPaid!),
    },
  };
}

/// RPCs da tela Financeiro (schema `ad`, dados em `od`).
class FinanceRepository {
  FinanceRepository(this._gateway);

  final SupabaseGateway _gateway;

  Map<String, dynamic> _branch(int nrCompany, int nrBranch) => {
    'nr_company': nrCompany,
    'nr_branch': nrBranch,
  };

  Future<void> setup({required int nrCompany, required int nrBranch}) =>
      _gateway.rpc('fin_setup', _branch(nrCompany, nrBranch));

  Future<FinCatalog> catalog({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async => FinCatalog.fromJson(
    await _gateway.rpc('fin_catalog', {
      ..._branch(nrCompany, nrBranch),
      'id_include_inactive': includeInactive,
    }),
  );

  /// Cadastro de conta, categoria ou fornecedor: [rpc] = fin_account_save,
  /// fin_category_save ou fin_supplier_save; [key] = nr_account etc. (null cria).
  Future<void> saveRegister({
    required int nrCompany,
    required int nrBranch,
    required String rpc,
    required String key,
    int? id,
    required Map<String, dynamic> fields,
  }) => _gateway.rpc(rpc, {
    ..._branch(nrCompany, nrBranch),
    'vc_action': id == null ? 'I' : 'U',
    if (id != null) key: id,
    ...fields,
  });

  Future<FinOverview> overview({
    required int nrCompany,
    required int nrBranch,
  }) async => FinOverview.fromJson(
    await _gateway.rpc('fin_overview', _branch(nrCompany, nrBranch)),
  );

  Future<FinEntryList> entries({
    required int nrCompany,
    required int nrBranch,
    required int itKind,
    required DateTime from,
    required DateTime to,
    EntryFilter status = EntryFilter.all,
    int? nrCategory,
    String? search,
  }) async => FinEntryList.fromJson(
    await _gateway.rpc('fin_entry_list', {
      ..._branch(nrCompany, nrBranch),
      'it_kind': itKind,
      'dt_from': Dates.toIso(from),
      'dt_to': Dates.toIso(to),
      'vc_status': status.name,
      if (nrCategory != null) 'nr_category': nrCategory,
      if (search != null && search.trim().isNotEmpty) 'vc_search': search,
    }),
  );

  Future<int> createEntry({
    required int nrCompany,
    required int nrBranch,
    required EntryDraft draft,
  }) async {
    final json = await _gateway.rpc('fin_entry_save', {
      ..._branch(nrCompany, nrBranch),
      'vc_action': 'I',
      ...draft.toJson(),
    });
    return (json['qt_created'] as num?)?.toInt() ?? 1;
  }

  Future<void> updateEntry({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required Map<String, dynamic> changes,
  }) => _gateway.rpc('fin_entry_save', {
    ..._branch(nrCompany, nrBranch),
    'vc_action': 'U',
    'nr_entry': nrEntry,
    ...changes,
  });

  /// PAY / UNDO / CANCEL / REOPEN.
  Future<void> settle({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required String action,
    Map<String, dynamic> extra = const {},
  }) => _gateway.rpc('fin_entry_settle', {
    ..._branch(nrCompany, nrBranch),
    'nr_entry': nrEntry,
    'vc_action': action,
    ...extra,
  });

  Future<Cashflow> cashflow({
    required int nrCompany,
    required int nrBranch,
    required DateTime month,
  }) async => Cashflow.fromJson(
    await _gateway.rpc('fin_cashflow', {
      ..._branch(nrCompany, nrBranch),
      'nr_year': month.year,
      'nr_month': month.month,
    }),
  );

  Future<Statement> statement({
    required int nrCompany,
    required int nrBranch,
    int? nrAccount,
    required DateTime from,
    required DateTime to,
  }) async => Statement.fromJson(
    await _gateway.rpc('fin_statement', {
      ..._branch(nrCompany, nrBranch),
      if (nrAccount != null) 'nr_account': nrAccount,
      'dt_from': Dates.toIso(from),
      'dt_to': Dates.toIso(to),
    }),
  );
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(supabaseGatewayProvider)),
);
