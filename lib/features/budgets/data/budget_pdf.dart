import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/budget_models.dart';

/// PDF do orcamento (A4): emitente, paciente, itens com dente/regiao,
/// desconto, total, validade, condicao de pagamento e assinaturas.
abstract final class BudgetPdf {
  static const _primary = PdfColor.fromInt(0xFF0E8C86);
  static const _muted = PdfColor.fromInt(0xFF6B7A80);
  static const _line = PdfColor.fromInt(0xFFDDE5E7);

  static String _money(double v) =>
      Numbers.money(v).replaceAll(RegExp('[  ]'), ' ');

  static String fileName(Budget b) => 'orcamento_${b.nrBudget}';

  static Future<Uint8List> build(Budget b) async {
    final i = b.issuer;
    final pdf = pw.Document(
      title: 'Orçamento ${b.nrBudget}',
      author: i.vcLegalName ?? i.vcName,
    );
    pw.Widget small(String t) =>
        pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _muted));
    pw.Widget cell(String t, {bool bold = false, pw.TextAlign? align}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            t,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );
    final cpf = b.vcPatientCpf == null
        ? null
        : Masks.format(MaskType.cpf, b.vcPatientCpf!);
    final technical = i.vcTechnicalName == null
        ? null
        : [
            i.vcTechnicalName,
            if (i.vcTechnicalCro != null)
              'CRO${i.vcTechnicalCroState == null ? '' : '-${i.vcTechnicalCroState}'} ${i.vcTechnicalCro}',
          ].join(' · ');
    final terms = [
      if (b.qtInstallments != null)
        b.qtInstallments == 1
            ? 'À vista'
            : '${b.qtInstallments}x de ${_money(b.vlTotal / b.qtInstallments!)}',
      if (b.itPaymentMethod != null) PaymentMethod.label(b.itPaymentMethod),
    ].join(' · ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        i.vcLegalName ?? i.vcName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (i.vcCnpj != null)
                        small('CNPJ ${Masks.format(MaskType.cnpj, i.vcCnpj!)}'),
                      if (i.addressLine != null) small(i.addressLine!),
                      if (i.vcPhone != null)
                        small(Masks.format(MaskType.phone, i.vcPhone!)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ORÇAMENTO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.Text('Nº ${b.nrBudget}'),
                    small('Emitido em ${Dates.format(b.dtBudget)}'),
                    small('Válido até ${Dates.format(b.dtValid)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Container(height: 2, color: _primary),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: small('Página ${ctx.pageNumber} de ${ctx.pagesCount}'),
        ),
        build: (_) => [
          pw.Text(
            'Paciente: ${b.vcPatient}${cpf == null ? '' : ' · CPF $cpf'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (b.vcProfessional != null)
            small('Profissional: ${b.vcProfessional}'),
          if (b.vcTitle != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(b.vcTitle!, style: const pw.TextStyle(fontSize: 12)),
          ],
          pw.SizedBox(height: 12),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _line, width: 0.6),
              bottom: pw.BorderSide(color: _line, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(5),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE6F4F3),
                ),
                children: [
                  cell('Procedimento', bold: true),
                  cell('Dente/região', bold: true),
                  cell('Qtd.', bold: true, align: pw.TextAlign.right),
                  cell('Unitário', bold: true, align: pw.TextAlign.right),
                  cell('Total', bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (final it in b.items)
                pw.TableRow(
                  children: [
                    cell(it.vcDescription),
                    cell(it.vcTooth ?? ''),
                    cell(Numbers.qty(it.qtQuantity), align: pw.TextAlign.right),
                    cell(_money(it.vlUnit), align: pw.TextAlign.right),
                    cell(_money(it.vlTotal), align: pw.TextAlign.right),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _total('Subtotal', _money(b.vlGross)),
                  if (b.vlDiscount > 0)
                    _total(
                      'Desconto (${Numbers.percent(b.pcDiscount)})',
                      '- ${_money(b.vlDiscount)}',
                    ),
                  pw.Divider(color: _line),
                  _total('Total', _money(b.vlTotal), bold: true),
                ],
              ),
            ),
          ),
          if (terms.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Condição de pagamento: $terms'),
          ],
          if (b.vcNotes != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Observações:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(b.vcNotes!),
          ],
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signature(b.vcPatient, 'Paciente ou responsável'),
              _signature(
                i.vcLegalName ?? i.vcName,
                technical == null
                    ? 'Clínica'
                    : 'Responsável técnico: $technical',
              ),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _total(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : null,
                fontSize: bold ? 13 : 11,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _signature(String name, String role) => pw.SizedBox(
    width: 220,
    child: pw.Column(
      children: [
        pw.Container(height: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 4),
        pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(role, style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );
}
