import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/finance/data/finance_repository.dart';
import 'package:odonto_app/features/finance/domain/finance_models.dart';
import 'package:odonto_app/features/finance/presentation/finance_page.dart';
import 'package:odonto_app/features/profiles/application/profiles_controller.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

/// Mesmos formatos das RPCs (tests/12_finance.sql no backend).
final _catalog = {
  'accounts': [
    {
      'nr_account': 1,
      'vc_name': 'Caixa',
      'it_type': 1,
      'vl_opening': 100,
      'vl_balance': 350.5,
      'it_status': 1,
    },
    {
      'nr_account': 2,
      'vc_name': 'Banco',
      'it_type': 2,
      'vl_opening': 0,
      'vl_balance': -20,
      'it_status': 1,
    },
  ],
  'categories': [
    {
      'nr_category': 1,
      'vc_name': 'Tratamentos',
      'it_kind': 1,
      'it_cost_type': null,
      'it_status': 1,
      'qt_entries': 0,
    },
    {
      'nr_category': 4,
      'vc_name': 'Aluguel',
      'it_kind': 2,
      'it_cost_type': 1,
      'it_status': 1,
      'qt_entries': 3,
    },
  ],
  'suppliers': [
    {'nr_supplier': 1, 'vc_name': 'Dental Sul', 'it_status': 1},
  ],
  'permission': {'id_read': true, 'id_create': true, 'id_update': true},
};

Map<String, dynamic> _entry({
  int nr = 10,
  int status = 1,
  bool overdue = false,
}) => {
  'nr_entry': nr,
  'it_kind': 2,
  'nr_category': 4,
  'vc_category': 'Aluguel',
  'it_cost_type': 1,
  'nr_account': null,
  'nr_supplier': 1,
  'vc_supplier': 'Dental Sul',
  'vc_description': 'Aluguel (1/3)',
  'vl_amount': 1500,
  'dt_due': '2026-11-10',
  'it_status': status,
  'id_overdue': overdue,
  'nr_installment': 1,
  'qt_installments': 3,
  'id_recurring': false,
};

class _FakeRepo implements FinanceRepository {
  bool configured = true;
  int setups = 0;
  EntryDraft? created;
  final settles = <(int, String, Map<String, dynamic>)>[];
  final newCategories = <Map<String, dynamic>>[];

  @override
  Future<void> setup({required int nrCompany, required int nrBranch}) async {
    setups++;
    configured = true;
  }

  @override
  Future<FinCatalog> catalog({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async => FinCatalog.fromJson({
    ..._catalog,
    'categories': [...(_catalog['categories'] as List), ...newCategories],
  });

  @override
  Future<int?> saveRegister({
    required int nrCompany,
    required int nrBranch,
    required String rpc,
    required String key,
    int? id,
    required Map<String, dynamic> fields,
  }) async {
    if (rpc != 'fin_category_save' || id != null) return id;
    newCategories.add({
      'nr_category': 9,
      'it_status': 1,
      'qt_entries': 0,
      ...fields,
    });
    return 9;
  }

  @override
  Future<FinOverview> overview({
    required int nrCompany,
    required int nrBranch,
  }) async => FinOverview.fromJson({
    'id_configured': configured,
    'vl_balance': 330.5,
    'accounts': _catalog['accounts'],
    'today': {'vl_receivable': 200, 'vl_payable': 0},
    'overdue': {
      'vl_receivable': 0,
      'qt_receivable': 0,
      'vl_payable': 80,
      'qt_payable': 1,
    },
    'month': {
      'vl_received': 1000,
      'vl_paid': 400,
      'vl_to_receive': 500,
      'vl_to_pay': 1500,
    },
    'next': [_entry()],
    'permission': _catalog['permission'],
  });

  @override
  Future<FinEntryList> entries({
    required int nrCompany,
    required int nrBranch,
    required int itKind,
    required DateTime from,
    required DateTime to,
    EntryFilter status = EntryFilter.all,
    int? nrCategory,
    String? search,
  }) async => FinEntryList.fromJson({
    'entries': itKind == EntryKind.payable ? [_entry()] : [],
    'totals': {
      'vl_open': 1500,
      'vl_overdue': 0,
      'vl_paid': 0,
      'vl_cancelled': 0,
      'qt_total': 1,
      'by_cost_type': {'1': 1500},
    },
  });

  @override
  Future<int> createEntry({
    required int nrCompany,
    required int nrBranch,
    required EntryDraft draft,
  }) async {
    created = draft;
    return draft.qtInstallments;
  }

  @override
  Future<void> updateEntry({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required Map<String, dynamic> changes,
  }) async {}

  @override
  Future<void> settle({
    required int nrCompany,
    required int nrBranch,
    required int nrEntry,
    required String action,
    Map<String, dynamic> extra = const {},
  }) async => settles.add((nrEntry, action, extra));

  @override
  Future<Cashflow> cashflow({
    required int nrCompany,
    required int nrBranch,
    required DateTime month,
  }) async => const Cashflow();

  @override
  Future<Statement> statement({
    required int nrCompany,
    required int nrBranch,
    int? nrAccount,
    required DateTime from,
    required DateTime to,
  }) async => const Statement();
}

void main() {
  group('modelos', () {
    test('catalogo, lancamento e totais', () {
      final c = FinCatalog.fromJson(_catalog);
      expect(c.accounts.length, 2);
      expect(c.categoriesOf(EntryKind.payable).single.vcName, 'Aluguel');
      expect(c.categoriesOf(EntryKind.receivable).single.itCostType, isNull);

      final l = FinEntryList.fromJson({
        'entries': [_entry(status: 1, overdue: true)],
        'totals': {
          'vl_open': '1500.00',
          'by_cost_type': {'1': 1500, '2': '20.5'},
        },
      });
      final e = l.entries.single;
      expect(e.dtDue, DateTime(2026, 11, 10));
      expect(e.isGrouped, isTrue);
      expect(e.counterpart, 'Dental Sul');
      expect(EntryStatus.label(e.itStatus, overdue: e.idOverdue), 'Vencido');
      expect(l.totals.vlOpen, 1500);
      expect(l.totals.byCostType, {1: 1500.0, 2: 20.5});
    });

    test('EntryDraft: parcelada, recorrente e ja paga', () {
      final base = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aluguel',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
      );
      final once = base.toJson();
      expect(once['dt_due'], '2026-11-05');
      expect(once['qt_installments'], 1);
      expect(once.containsKey('id_recurring'), isFalse);
      expect(once.containsKey('id_paid'), isFalse);

      final inst = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aparelho',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
        qtInstallments: 3,
      ).toJson();
      expect(inst['qt_installments'], 3);

      final rec = EntryDraft(
        itKind: 2,
        nrCategory: 4,
        vcDescription: 'Aluguel',
        vlAmount: 1000,
        dtDue: DateTime(2026, 11, 5),
        idRecurring: true,
        qtRepeat: 12,
      ).toJson();
      expect(rec['id_recurring'], isTrue);
      expect(rec['qt_repeat'], 12);
      expect(rec.containsKey('qt_installments'), isFalse);

      final paid = EntryDraft(
        itKind: 1,
        nrCategory: 1,
        vcDescription: 'Consulta',
        vlAmount: 200,
        dtDue: DateTime(2026, 11, 5),
        nrAccount: 1,
        idPaid: true,
        dtPaid: DateTime(2026, 11, 4),
      ).toJson();
      expect(paid['id_paid'], isTrue);
      expect(paid['dt_paid'], '2026-11-04');
      expect(paid['nr_account'], 1);
    });
  });

  group('telas', () {
    late _FakeRepo repo;

    Widget app() => ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repo),
        currentCompanyProvider.overrideWith((ref) => 1),
        currentBranchNumberProvider.overrideWith((ref) => 1),
        canReadProvider.overrideWith((ref, code) => true),
        canCreateProvider.overrideWith((ref, code) => true),
        canUpdateProvider.overrideWith((ref, code) => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: const Scaffold(body: FinancePageBody()),
      ),
    );

    setUp(() => repo = _FakeRepo());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    testWidgets('sem configuracao: botao configura a filial', (tester) async {
      repo.configured = false;
      await pump(tester);
      expect(find.text(Strings.finSetupTitle), findsOneWidget);
      expect(find.widgetWithText(Tab, Strings.tabPayables), findsNothing);
      await tester.tap(find.text(Strings.finSetupAction));
      await tester.pumpAndSettle();
      expect(repo.setups, 1);
      expect(find.widgetWithText(Tab, Strings.tabPayables), findsOneWidget);
    });

    testWidgets('visao geral: saldo, vencidos e proximos', (tester) async {
      await pump(tester);
      expect(find.text(Strings.finBalance), findsOneWidget);
      expect(find.textContaining('330,50'), findsOneWidget);
      expect(find.text(Strings.finOverdueCount(1)), findsOneWidget);
      expect(find.text('Aluguel (1/3)'), findsOneWidget);
    });

    testWidgets('a pagar: lista, nova parcelada e baixa', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(Tab, Strings.tabPayables));
      await tester.pumpAndSettle();
      expect(find.text('Aluguel (1/3)'), findsOneWidget);
      expect(find.text(Strings.finInstallmentOf(1, 3)), findsOneWidget);

      // nova conta a pagar parcelada em 3
      await tester.tap(find.text(Strings.newPayable));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.finDescription} *'),
          matching: find.byType(TextField),
        ),
        'Autoclave',
      );
      await tester.tap(find.text('${Strings.finCategory} *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aluguel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finRepeatInstallments));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.finTotalAmount} *'),
          matching: find.byType(TextField),
        ),
        '1000',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.finInstallments),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(Strings.finInstallmentsPreview(3, 'R\$ 333,33')),
        findsOneWidget,
      );
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      expect(repo.created?.vcDescription, 'Autoclave');
      expect(repo.created?.nrCategory, 4);
      expect(repo.created?.qtInstallments, 3);
      expect(repo.created?.vlAmount, 1000);

      // baixa pelo detalhe: conta ativa ja vem escolhida
      await tester.tap(find.text('Aluguel (1/3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.finPay));
      await tester.pumpAndSettle();
      expect(find.text(Strings.finPayTitle), findsOneWidget);
      await tester.tap(find.text(Strings.finPay).last);
      await tester.pumpAndSettle();
      final (nr, action, extra) = repo.settles.single;
      expect(nr, 10);
      expect(action, 'PAY');
      expect(extra['nr_account'], 1);
      expect(extra['vl_paid'], 1500);
    });

    testWidgets('lancamento: + cria a categoria de despesa e ja escolhe', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(Tab, Strings.tabPayables));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.newPayable));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(Strings.finNewCategory));
      await tester.pumpAndSettle();
      // ja vem como despesa, tipo de custo fixo
      expect(find.text(Strings.finCostType), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.text('${Strings.name} *'),
          matching: find.byType(TextField),
        ),
        'Manutenção',
      );
      await tester.tap(find.text(Strings.save).last);
      await tester.pumpAndSettle();
      final c = repo.newCategories.single;
      expect(c['vc_name'], 'Manutenção');
      expect(c['it_kind'], EntryKind.payable);
      expect(c['it_cost_type'], CostType.fixed);
      // de volta ao lancamento, com a categoria nova escolhida
      expect(find.text(Strings.newPayable), findsWidgets);
      expect(find.text('Manutenção'), findsOneWidget);
    });

    testWidgets('cadastros: nova categoria nos dois grupos', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(Tab, Strings.tabFinRegisters));
      await tester.pumpAndSettle();
      expect(find.text(Strings.finNewCategory), findsNWidgets(2));
    });
  });
}
