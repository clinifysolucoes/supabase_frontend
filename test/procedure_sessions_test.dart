import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/clinical_record/domain/clinical_record_models.dart';
import 'package:odonto_app/features/pricing/data/pricing_repository.dart';
import 'package:odonto_app/features/pricing/domain/pricing_models.dart';

void main() {
  test('Sessoes, retorno e tempo nos modelos', () {
    final r = PatientClinicalRecord.fromJson({
      'evolutions': [
        {
          'nr_evolution': 1,
          'vc_text': 'Sessão 1.',
          'nr_session': 1,
          'qt_minutes': 30,
        },
      ],
      'pending_items': [
        {
          'nr_budget': 5,
          'nr_item': 1,
          'vc_description': 'Manutenção',
          'qt_sessions': 3,
          'qt_sessions_done': 1,
        },
        {'nr_budget': 5, 'nr_item': 2, 'vc_description': 'Limpeza'},
      ],
      'record_settings': {'id_sessions': true, 'id_time': true},
    });
    expect(r.idSessions, isTrue);
    expect(r.idTime, isTrue);
    expect(r.idReturn, isFalse);
    expect(r.evolutions.single.qtMinutes, 30);
    expect(r.pendingItems.first.label, endsWith('sessão 2/3'));
    expect(r.pendingItems.last.label, 'Limpeza (orç. 5)');

    final p = Procedure.fromJson({
      'nr_procedure': 1,
      'vc_name': 'Manutenção',
      'qt_sessions': 3,
      'qt_return_days': 30,
    });
    expect(p.qtSessions, 3);
    expect(p.qtReturnDays, 30);
    final j = const ProcedureDraft(vcName: 'X', qtSessions: 2).toJson();
    expect(j['qt_sessions'], 2);
    expect(j.containsKey('qt_return_days'), isTrue);
  });
}
