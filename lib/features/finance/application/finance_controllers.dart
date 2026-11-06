import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agenda/application/agenda_controllers.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/finance_repository.dart';
import '../domain/bank_models.dart';
import '../domain/cash_models.dart';
import '../domain/dre_models.dart';
import '../domain/health_models.dart';
import '../domain/finance_models.dart';
import '../domain/phase4_models.dart';
import '../domain/receivable_models.dart';

/// Empresa e filial atuais (null sem sessao/filial).
({int company, int branch})? _branchOf(Ref ref) {
  final nrCompany = ref.watch(currentCompanyProvider);
  final nrBranch = ref.watch(currentBranchNumberProvider);
  if (nrCompany == null || nrBranch == null) return null;
  return (company: nrCompany, branch: nrBranch);
}

DateTime _thisMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

/// Ultimo dia do mes de [month].
DateTime monthEnd(DateTime month) => DateTime(month.year, month.month + 1, 0);

/// Visao geral do dia.
final financeOverviewProvider = FutureProvider.autoDispose<FinOverview>((
  ref,
) async {
  final b = _branchOf(ref);
  if (b == null) return const FinOverview();
  return ref
      .read(financeRepositoryProvider)
      .overview(nrCompany: b.company, nrBranch: b.branch);
});

/// Contas, categorias e fornecedores (inclusive os inativos: os formularios
/// filtram os ativos, a aba Cadastros mostra tudo).
final financeCatalogProvider = FutureProvider.autoDispose<FinCatalog>((
  ref,
) async {
  final b = _branchOf(ref);
  if (b == null) return const FinCatalog();
  return ref
      .read(financeRepositoryProvider)
      .catalog(nrCompany: b.company, nrBranch: b.branch, includeInactive: true);
});

/// Mes das listas A pagar / A receber, por tipo (EntryKind).
final entriesMonthProvider = StateProvider.autoDispose.family<DateTime, int>(
  (_, _) => _thisMonth(),
);

/// Filtro de situacao das listas, por tipo.
final entriesFilterProvider = StateProvider.autoDispose
    .family<EntryFilter, int>((_, _) => EntryFilter.all);

/// Busca por descricao/fornecedor/paciente, por tipo.
final entriesSearchProvider = StateProvider.autoDispose.family<String, int>(
  (_, _) => '',
);

/// Filtrar o mes pela competencia (em vez do vencimento), por tipo.
final entriesByCompetenceProvider = StateProvider.autoDispose.family<bool, int>(
  (_, _) => false,
);

/// So contas parceladas, por tipo.
final entriesInstallmentsProvider = StateProvider.autoDispose.family<bool, int>(
  (_, _) => false,
);

/// Lancamentos do mes, por tipo.
final entriesProvider = FutureProvider.autoDispose.family<FinEntryList, int>((
  ref,
  kind,
) async {
  final b = _branchOf(ref);
  if (b == null) return const FinEntryList();
  final month = ref.watch(entriesMonthProvider(kind));
  final status = ref.watch(entriesFilterProvider(kind));
  // vencidos olham para tras (ate 400 dias), nao para o mes escolhido
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final overdue = status == EntryFilter.overdue;
  return ref
      .read(financeRepositoryProvider)
      .entries(
        nrCompany: b.company,
        nrBranch: b.branch,
        itKind: kind,
        from: overdue ? today.subtract(const Duration(days: 399)) : month,
        to: overdue ? today : monthEnd(month),
        status: status,
        search: ref.watch(entriesSearchProvider(kind)),
        byCompetence: !overdue && ref.watch(entriesByCompetenceProvider(kind)),
        onlyInstallments: ref.watch(entriesInstallmentsProvider(kind)),
      );
});

/// Contas recorrentes (regras), por tipo; [includeInactive] mostra as encerradas.
final recurrencesProvider = FutureProvider.autoDispose
    .family<List<FinRecurrence>, ({int kind, bool includeInactive})>((
      ref,
      key,
    ) async {
      final b = _branchOf(ref);
      if (b == null) return const [];
      return ref
          .read(financeRepositoryProvider)
          .recurrences(
            nrCompany: b.company,
            nrBranch: b.branch,
            itKind: key.kind,
            includeInactive: key.includeInactive,
          );
    });

/// Consultas do mes de A receber que ja aconteceram e nao foram fechadas.
final pendingCheckoutsProvider =
    FutureProvider.autoDispose<List<PendingCheckout>>((ref) async {
      final b = _branchOf(ref);
      if (b == null) return const [];
      final month = ref.watch(entriesMonthProvider(EntryKind.receivable));
      return ref
          .read(financeRepositoryProvider)
          .pendingCheckouts(
            nrCompany: b.company,
            nrBranch: b.branch,
            from: month,
            to: monthEnd(month),
          );
    });

/// Anexos de uma conta.
final attachmentsProvider = FutureProvider.autoDispose
    .family<List<FinAttachment>, int>((ref, nrEntry) async {
      final b = _branchOf(ref);
      if (b == null) return const [];
      return ref
          .read(financeRepositoryProvider)
          .attachments(
            nrCompany: b.company,
            nrBranch: b.branch,
            nrEntry: nrEntry,
          );
    });

/// Mes do fluxo de caixa.
final cashflowMonthProvider = StateProvider.autoDispose<DateTime>(
  (_) => _thisMonth(),
);

final cashflowProvider = FutureProvider.autoDispose<Cashflow>((ref) async {
  final b = _branchOf(ref);
  if (b == null) return const Cashflow();
  return ref
      .read(financeRepositoryProvider)
      .cashflow(
        nrCompany: b.company,
        nrBranch: b.branch,
        month: ref.watch(cashflowMonthProvider),
      );
});

/// DRE: ano e base (competence | cash).
final dreYearProvider = StateProvider.autoDispose<int>(
  (_) => DateTime.now().year,
);
final dreBasisProvider = StateProvider.autoDispose<String>((_) => 'competence');

final dreProvider = FutureProvider.autoDispose<DreReport>((ref) async {
  final b = _branchOf(ref);
  if (b == null) return const DreReport();
  final year = ref.watch(dreYearProvider);
  return ref
      .read(financeRepositoryProvider)
      .dre(
        nrCompany: b.company,
        nrBranch: b.branch,
        from: DateTime(year),
        to: DateTime(year, 12),
        basis: ref.watch(dreBasisProvider),
      );
});

/// Extrato: mes e conta (null = todas as contas ativas).
final statementMonthProvider = StateProvider.autoDispose<DateTime>(
  (_) => _thisMonth(),
);

final statementAccountProvider = StateProvider.autoDispose<int?>((_) => null);

final statementProvider = FutureProvider.autoDispose<Statement>((ref) async {
  final b = _branchOf(ref);
  if (b == null) return const Statement();
  final month = ref.watch(statementMonthProvider);
  return ref
      .read(financeRepositoryProvider)
      .statement(
        nrCompany: b.company,
        nrBranch: b.branch,
        nrAccount: ref.watch(statementAccountProvider),
        from: month,
        to: monthEnd(month),
      );
});

/// Caixa do dia: o meu caixa, as contas caixa e as ultimas sessoes.
final cashStatusProvider = FutureProvider.autoDispose<CashStatus>((ref) async {
  final b = _branchOf(ref);
  if (b == null) return const CashStatus();
  return ref
      .read(financeRepositoryProvider)
      .cashStatus(nrCompany: b.company, nrBranch: b.branch);
});

/// Recebiveis: mes da previsao e situacao.
final receivablesMonthProvider = StateProvider.autoDispose<DateTime>(
  (_) => _thisMonth(),
);

final receivablesFilterProvider = StateProvider.autoDispose<ReceivableFilter>(
  (_) => ReceivableFilter.all,
);

final receivablesProvider = FutureProvider.autoDispose<ReceivableList>((
  ref,
) async {
  final b = _branchOf(ref);
  if (b == null) return const ReceivableList();
  final filter = ref.watch(receivablesFilterProvider);
  final month = ref.watch(receivablesMonthProvider);
  // vencidos olham para tras, como nas contas
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final overdue = filter == ReceivableFilter.overdue;
  return ref
      .read(financeRepositoryProvider)
      .receivables(
        nrCompany: b.company,
        nrBranch: b.branch,
        from: overdue ? today.subtract(const Duration(days: 399)) : month,
        to: overdue ? today : monthEnd(month),
        status: filter,
      );
});

/// Convenios (com os procedimentos e profissionais dos formularios).
final healthPlansProvider = FutureProvider.autoDispose<PlanCatalog>((
  ref,
) async {
  final b = _branchOf(ref);
  if (b == null) return const PlanCatalog();
  return ref
      .read(financeRepositoryProvider)
      .healthPlans(nrCompany: b.company, nrBranch: b.branch);
});

/// Guias: mes do atendimento e situacao.
final guidesMonthProvider = StateProvider.autoDispose<DateTime>(
  (_) => _thisMonth(),
);

final guidesFilterProvider = StateProvider.autoDispose<GuideFilter>(
  (_) => GuideFilter.all,
);

final guidesProvider = FutureProvider.autoDispose<GuideList>((ref) async {
  final b = _branchOf(ref);
  if (b == null) return const GuideList();
  final month = ref.watch(guidesMonthProvider);
  return ref
      .read(financeRepositoryProvider)
      .healthGuides(
        nrCompany: b.company,
        nrBranch: b.branch,
        from: month,
        to: monthEnd(month),
        status: ref.watch(guidesFilterProvider),
      );
});

/// Conciliacao: conta (null = escolher) e mes.
final bankAccountProvider = StateProvider.autoDispose<int?>((_) => null);

final bankMonthProvider = StateProvider.autoDispose<DateTime>(
  (_) => _thisMonth(),
);

final bankLinesProvider = FutureProvider.autoDispose<BankList?>((ref) async {
  final b = _branchOf(ref);
  final account = ref.watch(bankAccountProvider);
  if (b == null || account == null) return null;
  final month = ref.watch(bankMonthProvider);
  return ref
      .read(financeRepositoryProvider)
      .bankLines(
        nrCompany: b.company,
        nrBranch: b.branch,
        nrAccount: account,
        from: month,
        to: monthEnd(month),
      );
});

/// Escritas do financeiro: chamam a RPC e recarregam tudo que mostra saldo.
class FinanceActions {
  FinanceActions(this._ref);

  final Ref _ref;

  FinanceRepository get _repo => _ref.read(financeRepositoryProvider);

  ({int company, int branch}) get _b {
    final nrCompany = _ref.read(currentCompanyProvider);
    final nrBranch = _ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) {
      throw StateError('branch');
    }
    return (company: nrCompany, branch: nrBranch);
  }

  void _invalidate() {
    _ref
      ..invalidate(financeOverviewProvider)
      ..invalidate(financeCatalogProvider)
      ..invalidate(entriesProvider)
      ..invalidate(cashflowProvider)
      ..invalidate(statementProvider)
      ..invalidate(cashStatusProvider)
      ..invalidate(receivablesProvider)
      ..invalidate(healthPlansProvider)
      ..invalidate(guidesProvider)
      ..invalidate(bankLinesProvider)
      ..invalidate(recurrencesProvider)
      ..invalidate(pendingCheckoutsProvider)
      ..invalidate(attachmentsProvider);
  }

  /// Recebimentos para a Receita Saude; [mark] = exporta de verdade.
  Future<HealthExport> healthExport(
    DateTime from,
    DateTime to, {
    bool onlyPending = false,
    List<int>? entries,
    bool mark = false,
  }) {
    final b = _b;
    return _repo.healthExport(
      nrCompany: b.company,
      nrBranch: b.branch,
      from: from,
      to: to,
      onlyPending: onlyPending,
      entries: entries,
      mark: mark,
    );
  }

  Future<void> uploadAttachment({
    required int nrEntry,
    required int itType,
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    final b = _b;
    await _repo.uploadAttachment(
      nrCompany: b.company,
      nrBranch: b.branch,
      nrEntry: nrEntry,
      itType: itType,
      name: name,
      mime: mime,
      bytes: bytes,
    );
    _invalidate();
  }

  Future<Uint8List> downloadAttachment(int nrAttachment) {
    final b = _b;
    return _repo.downloadAttachment(
      nrCompany: b.company,
      nrBranch: b.branch,
      nrAttachment: nrAttachment,
    );
  }

  Future<void> deleteAttachment(int nrAttachment) async {
    final b = _b;
    await _repo.deleteAttachment(
      nrCompany: b.company,
      nrBranch: b.branch,
      nrAttachment: nrAttachment,
    );
    _invalidate();
  }

  /// Fechamento da consulta: gera o financeiro e atualiza a agenda (selo).
  Future<Map<String, dynamic>> checkout(CheckoutDraft draft) async {
    final b = _b;
    final r = await _repo.checkout(
      nrCompany: b.company,
      nrBranch: b.branch,
      draft: draft,
    );
    _invalidate();
    _ref.invalidate(appointmentsProvider);
    return r;
  }

  /// Caixa: fin_cash_open, fin_cash_close ou fin_transfer_save.
  Future<Map<String, dynamic>> cash(
    String rpc,
    Map<String, dynamic> fields,
  ) async {
    final b = _b;
    final r = await _repo.cashCall(
      nrCompany: b.company,
      nrBranch: b.branch,
      rpc: rpc,
      fields: fields,
    );
    _invalidate();
    return r;
  }

  Future<void> setup() async {
    final b = _b;
    await _repo.setup(nrCompany: b.company, nrBranch: b.branch);
    _invalidate();
  }

  Future<int?> saveRegister({
    required String rpc,
    required String key,
    int? id,
    required Map<String, dynamic> fields,
  }) async {
    final b = _b;
    final nr = await _repo.saveRegister(
      nrCompany: b.company,
      nrBranch: b.branch,
      rpc: rpc,
      key: key,
      id: id,
      fields: fields,
    );
    _invalidate();
    return nr;
  }

  Future<int> createEntry(EntryDraft draft) async {
    final b = _b;
    final qt = await _repo.createEntry(
      nrCompany: b.company,
      nrBranch: b.branch,
      draft: draft,
    );
    _invalidate();
    return qt;
  }

  Future<void> updateEntry(int nrEntry, Map<String, dynamic> changes) async {
    final b = _b;
    await _repo.updateEntry(
      nrCompany: b.company,
      nrBranch: b.branch,
      nrEntry: nrEntry,
      changes: changes,
    );
    _invalidate();
  }

  Future<void> settle(
    int nrEntry,
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final b = _b;
    await _repo.settle(
      nrCompany: b.company,
      nrBranch: b.branch,
      nrEntry: nrEntry,
      action: action,
      extra: extra,
    );
    _invalidate();
  }
}

final financeActionsProvider = Provider.autoDispose<FinanceActions>(
  FinanceActions.new,
);
