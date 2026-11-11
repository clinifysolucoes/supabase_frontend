/// Estoque de materiais (ad.stock_list / _item_save / _movement_save /
/// _movement_list). Quantidades em unidades de uso do material.
library;

import '../../../l10n/strings.dart';

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();

/// Tipos de movimento (od.stock_movement.it_type).
abstract final class StockMoveType {
  static const entry = 1;
  static const exit = 2;
  static const adjust = 3;
  static const procedure = 4;
  static const reversal = 5;

  static const all = [entry, exit, adjust, procedure, reversal];

  static String label(int t) => switch (t) {
    entry => Strings.stockTypeEntry,
    exit => Strings.stockTypeExit,
    adjust => Strings.stockTypeAdjust,
    procedure => Strings.stockTypeProcedure,
    reversal => Strings.stockTypeReversal,
    _ => '-',
  };
}

enum StockFilter {
  controlled('controlled', Strings.stockFilterControlled),
  low('low', Strings.stockFilterLow),
  all('all', Strings.stockFilterAll);

  const StockFilter(this.code, this.label);

  final String code;
  final String label;
}

class StockItem {
  const StockItem({
    required this.nrMaterial,
    required this.vcName,
    this.vcPackage,
    this.qtYield,
    this.vcUnit,
    this.vlPackagePrice,
    this.vlUnitCost,
    this.idControl = false,
    this.qtStock,
    this.qtMin,
    this.idLow = false,
    this.vlStock = 0,
    this.dtLastMovement,
  });

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
    nrMaterial: _int(j['nr_material']),
    vcName: j['vc_name'] as String? ?? '',
    vcPackage: j['vc_package'] as String?,
    qtYield: (j['qt_yield'] as num?)?.toDouble(),
    vcUnit: j['vc_unit'] as String?,
    vlPackagePrice: (j['vl_package_price'] as num?)?.toDouble(),
    vlUnitCost: (j['vl_unit_cost'] as num?)?.toDouble(),
    idControl: j['id_control'] as bool? ?? false,
    qtStock: (j['qt_stock'] as num?)?.toDouble(),
    qtMin: (j['qt_min'] as num?)?.toDouble(),
    idLow: j['id_low'] as bool? ?? false,
    vlStock: _num(j['vl_stock']),
    dtLastMovement: _date(j['dt_last_movement']),
  );

  final int nrMaterial;
  final String vcName;
  final String? vcPackage;
  final double? qtYield;
  final String? vcUnit;
  final double? vlPackagePrice;
  final double? vlUnitCost;
  final bool idControl;
  final double? qtStock;
  final double? qtMin;
  final bool idLow;
  final double vlStock;
  final DateTime? dtLastMovement;

  /// Entrada/saida pode ser em embalagens.
  bool get hasPackages => (qtYield ?? 0) > 0;

  /// Saldo em embalagens (ex.: "1,8 Caixa 50 pares").
  double? get packages =>
      hasPackages && qtStock != null ? qtStock! / qtYield! : null;
}

class StockListData {
  const StockListData({
    this.items = const [],
    this.suppliers = const [],
    this.qtControlled = 0,
    this.qtLow = 0,
    this.vlStock = 0,
  });

  factory StockListData.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? const {};
    return StockListData(
      items: _list(j['items']).map(StockItem.fromJson).toList(),
      suppliers: [
        for (final s in _list(j['suppliers']))
          (id: _int(s['nr_supplier']), name: s['vc_name'] as String? ?? ''),
      ],
      qtControlled: _int(t['qt_controlled']),
      qtLow: _int(t['qt_low']),
      vlStock: _num(t['vl_stock']),
    );
  }

  final List<StockItem> items;
  final List<({int id, String name})> suppliers;
  final int qtControlled;
  final int qtLow;
  final double vlStock;
}

class StockMovement {
  const StockMovement({
    required this.nrMovement,
    required this.dtMovement,
    required this.vcMaterial,
    required this.itType,
    required this.qtQuantity,
    required this.qtBalance,
    this.vcUnit,
    this.vlTotal,
    this.vcSupplier,
    this.vcDocument,
    this.nrEntry,
    this.vcPatient,
    this.vcNotes,
    this.vcUser,
  });

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    nrMovement: _int(j['nr_movement']),
    dtMovement: _date(j['dt_movement']) ?? DateTime(2000),
    vcMaterial: j['vc_material'] as String? ?? '',
    itType: _int(j['it_type']),
    qtQuantity: _num(j['qt_quantity']),
    qtBalance: _num(j['qt_balance']),
    vcUnit: j['vc_unit'] as String?,
    vlTotal: (j['vl_total'] as num?)?.toDouble(),
    vcSupplier: j['vc_supplier'] as String?,
    vcDocument: j['vc_document'] as String?,
    nrEntry: (j['nr_entry'] as num?)?.toInt(),
    vcPatient: j['vc_patient'] as String?,
    vcNotes: j['vc_notes'] as String?,
    vcUser: j['vc_user'] as String?,
  );

  final int nrMovement;
  final DateTime dtMovement;
  final String vcMaterial;
  final int itType;
  final double qtQuantity;
  final double qtBalance;
  final String? vcUnit;
  final double? vlTotal;
  final String? vcSupplier;
  final String? vcDocument;
  final int? nrEntry;
  final String? vcPatient;
  final String? vcNotes;
  final String? vcUser;

  /// Fornecedor/documento, paciente, observacao e usuario numa linha.
  String get details => [
    if ((vcSupplier ?? '').isNotEmpty) vcSupplier!,
    if ((vcDocument ?? '').isNotEmpty) vcDocument!,
    if ((vcPatient ?? '').isNotEmpty) vcPatient!,
    if ((vcNotes ?? '').isNotEmpty) vcNotes!,
    if ((vcUser ?? '').isNotEmpty) vcUser!,
  ].join(' · ');
}

class StockMovementData {
  const StockMovementData({
    this.movements = const [],
    this.vlIn = 0,
    this.vlOut = 0,
    this.vlProcedures = 0,
    this.vlAdjust = 0,
    this.idTruncated = false,
  });

  factory StockMovementData.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map?) ?? const {};
    return StockMovementData(
      movements: _list(j['movements']).map(StockMovement.fromJson).toList(),
      vlIn: _num(s['vl_in']),
      vlOut: _num(s['vl_out']),
      vlProcedures: _num(s['vl_procedures']),
      vlAdjust: _num(s['vl_adjust']),
      idTruncated: j['id_truncated'] as bool? ?? false,
    );
  }

  final List<StockMovement> movements;
  final double vlIn;
  final double vlOut;
  final double vlProcedures;
  final double vlAdjust;
  final bool idTruncated;
}

/// Periodos de atalho dos movimentos.
enum StockPeriod { last30, thisMonth, lastMonth }

({DateTime from, DateTime to}) stockRange(StockPeriod p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (p) {
    StockPeriod.last30 => (
      from: today.subtract(const Duration(days: 29)),
      to: today,
    ),
    StockPeriod.thisMonth => (from: DateTime(now.year, now.month), to: today),
    StockPeriod.lastMonth => (
      from: DateTime(now.year, now.month - 1),
      to: DateTime(now.year, now.month, 0),
    ),
  };
}
