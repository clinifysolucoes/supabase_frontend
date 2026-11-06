import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/finance/data/receipt_pdf.dart';
import 'package:odonto_app/features/finance/domain/receipt_models.dart';
import 'package:odonto_app/shared/formatters/extenso.dart';

void main() {
  group('valor por extenso', () {
    test('inteiros', () {
      expect(Extenso.number(0), 'zero');
      expect(Extenso.number(1), 'um');
      expect(Extenso.number(15), 'quinze');
      expect(Extenso.number(21), 'vinte e um');
      expect(Extenso.number(100), 'cem');
      expect(Extenso.number(101), 'cento e um');
      expect(Extenso.number(250), 'duzentos e cinquenta');
      expect(Extenso.number(1000), 'mil');
      expect(Extenso.number(1001), 'mil e um');
      expect(Extenso.number(1100), 'mil e cem');
      expect(Extenso.number(1250), 'mil, duzentos e cinquenta');
      expect(Extenso.number(2000000), 'dois milhões');
      expect(Extenso.number(1000500), 'um milhão e quinhentos');
    });

    test('reais e centavos', () {
      expect(Extenso.money(1), 'um real');
      expect(Extenso.money(0.01), 'um centavo');
      expect(Extenso.money(250), 'duzentos e cinquenta reais');
      expect(
        Extenso.money(1250.5),
        'mil, duzentos e cinquenta reais e cinquenta centavos',
      );
      expect(Extenso.money(1000000), 'um milhão de reais');
      expect(Extenso.money(0), 'zero real');
    });
  });

  final json = {
    'receipt': {
      'nr_receipt': 10,
      'vc_number': 'REC-000010',
      'nr_entry': 3,
      'vl_amount': 250,
      'dt_paid': '2030-03-04',
      'it_payment_method': 2,
      'vc_payer_name': 'Ana Recibo',
      'vc_payer_document': '52998224725',
      'vc_description': 'Restauração',
      'it_status': 1,
    },
    'issuer': {
      'vc_name': 'Clínica Sorriso',
      'vc_legal_name': 'Sorriso Odontologia Ltda',
      'vc_cnpj': '11222333000181',
      'vc_address': 'Rua A',
      'vc_address_number': '10',
      'vc_district': 'Centro',
      'vc_city': 'Curitiba',
      'vc_state': 'PR',
      'vc_technical_name': 'Dra. Mel',
      'vc_technical_cro': '1234',
      'vc_technical_cro_state': 'PR',
    },
    'id_existing': true,
  };

  test('ReceiptDoc le recibo e emitente', () {
    final d = ReceiptDoc.fromJson(json);
    expect(d.receipt.vcNumber, 'REC-000010');
    expect(d.receipt.vlAmount, 250);
    expect(d.receipt.dtPaid, DateTime(2030, 3, 4));
    expect(d.idExisting, isTrue);
    expect(d.issuer.addressLine, 'Rua A, 10 - Centro - Curitiba/PR');
    expect(ReceiptPdf.fileName(d.receipt), 'recibo_REC-000010');
  });

  test('PDF do recibo e gerado', () async {
    final bytes = await ReceiptPdf.build(
      ReceiptDoc.fromJson(json),
      now: DateTime(2030, 3, 4),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
