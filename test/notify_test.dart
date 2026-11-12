import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/notify/domain/notify_models.dart';
import 'package:odonto_app/features/notify/presentation/notify_confirm_page.dart';
import 'package:odonto_app/features/notify/presentation/notify_section.dart';

final _settings = {
  'settings': {
    'id_email': true,
    'id_sms': false,
    'vc_email_from_name': null,
    'vc_email_reply_to': 'contato@clinica.local',
    'id_reminder': true,
    'qt_reminder_hours': 24,
    'id_booked': true,
    'id_return': true,
    'qt_send_hour': 9,
    'vc_tpl_reminder':
        'Olá, {{nome}}! Consulta na {{clinica}} em {{data}} às {{hora}}. Confirme: {{link}}',
    'vc_tpl_booked': 'Olá, {{nome}}! Marcada para {{data}}.',
    'vc_tpl_return': 'Olá, {{nome}}! {{retorno}}',
    'vc_clinic': 'Clínica Sorriso',
    'id_saved': true,
  },
  'totals': [
    {'it_channel': 1, 'it_status': 2, 'qt': 3},
    {'it_channel': 2, 'it_status': 9, 'qt': 1},
  ],
  'permission': {'id_update': true},
};

void main() {
  test('Le a configuracao e monta a previa', () {
    final s = NotifySettings.fromJson(_settings);
    expect(s.idEmail, isTrue);
    expect(s.totals[(1, 2)], 3);
    expect(s.canUpdate, isTrue);
    expect(
      notifyPreview(s.vcTplBooked, clinic: s.vcClinic),
      'Olá, Maria! Marcada para 15/03.',
    );
    expect(
      notifyPreview('Oi {{nome}} {{desconhecido}}', clinic: null),
      'Oi Maria',
    );
    expect(NotifyStatus.label(NotifyStatus.error), 'Erro');
  });

  test('Resultado da confirmacao', () {
    const ok = NotifyConfirmResult(itResult: 2);
    expect(ok.isConfirmed, isTrue);
    expect(const NotifyConfirmResult(itResult: 3).isConfirmed, isFalse);
  });

  testWidgets('Formulario desenha com previa', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotifyForm(settings: NotifySettings.fromJson(_settings)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Responder para'), findsOneWidget);
    expect(
      find.textContaining('Prévia: Olá, Maria! Consulta na Clínica Sorriso'),
      findsOneWidget,
    );
    expect(find.textContaining('E-mail · Enviada: 3'), findsOneWidget);
  });

  testWidgets('Pagina de confirmacao: confirmada e link invalido', (
    tester,
  ) async {
    Future<void> pump(NotifyConfirmResult r) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotifyConfirmView(result: r)),
      ),
    );
    await pump(
      const NotifyConfirmResult(
        itResult: 1,
        vcClinic: 'Clínica Sorriso',
        vcPatient: 'Lia',
        vcDate: '15/03/2027',
        vcTime: '14:30',
        vcProfessional: 'Dra. Rosa',
      ),
    );
    expect(find.text('Consulta confirmada!'), findsOneWidget);
    expect(
      find.text('Lia, sua consulta é em 15/03/2027 às 14:30 com Dra. Rosa.'),
      findsOneWidget,
    );
    await pump(const NotifyConfirmResult(itResult: 0));
    expect(find.text('Link inválido ou expirado.'), findsOneWidget);
  });
}
