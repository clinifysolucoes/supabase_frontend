import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/agenda/domain/agenda_models.dart';
import 'package:odonto_app/features/online_booking/domain/online_booking_models.dart';
import 'package:odonto_app/l10n/strings.dart';

void main() {
  test('Info da clinica lista os dias da janela', () {
    final c = OnlineClinic.fromJson({
      'clinic': {'vc_name': 'Clínica', 'vc_city': 'Curitiba'},
      'vc_message': 'Chegue antes.',
      'dt_today': '2026-11-07',
      'dt_last': '2026-11-10',
      'professionals': [
        {'nr_professional': 1, 'vc_name': 'Dra. Rosa', 'qt_slot_minutes': 60},
      ],
    });
    expect(c.days.map((d) => d.day), [7, 8, 9, 10]);
    expect(c.professionals.single.qtSlotMinutes, 60);
    expect(Strings.weekdayShort(c.days.first.weekday), 'sáb');
  });

  test('Configuracao e endereco publico', () {
    final s = OnlineBookingSettings.fromJson({
      'settings': {
        'id_enabled': true,
        'vc_slug': 'sorriso',
        'qt_days_ahead': 15,
        'qt_min_hours': 4,
        'id_saved': true,
      },
      'professionals': [
        {'nr_professional': 2, 'vc_name': 'Dr. A', 'id_online': true},
      ],
      'permission': {'id_update': true},
    });
    expect(s.idEnabled, isTrue);
    expect(s.qtDaysAhead, 15);
    expect(s.professionals.single.idOnline, isTrue);
    expect(
      OnlineBookingSettings.publicUrl('https://app.clinica.com', s.vcSlug),
      'https://app.clinica.com/agendar/sorriso',
    );
  });

  test('Consulta da agenda sabe que veio do agendamento online', () {
    final a = Appointment.fromJson({
      'nr_appointment': 1,
      'it_type': 1,
      'dh_start': '2026-11-09T13:00:00Z',
      'dh_end': '2026-11-09T14:00:00Z',
      'it_origin': 2,
    });
    expect(a.isOnline, isTrue);
    expect(
      Appointment.fromJson({
        'nr_appointment': 2,
        'dh_start': '2026-11-09T13:00:00Z',
        'dh_end': '2026-11-09T14:00:00Z',
      }).isOnline,
      isFalse,
    );
  });
}
