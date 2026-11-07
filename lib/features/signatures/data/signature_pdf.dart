import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../domain/signature_models.dart';

/// Bloco de assinaturas eletronicas para os PDFs (documento e orcamento):
/// traco, nome, papel e o registro (data/hora, CPF, IP, codigo e hash).
abstract final class SignaturePdf {
  static const _muted = PdfColor.fromInt(0xFF6B7A80);
  static const _danger = PdfColor.fromInt(0xFFD64545);

  /// Traco da assinatura; imagem ilegivel vira espaco em branco (o registro
  /// abaixo continua valendo).
  static pw.Widget _image(Signature s) {
    final bytes = s.imageBytes;
    if (bytes != null) {
      try {
        return pw.Image(
          pw.MemoryImage(bytes),
          height: 60,
          fit: pw.BoxFit.contain,
        );
      } catch (_) {
        // cai no espaco vazio
      }
    }
    return pw.SizedBox(height: 60);
  }

  static pw.Widget block(List<Signature> signatures) {
    pw.Widget small(String t, {PdfColor color = _muted}) =>
        pw.Text(t, style: pw.TextStyle(fontSize: 7, color: color));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Wrap(
          spacing: 24,
          runSpacing: 16,
          alignment: pw.WrapAlignment.spaceAround,
          children: [
            for (final s in signatures)
              pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _image(s),
                    pw.Container(height: 0.8, color: PdfColors.grey700),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      s.vcSignerName,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      s.role.label,
                      style: const pw.TextStyle(fontSize: 8, color: _muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColor.fromInt(0xFFDDE5E7),
              width: 0.6,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Assinado eletronicamente (assinatura eletrônica simples, Lei 14.063/2020)',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              for (final s in signatures)
                small(
                  [
                    '${s.vcSignerName} (${s.role.label})',
                    if (s.vcSignerCpf != null)
                      'CPF ${Masks.format(MaskType.cpf, s.vcSignerCpf!)}',
                    Dates.formatTime(s.dhSigned),
                    if (s.vcIp != null) 'IP ${s.vcIp}',
                    'código ${s.uuCode}',
                    if (!s.idValid) 'CONTEÚDO ALTERADO APÓS ESTA ASSINATURA',
                  ].join(' · '),
                  color: s.idValid ? _muted : _danger,
                ),
              for (final h in {for (final s in signatures) s.vcHash})
                small('Hash SHA-256 do conteúdo assinado: $h'),
            ],
          ),
        ),
      ],
    );
  }
}
