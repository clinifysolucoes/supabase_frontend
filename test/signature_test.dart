import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/documents/data/document_pdf.dart';
import 'package:odonto_app/features/documents/domain/document_models.dart';
import 'package:odonto_app/features/signatures/domain/signature_models.dart';
import 'package:odonto_app/features/signatures/presentation/signature_pad.dart';

void main() {
  // PNG 1x1 transparente
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  test('Assinatura le os dados e decodifica a imagem', () {
    final l = SignatureList.fromJson({
      'signatures': [
        {
          'nr_signature': 1,
          'it_signer': 2,
          'vc_signer_name': 'Ana',
          'tx_image': Signature.dataUrl(png),
          'vc_hash': 'ab' * 32,
          'uu_code': '7f1c0b2e-1111-2222-3333-444455556666',
          'dh_signed': '2026-11-08T12:00:00Z',
          'id_valid': false,
        },
      ],
    });
    final s = l.signatures.single;
    expect(s.role, SignerRole.guardian);
    expect(s.imageBytes, png);
    expect(l.hasInvalid, isTrue);
  });

  test('PDF do documento com o bloco de assinaturas', () async {
    final l = PatientDocumentList.fromJson({
      'documents': [
        {
          'nr_document': 1,
          'it_kind': 3,
          'vc_title': 'Contrato',
          'vc_body': 'Texto.',
          'qt_signatures': 1,
        },
      ],
      'patient': {'vc_name': 'Davi'},
      'issuer': {'vc_name': 'Clínica'},
    });
    expect(l.documents.single.qtSignatures, 1);
    final bytes = await DocumentPdf.build(
      l.documents.single,
      patient: l.patient,
      issuer: l.issuer,
      signatures: [
        Signature(
          nrSignature: 1,
          role: SignerRole.patient,
          vcSignerName: 'Davi',
          txImage: Signature.dataUrl(png),
          vcHash: 'cd' * 32,
          uuCode: 'abc',
          dhSigned: DateTime(2026, 11, 8, 10),
        ),
      ],
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('Quadro registra o traco e gera PNG', (tester) async {
    final c = SignaturePadController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, child: SignaturePad(controller: c)),
        ),
      ),
    );
    expect(c.isEmpty, isTrue);
    await tester.drag(find.byType(SignaturePad), const Offset(80, 20));
    expect(c.isEmpty, isFalse);
    c.clear();
    expect(c.isEmpty, isTrue);
  });
}
