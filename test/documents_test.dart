import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/documents/data/document_pdf.dart';
import 'package:odonto_app/features/documents/domain/document_models.dart';

void main() {
  test('Modelo lista os extras que usa', () {
    final t = DocumentTemplate.fromJson({
      'nr_template': 1,
      'it_kind': 1,
      'vc_name': 'Atestado',
      'vc_body': '{{paciente}} afastado por {{dias}} dias. CID {{cid}}.',
    });
    expect(t.kind, DocumentKind.certificate);
    expect(t.extras, ['dias', 'cid']);
  });

  test('Documentos emitidos: receituario com itens, paciente e emitente', () {
    final l = PatientDocumentList.fromJson({
      'documents': [
        {
          'nr_document': 2,
          'it_kind': 2,
          'vc_title': 'Receituário',
          'dt_document': '2026-11-07',
          'vc_professional': 'Dra. Lia',
          'vc_council': 'CRO-PR 12345',
          'items': [
            {
              'nr_medication': 11,
              'vc_name': 'Amoxicilina',
              'vc_presentation': '500 mg cápsula',
              'it_use': 1,
            },
            {'vc_name': 'Tramadol', 'it_use': 1, 'id_controlled': true},
            {'vc_name': 'Clorexidina', 'it_use': 2},
          ],
        },
      ],
      'patient': {'vc_name': 'Davi', 'vc_cpf': '52998224725'},
      'issuer': {'vc_name': 'Clínica', 'vc_city': 'Curitiba'},
      'permission': {'id_create': true, 'id_update': true},
    });
    final d = l.documents.single;
    expect(d.kind, DocumentKind.prescription);
    expect(d.items.first.title, 'Amoxicilina 500 mg cápsula');
    expect(d.items[2].use, MedicationUse.external);
    expect(d.hasControlled, isTrue);
    expect(l.patient.vcCpf, '52998224725');
    expect(l.issuer.vcCity, 'Curitiba');
    expect(DocumentPdf.fileName(d), 'receituario_2');
  });

  test('Item do receituario manda a posologia editada', () {
    const m = Medication(
      nrMedication: 3,
      vcName: 'Ibuprofeno',
      vcDosage: '8/8 h',
      use: MedicationUse.internal,
    );
    final j = m.copyWith(vcDosage: '12/12 h').toItemJson();
    expect(j['nr_medication'], 3);
    expect(j['vc_dosage'], '12/12 h');
    expect(j['it_use'], 1);
  });

  test('PDF do documento e gerado', () async {
    final l = PatientDocumentList.fromJson({
      'documents': [
        {
          'nr_document': 1,
          'it_kind': 1,
          'vc_title': 'Atestado odontológico',
          'vc_body':
              'Atesto que Davi esteve em atendimento.\n\nCuritiba, 7 de novembro de 2026.',
          'dt_document': '2026-11-07',
        },
      ],
      'patient': {'vc_name': 'Davi'},
      'issuer': {'vc_name': 'Clínica'},
    });
    final bytes = await DocumentPdf.build(
      l.documents.single,
      patient: l.patient,
      issuer: l.issuer,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('Medicamento digitado fora do catalogo', () {
    const m = Medication(vcName: 'Gelo local');
    expect(m.isTyped, isTrue);
    final j = m
        .copyWith(use: MedicationUse.topical, vcDosage: '15 min')
        .toItemJson();
    expect(j.containsKey('nr_medication'), isFalse);
    expect(j['it_use'], 3);
    expect(j['vc_dosage'], '15 min');
  });
}
