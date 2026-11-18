import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/errors/app_error.dart';
import 'package:odonto_app/features/agenda/domain/agenda_models.dart';
import 'package:odonto_app/features/agenda/presentation/patient_block_flow.dart';
import 'package:odonto_app/l10n/strings.dart';

void main() {
  test('Pendencia do paciente: leitura e textos', () {
    final b = PatientBlock.fromJson({
      'vc_kind': 'contract',
      'qt_entries': 1,
      'vl_total': 0,
      'vc_stage': 'checkin',
    })!;
    expect(b.kind, 'contract');
    expect(b.stage, 'checkin');
    expect(PatientBlock.fromJson(null), isNull);
    expect(isBlockConfirm('APPOINTMENT_CONTRACT_CONFIRM'), isTrue);
    expect(isBlockConfirm('CLINICAL_EVOLUTION_CONFIRM'), isTrue);
    expect(isBlockConfirm('APPOINTMENT_DEBT_BLOCKED'), isFalse);
    expect(PatientBlock.kindFromError('APPOINTMENT_OPEN_CONFIRM', {}), 'open');
    expect(
      PatientBlock.kindFromError('CLINICAL_EVOLUTION_CONFIRM', {
        'Kind': 'debt',
      }),
      'debt',
    );
    expect(Strings.blockWarning('contract', 'R\$ 0,00'), contains('contrato'));
    expect(
      Strings.errorMessage('APPOINTMENT_CONTRACT_BLOCKED', const {}, null),
      contains('contrato'),
    );
  });

  testWidgets('Confirmacao do administrador roda de novo com override', (
    tester,
  ) async {
    final calls = <bool>[];
    late BlockRun result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await runWithBlockConfirm(context, ({
                bool override = false,
              }) async {
                calls.add(override);
                if (!override) {
                  throw AppError(
                    key: 'APPOINTMENT_DEBT_CONFIRM',
                    parameters: const {'Amount': 120},
                  );
                }
                return const PatientBlock(kind: 'debt', amount: 120);
              });
            },
            child: const Text('salvar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('salvar'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.blockConfirmTitle('debt')), findsOneWidget);
    await tester.tap(find.text(Strings.blockConfirmAction));
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
    expect(result.done, isTrue);
    expect(result.block?.amount, 120);
  });
}
