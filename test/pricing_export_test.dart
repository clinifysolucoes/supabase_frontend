import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/pricing/data/pricing_export.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';

void main() {
  final data = ProcedureListData(
    procedures: [
      Procedure.fromJson({
        'nr_procedure': 1,
        'vc_code': '1.0',
        'vc_name': 'Profilaxia',
        'nr_specialty': 1,
        'vc_specialty': 'Clínica Geral',
        'qt_minutes': 60,
        'vl_lab_cost': 0,
        'vl_material_other': 2,
        'vl_current_price': 150,
        'it_status': 1,
        'materials': [
          {
            'nr_material': 1,
            'vc_name': 'Luva',
            'vc_unit': 'par',
            'qt_used': 2,
            'vl_unit_cost': 0.38,
            'vl_line_cost': 0.76,
          },
        ],
        'pricing': {
          'vl_material': 2.76,
          'vl_lab': 0,
          'vl_structure': 46.71,
          'vl_professional': 50,
          'vl_direct_cost': 99.47,
          'vl_price': 222.68,
          'vl_price_min': 133.21,
          'vl_card': 8.91,
          'vl_commission': 15.59,
          'vl_fees': 6.68,
          'vl_tax': 25.23,
          'vl_profit': 66.8,
          'pc_profit_real': 30,
          'pc_total': 55.33,
          'it_tax_regime': 2,
          'id_valid': true,
        },
        'alerts': ['MATERIAL_NO_PRICE'],
      }),
    ],
    params: const PricingParams(
      nrCompany: 1,
      nrBranch: 1,
      qtRooms: 4,
      qtHoursWeek: 35,
      qtWeeksMonth: 4,
      pcOccupancy: 65,
      vlProfessionalHour: 50,
      pcCard: 4,
      pcCommission: 7,
      itTaxRegime: TaxRegime.pj,
      pcTaxPf: 27.5,
      pcTaxPj: 11.33,
      pcProfit: 30,
      idSaved: true,
    ),
    summary: const PricingSummary(
      vlMonthlyCost: 17002.23,
      qtProductiveHours: 364,
      vlStructureHour: 46.71,
      vlStructureHourCalc: 46.71,
      pcFees: 3,
      pcTax: 11.33,
      pcTotal: 55.33,
      itTaxRegime: TaxRegime.pj,
    ),
  );

  test('gera xlsx com as tres abas e os valores do procedimento', () {
    final now = DateTime(2026, 10, 14, 9, 30);
    final bytes = PricingExport.buildXlsx(data, now: now);
    expect(bytes, isNotEmpty);
    expect(PricingExport.fileName(now), 'precificacao_20261014_0930');

    final excel = Excel.decodeBytes(bytes);
    expect(
      excel.sheets.keys,
      containsAll([
        'Procedimentos',
        'Materiais por procedimento',
        'Parâmetros',
      ]),
    );
    final sheet = excel['Procedimentos'];
    final header = sheet.row(0).map((c) => c?.value.toString()).toList();
    expect(header.first, 'Código');
    expect(header, contains('Preço sugerido (R\$)'));
    final row = sheet.row(1).map((c) => c?.value).toList();
    expect(row[0].toString(), '1.0');
    expect(row[1].toString(), 'Profilaxia');
    final price = row[header.indexOf('Preço sugerido (R\$)')];
    expect(price, isA<DoubleCellValue>());
    expect((price as DoubleCellValue).value, 222.68);

    final mats = excel['Materiais por procedimento'];
    expect(mats.row(1)[1]!.value.toString(), 'Luva');

    final params = excel['Parâmetros'];
    expect(params.maxRows, greaterThan(8));
  });
}
