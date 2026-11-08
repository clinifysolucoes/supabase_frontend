import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/whatsapp/domain/whatsapp_models.dart';

void main() {
  test('Configuracao do WhatsApp com padroes e totais', () {
    final s = WhatsappSettings.fromJson({
      'settings': {
        'id_enabled': true,
        'vc_phone_number_id': '1234567890',
        'id_token': true,
        'dh_token_saved': '2026-11-08T12:00:00Z',
        'qt_reminder_hours': 12,
      },
      'totals': {'2': 3, '9': 1},
      'permission': {'id_update': true},
    });
    expect(s.idEnabled, isTrue);
    expect(s.idToken, isTrue);
    expect(s.qtReminderHours, 12);
    expect(s.vcTplReminder, 'lembrete_consulta');
    expect(s.totals, {2: 3, 9: 1});
    expect(s.canUpdate, isTrue);
  });

  test('Historico com resposta e situacao', () {
    final p = WhatsappMessagePage.fromJson({
      'messages': [
        {
          'nr_message': 1,
          'it_kind': 1,
          'vc_patient': 'Lia',
          'vc_to': '5541999991234',
          'it_status': 4,
          'vc_reply': 'CONFIRM',
        },
      ],
      'qt_total': 7,
    });
    final m = p.messages.single;
    expect(WaKind.label(m.itKind), 'Lembrete');
    expect(WaStatus.label(m.itStatus), 'Lida');
    expect(m.replyLabel, 'Confirmou');
    expect(p.qtTotal, 7);
  });
}
