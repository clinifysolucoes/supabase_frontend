import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/settings/domain/settings_models.dart';

void main() {
  test('BranchSettings usa os padroes quando a filial nao tem linha', () {
    final s = BranchSettings.fromJson({
      'clinic': {'vc_name': 'Matriz'},
      'settings': <String, dynamic>{},
      'hours': <dynamic>[],
      'permission': {'id_update': true, 'id_clinic': false},
    });
    expect(s.clinic.vcName, 'Matriz');
    expect(s.qtSlotMinutes, 15);
    expect(s.qtMaxParallel, 1);
    expect(s.idAllowOutsideHours, isTrue);
    expect(s.idAutoRecordNumber, isFalse);
    expect(s.nrNextRecord, 1);
    expect(s.canUpdate, isTrue);
    expect(s.canEditClinic, isFalse);
  });

  test('BranchSettings le valores e horarios', () {
    final s = BranchSettings.fromJson({
      'clinic': {'vc_technical_cro_state': 'PR', 'vc_forum_city': 'Curitiba'},
      'settings': {
        'qt_slot_minutes': 30,
        'qt_max_parallel': 2,
        'id_allow_outside_hours': false,
        'id_auto_record_number': true,
        'nr_next_record': 100,
        'id_require_cpf': true,
        'id_require_mobile': true,
      },
      'hours': [
        {'it_weekday': 1, 'qt_minute_start': 480, 'qt_minute_end': 720},
      ],
      'permission': {'id_update': true, 'id_clinic': true},
    });
    expect(s.qtSlotMinutes, 30);
    expect(s.qtMaxParallel, 2);
    expect(s.idAllowOutsideHours, isFalse);
    expect(s.nrNextRecord, 100);
    expect(s.idRequireCpf && s.idRequireMobile, isTrue);
    expect(s.hours, hasLength(1));
    expect(s.clinic.vcForumCity, 'Curitiba');
  });
}
