import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

/// Tipo de planilha de ad.data_export.
enum ExportKind {
  patients('patients', 'pacientes'),
  finance('finance', 'financeiro'),
  procedures('procedures', 'procedimentos'),
  agenda('agenda', 'agenda');

  const ExportKind(this.code, this.file);

  /// vc_kind do backend.
  final String code;

  /// Prefixo do arquivo.
  final String file;
}

/// Colunas e linhas devolvidas por ad.data_export.
class ExportTable {
  const ExportTable({required this.columns, required this.rows});

  factory ExportTable.fromJson(Map<String, dynamic> j) => ExportTable(
    columns: [for (final c in (j['columns'] as List? ?? const [])) '$c'],
    rows: [
      for (final r in (j['rows'] as List? ?? const []))
        (r as List).cast<Object?>(),
    ],
  );

  final List<String> columns;
  final List<List<Object?>> rows;
}

/// Planilha (.xlsx) generica a partir de [ExportTable]: cabecalho destacado,
/// numeros como numero (moeda nas colunas de valor), datas ISO como data.
abstract final class DataExportXlsx {
  static final _header = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('FF0E8C86'),
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );
  static final _money = CellStyle(
    numberFormat: const CustomNumericNumFormat(formatCode: r'"R$" #,##0.00'),
  );
  static final _plain = CellStyle();
  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _moneyWords = RegExp(
    r'^(valor|preço|custo|laboratório|outros materiais)',
    caseSensitive: false,
  );

  /// Nome do arquivo sem extensao: `pacientes_AAAAMMDD_HHMM`.
  static String fileName(ExportKind kind, DateTime now) =>
      '${kind.file}_${DateFormat('yyyyMMdd_HHmm').format(now)}';

  static Uint8List build(ExportTable table, {required String sheetName}) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    final money = [for (final c in table.columns) _moneyWords.hasMatch(c)];
    for (var c = 0; c < table.columns.length; c++) {
      var width = table.columns[c].length + 4.0;
      for (final r in table.rows.take(200)) {
        if (c < r.length && r[c] != null) {
          final len = '${r[c]}'.length + 2.0;
          if (len > width) width = len;
        }
      }
      sheet.setColumnWidth(c, width.clamp(8, 50).toDouble());
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        TextCellValue(table.columns[c]),
        cellStyle: _header,
      );
    }
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      for (var c = 0; c < row.length && c < table.columns.length; c++) {
        final v = row[c];
        if (v == null) continue;
        final (value, style) = _cell(v, money[c]);
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
          value,
          cellStyle: style,
        );
      }
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('xlsx vazio');
    return Uint8List.fromList(bytes);
  }

  static (CellValue, CellStyle) _cell(Object v, bool money) {
    if (v is num) {
      return (DoubleCellValue(v.toDouble()), money ? _money : _plain);
    }
    final s = '$v';
    if (_isoDate.hasMatch(s)) {
      final d = DateTime.tryParse(s);
      if (d != null) {
        return (
          DateCellValue(year: d.year, month: d.month, day: d.day),
          _plain,
        );
      }
    }
    return (TextCellValue(s), _plain);
  }
}
