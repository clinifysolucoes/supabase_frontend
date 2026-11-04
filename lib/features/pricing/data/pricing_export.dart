import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../../l10n/strings.dart';
import '../domain/pricing_models.dart';

/// Gera a planilha (.xlsx) do grid de precificacao: os procedimentos com o
/// preco calculado pelo banco, os materiais de cada um e os parametros em
/// vigor. Sao VALORES (retrato do que o sistema calculou), nao formulas; a
/// planilha com as formulas vive em docs/precificacao do repositorio supabase.
abstract final class PricingExport {
  static const _moneyFormat = CustomNumericNumFormat(
    formatCode: r'"R$" #,##0.00',
  );
  static const _money4Format = CustomNumericNumFormat(
    formatCode: r'"R$" #,##0.0000',
  );
  static const _percentFormat = CustomNumericNumFormat(formatCode: '0.00%');
  static const _intFormat = CustomNumericNumFormat(formatCode: '0');

  static final _header = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('FF0E8C86'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );
  static final _money = CellStyle(numberFormat: _moneyFormat);
  static final _money4 = CellStyle(numberFormat: _money4Format);
  static final _moneyBold = CellStyle(bold: true, numberFormat: _moneyFormat);
  static final _percent = CellStyle(numberFormat: _percentFormat);
  static final _int = CellStyle(numberFormat: _intFormat);
  static final _bold = CellStyle(bold: true);
  static final _plain = CellStyle();

  /// Nome do arquivo sem extensao: precificacao_AAAAMMDD_HHMM.
  static String fileName(DateTime now) =>
      'precificacao_${DateFormat('yyyyMMdd_HHmm').format(now)}';

  static Uint8List buildXlsx(ProcedureListData data, {DateTime? now}) {
    final when = now ?? DateTime.now();
    final excel = Excel.createExcel();
    excel.rename('Sheet1', Strings.exportSheetProcedures);
    _procedures(excel[Strings.exportSheetProcedures], data);
    _materials(excel[Strings.exportSheetMaterials], data);
    _params(excel[Strings.exportSheetParams], data, when);
    excel.setDefaultSheet(Strings.exportSheetProcedures);
    final bytes = excel.encode();
    if (bytes == null) throw StateError('xlsx vazio');
    return Uint8List.fromList(bytes);
  }

  // --- aba Procedimentos ------------------------------------------------------

  static void _procedures(Sheet sheet, ProcedureListData data) {
    final regime = data.summary.itTaxRegime ?? data.params.itTaxRegime;
    final taxLabel = regime == TaxRegime.pj
        ? '${Strings.incomeTax} ${Strings.taxRegimePjShort}'
        : '${Strings.incomeTax} ${Strings.taxRegimePfShort}';
    final columns = <_Col>[
      _Col(Strings.procedureCode, 10, (p) => _text(p.vcCode)),
      _Col(Strings.procedureName, 44, (p) => _text(p.vcName)),
      _Col(Strings.specialty, 18, (p) => _text(p.vcSpecialty)),
      _Col(Strings.minutes, 11, (p) => _num(p.qtMinutes, _int)),
      _Col(
        '${Strings.materialsCost} (R\$)',
        14,
        (p) => _num(p.pricing?.vlMaterial, _money),
      ),
      _Col(
        '${Strings.labCostShort} (R\$)',
        14,
        (p) => _num(p.vlLabCost, _money),
      ),
      _Col(
        '${Strings.structureCost} (R\$)',
        14,
        (p) => _num(p.pricing?.vlStructure, _money),
      ),
      _Col(
        '${Strings.professionalCost} (R\$)',
        14,
        (p) => _num(p.pricing?.vlProfessional, _money),
      ),
      _Col(
        '${Strings.directCost} (R\$)',
        14,
        (p) => _num(p.pricing?.vlDirectCost, _moneyBold),
      ),
      _Col(
        '${Strings.cardFee} (R\$)',
        13,
        (p) => _num(p.pricing?.vlCard, _money),
      ),
      _Col(
        '${Strings.commission} (R\$)',
        13,
        (p) => _num(p.pricing?.vlCommission, _money),
      ),
      _Col(
        '${Strings.extraFees} (R\$)',
        13,
        (p) => _num(p.pricing?.vlFees, _money),
      ),
      _Col('$taxLabel (R\$)', 13, (p) => _num(p.pricing?.vlTax, _money)),
      _Col(
        '${Strings.profit} (R\$)',
        13,
        (p) => _num(p.pricing?.vlProfit, _money),
      ),
      _Col(
        '${Strings.profitReal} (%)',
        11,
        (p) => _pct(p.pricing?.pcProfitReal),
      ),
      _Col(
        '${Strings.minPrice} (R\$)',
        14,
        (p) => _num(p.pricing?.vlPriceMin, _money),
      ),
      _Col(
        '${Strings.suggestedPrice} (R\$)',
        16,
        (p) => _num(p.pricing?.vlPrice, _moneyBold),
      ),
      _Col(Strings.currentPrice, 14, (p) => _num(p.vlCurrentPrice, _money)),
      _Col('${Strings.difference} (R\$)', 14, (p) => _num(p.priceDiff, _money)),
      _Col(
        '${Strings.currentProfit} (R\$)',
        16,
        (p) => _num(p.pricing?.vlCurrentProfit, _money),
      ),
      _Col(
        Strings.priceCheckColumn,
        20,
        (p) => _text(
          p.vlCurrentPrice == null ? null : PriceStatus.label(p.priceStatus),
        ),
      ),
      _Col(
        Strings.status,
        10,
        (p) =>
            _text(p.isActive ? Strings.statusActive : Strings.statusInactive),
      ),
      _Col(
        Strings.alerts,
        28,
        (p) => _text(p.alerts.map(ProcedureAlert.label).join(', ')),
      ),
    ];
    _table(sheet, columns, data.procedures);
  }

  // --- aba Materiais por procedimento ----------------------------------------

  static void _materials(Sheet sheet, ProcedureListData data) {
    final rows = <(Procedure, ProcedureMaterial)>[
      for (final p in data.procedures)
        for (final m in p.materials) (p, m),
    ];
    final columns = <_Col<(Procedure, ProcedureMaterial)>>[
      _Col(Strings.procedureName, 44, (r) => _text(r.$1.displayName)),
      _Col(Strings.materialName, 34, (r) => _text(r.$2.vcName)),
      _Col(Strings.quantityUsed, 12, (r) => _num(r.$2.qtUsed, _plain)),
      _Col(Strings.unit, 14, (r) => _text(r.$2.vcUnit)),
      _Col(
        '${Strings.unitCost} (R\$)',
        16,
        (r) => _num(r.$2.vlUnitCost, _money4),
      ),
      _Col(
        '${Strings.lineCost} (R\$)',
        14,
        (r) => _num(r.$2.vlLineCost, _money),
      ),
    ];
    _table(sheet, columns, rows);
  }

  // --- aba Parametros --------------------------------------------------------

  static void _params(Sheet sheet, ProcedureListData data, DateTime when) {
    final p = data.params;
    final s = data.summary;
    final regime = s.itTaxRegime ?? p.itTaxRegime;
    final rows = <(String, CellValue, CellStyle)>[
      (
        Strings.exportGeneratedAt,
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(when)),
        _plain,
      ),
      (Strings.monthlyCost, DoubleCellValue(s.vlMonthlyCost), _money),
      (Strings.rooms, IntCellValue(p.qtRooms), _int),
      (Strings.hoursWeek, DoubleCellValue(p.qtHoursWeek), _plain),
      (Strings.weeksMonth, DoubleCellValue(p.qtWeeksMonth), _plain),
      (Strings.occupancy, DoubleCellValue(p.pcOccupancy / 100), _percent),
      (Strings.productiveHours, DoubleCellValue(s.qtProductiveHours), _plain),
      (Strings.structureCalc, DoubleCellValue(s.vlStructureHourCalc), _money),
      (
        Strings.structureManual,
        p.vlStructureHourManual == null
            ? TextCellValue('-')
            : DoubleCellValue(p.vlStructureHourManual!),
        _money,
      ),
      (Strings.structureHour, DoubleCellValue(s.vlStructureHour), _moneyBold),
      (Strings.professionalHour, DoubleCellValue(p.vlProfessionalHour), _money),
      (Strings.cardRate, DoubleCellValue(p.pcCard / 100), _percent),
      (Strings.commissionRate, DoubleCellValue(p.pcCommission / 100), _percent),
      (Strings.extraFees, DoubleCellValue(s.pcFees / 100), _percent),
      (Strings.taxRegime, TextCellValue(TaxRegime.label(regime)), _plain),
      (Strings.taxPf, DoubleCellValue(p.pcTaxPf / 100), _percent),
      (Strings.taxPj, DoubleCellValue(p.pcTaxPj / 100), _percent),
      (Strings.profitRate, DoubleCellValue(p.pcProfit / 100), _percent),
      (Strings.totalPercent, DoubleCellValue(s.pcTotal / 100), _percent),
    ];
    sheet.setColumnWidth(0, 40);
    sheet.setColumnWidth(1, 18);
    var r = 0;
    for (final (label, value, style) in rows) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        TextCellValue(label),
        cellStyle: _bold,
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r),
        value,
        cellStyle: style,
      );
      r++;
    }
  }

  // --- helpers ---------------------------------------------------------------

  static void _table<T>(Sheet sheet, List<_Col<T>> columns, List<T> rows) {
    for (var c = 0; c < columns.length; c++) {
      sheet.setColumnWidth(c, columns[c].width);
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        TextCellValue(columns[c].title),
        cellStyle: _header,
      );
    }
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        final cell = columns[c].value(rows[r]);
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
          cell.value,
          cellStyle: cell.style,
        );
      }
    }
  }

  static _Cell _text(String? v) => _Cell(TextCellValue(v ?? ''), _plain);

  static _Cell _num(double? v, CellStyle style) => v == null
      ? _Cell(TextCellValue(''), _plain)
      : _Cell(DoubleCellValue(v), style);

  static _Cell _pct(double? v) => v == null
      ? _Cell(TextCellValue(''), _plain)
      : _Cell(DoubleCellValue(v / 100), _percent);
}

class _Col<T> {
  const _Col(this.title, this.width, this.value);

  final String title;
  final double width;
  final _Cell Function(T row) value;
}

class _Cell {
  const _Cell(this.value, this.style);

  final CellValue value;
  final CellStyle style;
}
