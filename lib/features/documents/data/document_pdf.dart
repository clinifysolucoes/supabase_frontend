import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../finance/domain/receipt_models.dart';
import '../domain/document_models.dart';

/// PDF de um documento do paciente (A4): cabecalho da clinica, titulo, texto
/// (ou os medicamentos do receituario, agrupados por via de uso) e a
/// assinatura do profissional.
abstract final class DocumentPdf {
  static const _primary = PdfColor.fromInt(0xFF0E8C86);
  static const _muted = PdfColor.fromInt(0xFF6B7A80);

  static String fileName(PatientDocument d) {
    final slug = switch (d.kind) {
      DocumentKind.certificate => 'atestado',
      DocumentKind.prescription => 'receituario',
      DocumentKind.contract => 'contrato',
      DocumentKind.attendance => 'declaracao',
      DocumentKind.other => 'documento',
    };
    return '${slug}_${d.nrDocument}';
  }

  static Future<Uint8List> build(
    PatientDocument d, {
    required DocumentPatient patient,
    required ReceiptIssuer issuer,
  }) async {
    final i = issuer;
    final pdf = pw.Document(
      title: d.vcTitle,
      author: i.vcLegalName ?? i.vcName,
    );
    pw.Widget small(String t) =>
        pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _muted));
    final cpf = patient.vcCpf == null
        ? null
        : Masks.format(MaskType.cpf, patient.vcCpf!);

    final body = <pw.Widget>[];
    if (d.vcBody != null) {
      for (final p in d.vcBody!.split('\n')) {
        body.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              p,
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            ),
          ),
        );
      }
    }
    if (d.kind == DocumentKind.prescription) {
      if (d.vcBody == null) {
        body.add(
          pw.Text(
            'Paciente: ${patient.vcName}${cpf == null ? '' : ' · CPF $cpf'}',
          ),
        );
      }
      var n = 0;
      for (final use in MedicationUse.values) {
        final items = d.items.where((x) => x.use == use).toList();
        if (items.isEmpty) continue;
        body.add(pw.SizedBox(height: 12));
        body.add(
          pw.Text(
            use.label.toUpperCase(),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: _primary,
              letterSpacing: 1,
            ),
          ),
        );
        for (final m in items) {
          n++;
          body.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '$n. ${m.title}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      if (m.vcQuantity != null) pw.Text(m.vcQuantity!),
                    ],
                  ),
                  if (m.vcDosage != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 14, top: 2),
                      child: pw.Text(m.vcDosage!),
                    ),
                ],
              ),
            ),
          );
        }
      }
      if (d.hasControlled) {
        body.add(pw.SizedBox(height: 12));
        body.add(
          small(
            'Contém medicamento de controle especial: emitir também em '
            'receituário próprio, em duas vias (farmácia e paciente).',
          ),
        );
      }
    }

    final city = i.vcCity ?? '';
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              i.vcLegalName ?? i.vcName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            if (i.vcCnpj != null)
              small('CNPJ ${Masks.format(MaskType.cnpj, i.vcCnpj!)}'),
            if (i.addressLine != null) small(i.addressLine!),
            if (i.vcPhone != null)
              small(Masks.format(MaskType.phone, i.vcPhone!)),
            pw.SizedBox(height: 8),
            pw.Container(height: 2, color: _primary),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: small('Página ${ctx.pageNumber} de ${ctx.pagesCount}'),
        ),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              d.vcTitle.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          ...body,
          pw.SizedBox(height: 28),
          if (d.kind == DocumentKind.prescription)
            pw.Text(
              '${city.isEmpty ? '' : '$city, '}${Dates.format(d.dtDocument)}',
            ),
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.SizedBox(
              width: 260,
              child: pw.Column(
                children: [
                  pw.Container(height: 0.8, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    d.vcProfessional ?? i.vcTechnicalName ?? '',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (d.vcCouncil != null) small(d.vcCouncil!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}
