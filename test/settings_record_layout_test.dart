import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/clinical_record/application/clinical_record_controllers.dart';
import 'package:odonto_app/features/clinical_record/domain/clinical_record_models.dart';
import 'package:odonto_app/features/clinical_record/presentation/anamnesis_models_section.dart';
import 'package:odonto_app/features/documents/application/document_controllers.dart';
import 'package:odonto_app/features/documents/domain/document_models.dart';
import 'package:odonto_app/features/documents/presentation/document_settings_sections.dart';

/// Configuracoes > Prontuario: as tres secoes empilhadas numa coluna rolavel,
/// como na tela, nao podem dar erro de layout.
void main() {
  testWidgets('Secao Prontuario das Configuracoes desenha sem erro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anamnesisModelsProvider.overrideWith(
            (ref, arg) async => const AnamnesisModelList(
              canUpdate: true,
              models: [
                AnamnesisModel(
                  nrModel: 1,
                  vcName: 'Geral',
                  questions: [AnamnesisQuestion(vcQuestion: 'Fuma?')],
                ),
              ],
            ),
          ),
          documentTemplatesProvider.overrideWith(
            (ref, arg) async => const DocumentTemplateList(
              canUpdate: true,
              fields: ['paciente'],
              templates: [
                DocumentTemplate(
                  nrTemplate: 1,
                  kind: DocumentKind.certificate,
                  vcName: 'Atestado',
                  vcBody: '{{paciente}}',
                ),
              ],
            ),
          ),
          medicationsProvider.overrideWith(
            (ref, arg) async => const MedicationList(
              canUpdate: true,
              medications: [Medication(nrMedication: 1, vcName: 'Dipirona')],
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnamnesisModelsSection(),
                  DocumentTemplatesSection(),
                  MedicationsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Geral'), findsOneWidget);
    expect(find.text('Atestado'), findsWidgets);
    expect(find.text('Dipirona'), findsOneWidget);
  });
}
