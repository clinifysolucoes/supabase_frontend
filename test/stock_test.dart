import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/stock/domain/stock_models.dart';
import 'package:odonto_app/features/stock/presentation/stock_page.dart';

final _list = {
  'items': [
    {
      'nr_material': 2,
      'vc_name': 'Resina',
      'vc_package': 'Seringa',
      'qt_yield': 100,
      'vc_unit': 'aplicação',
      'vl_package_price': 90,
      'vl_unit_cost': 0.9,
      'id_control': true,
      'qt_stock': -1,
      'id_low': true,
      'vl_stock': 0,
      'dt_last_movement': '2026-11-11',
    },
    {
      'nr_material': 1,
      'vc_name': 'Luva',
      'vc_package': 'Caixa 50 pares',
      'qt_yield': 50,
      'vc_unit': 'par',
      'vl_package_price': 110,
      'vl_unit_cost': 2.2,
      'id_control': true,
      'qt_stock': 90,
      'qt_min': 20,
      'id_low': false,
      'vl_stock': 198,
    },
    {'nr_material': 3, 'vc_name': 'Gaze', 'id_control': false},
  ],
  'totals': {'qt_controlled': 2, 'qt_low': 1, 'vl_stock': 198},
  'suppliers': [
    {'nr_supplier': 1, 'vc_name': 'Dental Sul'},
  ],
};

final _moves = {
  'movements': [
    {
      'nr_movement': 3,
      'dt_movement': '2026-11-11',
      'vc_material': 'Luva',
      'vc_unit': 'par',
      'it_type': 4,
      'qt_quantity': -2,
      'qt_balance': 94,
      'vl_total': 4.4,
      'vc_patient': 'Ana',
      'vc_user': 'Tom',
    },
    {
      'nr_movement': 1,
      'dt_movement': '2026-11-10',
      'vc_material': 'Luva',
      'vc_unit': 'par',
      'it_type': 1,
      'qt_quantity': 100,
      'qt_balance': 100,
      'vl_total': 220,
      'vc_supplier': 'Dental Sul',
      'vc_document': 'NF 123',
      'nr_entry': 7,
    },
  ],
  'summary': {'vl_in': 220, 'vl_out': 0, 'vl_procedures': 4.4, 'vl_adjust': 0},
};

void main() {
  test('Le saldos e movimentos', () {
    final d = StockListData.fromJson(_list);
    expect(d.items, hasLength(3));
    expect(d.qtLow, 1);
    final luva = d.items[1];
    expect(luva.packages, 1.8);
    expect(luva.hasPackages, isTrue);
    expect(d.items.last.idControl, isFalse);
    expect(d.items.last.packages, isNull);
    final m = StockMovementData.fromJson(_moves);
    expect(m.vlIn, 220);
    expect(m.movements.first.details, 'Ana · Tom');
    expect(m.movements.last.details, 'Dental Sul · NF 123');
    expect(StockMoveType.label(4), 'Procedimento');
  });

  test('Periodos', () {
    final r = stockRange(StockPeriod.lastMonth, DateTime(2026, 3, 15));
    expect(r.from, DateTime(2026, 2));
    expect(r.to, DateTime(2026, 2, 28));
    final l = stockRange(StockPeriod.last30, DateTime(2026, 3, 30));
    expect(l.from, DateTime(2026, 3));
  });

  testWidgets('Cartoes e movimentos desenham', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = StockListData.fromJson(_list);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final i in d.items)
                  StockItemCard(item: i, suppliers: d.suppliers),
                StockMovementsView(data: StockMovementData.fromJson(_moves)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sem controle de estoque'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Usado nos procedimentos'), findsOneWidget);
  });
}
