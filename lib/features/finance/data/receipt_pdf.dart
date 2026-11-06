import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/extenso.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../domain/finance_models.dart';
import '../domain/receipt_models.dart';

/// PDF do recibo (A4, uma via): emitente, numero, valor, "recebemos de",
/// valor por extenso, referente a, forma e data, local/data e assinatura.
abstract final class ReceiptPdf {
  static const _primary = PdfColor.fromInt(0xFF0E8C86);
  static const _muted = PdfColor.fromInt(0xFF6B7A80);

  /// Moeda sem os espacos especiais (fora da fonte padrao do PDF).
  static String _money(double v) =>
      Numbers.money(v).replaceAll(RegExp('[  ]'), ' ');

  static String fileName(Receipt r) =>
      'recibo_${r.vcNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';

  static String _doc(String? digits) {
    if (digits == null || digits.isEmpty) return '';
    return Masks.format(
      digits.length == 14 ? MaskType.cnpj : MaskType.cpf,
      digits,
    );
  }

  static Future<Uint8List> build(ReceiptDoc doc, {DateTime? now}) async {
    final r = doc.receipt;
    final i = doc.issuer;
    final pdf = pw.Document(
      title: 'Recibo ${r.vcNumber}',
      author: i.vcLegalName ?? i.vcName,
    );
    final payerDoc = _doc(r.vcPayerDocument);
    final method = r.itPaymentMethod == null
        ? null
        : PaymentMethod.label(r.itPaymentMethod);
    final place = [i.vcCity, i.vcState].whereType<String>().join('/');
    final technical = i.vcTechnicalName == null
        ? null
        : [
            i.vcTechnicalName,
            if (i.vcTechnicalCro != null)
              'CRO${i.vcTechnicalCroState == null ? '' : '-${i.vcTechnicalCroState}'} ${i.vcTechnicalCro}',
          ].join(' · ');

    pw.Widget small(String text) =>
        pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _muted));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // emitente
            pw.Text(
              i.vcLegalName ?? i.vcName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (i.vcLegalName != null && i.vcLegalName != i.vcName)
              small(i.vcName),
            if (i.vcCnpj != null) small('CNPJ ${_doc(i.vcCnpj)}'),
            if (i.addressLine != null) small(i.addressLine!),
            if (i.vcPhone != null || i.vcEmail != null)
              small(
                [
                  if (i.vcPhone != null)
                    Masks.format(MaskType.phone, i.vcPhone!),
                  ?i.vcEmail,
                ].join(' · '),
              ),
            pw.SizedBox(height: 24),
            pw.Container(height: 2, color: _primary),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RECIBO',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      'Nº ${r.vcNumber}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _primary, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    _money(r.vlAmount),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (r.isCancelled) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'RECIBO CANCELADO${r.vcCancelReason == null ? '' : ': ${r.vcCancelReason}'}',
                style: pw.TextStyle(
                  color: PdfColors.red,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            pw.SizedBox(height: 28),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 6),
                children: [
                  const pw.TextSpan(text: 'Recebemos de '),
                  pw.TextSpan(
                    text: r.vcPayerName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (payerDoc.isNotEmpty)
                    pw.TextSpan(
                      text: r.vcPayerDocument!.length == 14
                          ? ', CNPJ $payerDoc'
                          : ', CPF $payerDoc',
                    ),
                  const pw.TextSpan(text: ', a importância de '),
                  pw.TextSpan(
                    text: _money(r.vlAmount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(
                    text: ' (${Extenso.money(r.vlAmount)}), referente a ',
                  ),
                  pw.TextSpan(
                    text: r.vcDescription,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(
                    text:
                        ', pago em ${Dates.format(r.dtPaid)}'
                        '${method == null ? '' : ' via $method'}.',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Para clareza, firmamos o presente recibo dando plena quitação do valor acima.',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              '${place.isEmpty ? '' : '$place, '}${Dates.format(now ?? DateTime.now())}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 60),
            pw.Center(
              child: pw.Container(
                width: 280,
                height: 0.8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                i.vcLegalName ?? i.vcName,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            if (technical != null)
              pw.Center(child: small('Responsável técnico: $technical')),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: small('Recibo ${r.vcNumber}'),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
