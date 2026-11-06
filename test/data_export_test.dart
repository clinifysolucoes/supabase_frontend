import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/settings/data/data_export.dart';
import 'package:odonto_app/features/settings/domain/trash_models.dart';

void main() {
  test('ExportTable vira xlsx com numero, moeda, data e texto', () {
    final table = ExportTable.fromJson({
      'columns': ['Nome', 'Vencimento', 'Valor', 'Minutos'],
      'rows': [
        ['Ana', '2030-03-04', 100.5, 30],
        ['Bia', null, 20, 15],
      ],
    });
    expect(table.columns, hasLength(4));
    final bytes = DataExportXlsx.build(table, sheetName: 'Financeiro');
    final sheet = Excel.decodeBytes(bytes)['Financeiro'];
    expect(sheet.maxRows, 3);
    expect(sheet.cell(CellIndex.indexByString('A1')).value.toString(), 'Nome');
    expect(sheet.cell(CellIndex.indexByString('A2')).value.toString(), 'Ana');
    expect(
      sheet.cell(CellIndex.indexByString('B2')).value,
      isA<DateCellValue>(),
    );
    expect(
      sheet.cell(CellIndex.indexByString('C2')).value,
      isA<DoubleCellValue>(),
    );
    expect(sheet.cell(CellIndex.indexByString('B3')).value, isNull);
  });

  test('nome do arquivo por tipo e data', () {
    expect(
      DataExportXlsx.fileName(ExportKind.patients, DateTime(2026, 11, 6, 9, 5)),
      'pacientes_20261106_0905',
    );
  });

  test('TrashData le itens e tipos', () {
    final d = TrashData.fromJson({
      'items': [
        {
          'vc_kind': 'patient_note',
          'nr_key': 2,
          'nr_parent': 7,
          'vc_title': 'Ana',
          'vc_detail': 'Alergia',
          'dh_deleted': '2026-11-06T12:00:00+00:00',
          'vc_user': 'Mel',
          'id_restore': true,
        },
      ],
      'kinds': ['patient', 'patient_note'],
    });
    expect(d.items.single.nrParent, 7);
    expect(d.items.single.idRestore, isTrue);
    expect(d.items.single.dhDeleted, isNotNull);
    expect(d.kinds, ['patient', 'patient_note']);
    expect(TrashKind.label('fin_entry'), 'Conta');
  });
}
