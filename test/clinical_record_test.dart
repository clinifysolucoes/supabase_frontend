import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/clinical_record/domain/clinical_record_models.dart';

void main() {
  test('PatientClinicalRecord le alertas, anamneses, evolucoes e marcas', () {
    final r = PatientClinicalRecord.fromJson({
      'alerts': [
        {'vc_question': 'Alergia?', 'vc_text': 'Penicilina'},
        {'vc_question': 'Diabetes?', 'vc_text': null},
      ],
      'anamneses': [
        {
          'nr_anamnesis': 2,
          'vc_model': 'Geral',
          'dt_filled': '2026-11-07',
          'answers': [
            {
              'nr_question': 1,
              'vc_question': 'Alergia?',
              'it_type': 3,
              'id_yes': true,
              'vc_text': 'Penicilina',
              'id_alert': true,
            },
            {'nr_question': 2, 'vc_question': 'Queixa', 'it_type': 2},
          ],
        },
      ],
      'evolutions': [
        {
          'nr_evolution': 1,
          'dh_evolution': '2026-11-07T10:00:00Z',
          'vc_text': 'Profilaxia',
          'nr_budget': 3,
          'nr_item': 1,
        },
      ],
      'marks': [
        {
          'nr_mark': 1,
          'vc_tooth': '36',
          'it_condition': 1,
          'vc_faces': 'OD',
          'it_situation': 2,
        },
        {'nr_mark': 2, 'vc_tooth': '55', 'it_condition': 3},
      ],
      'pending_items': [
        {
          'nr_budget': 3,
          'nr_item': 2,
          'vc_description': 'Canal',
          'vc_tooth': '46',
        },
      ],
      'permission': {'id_create': true, 'id_update': false},
    });
    expect(r.alerts, ['Alergia?: Penicilina', 'Diabetes?']);
    expect(r.anamneses.single.alertCount, 1);
    expect(r.anamneses.single.answers[1].isAnswered, isFalse);
    expect(r.anamneses.single.answers[1].type, QuestionType.text);
    expect(r.evolutions.single.nrBudget, 3);
    expect(r.marksOf('36').single.condition, ToothCondition.caries);
    expect(r.marksOf('36').single.situation, ToothSituation.toTreat);
    expect(r.marksOf('55').single.situation, ToothSituation.existing);
    expect(r.pendingItems.single.label, 'Canal · 46 (orç. 3)');
    expect(r.canCreate, isTrue);
    expect(r.canUpdate, isFalse);
  });

  test('Odontograma tem 32 permanentes e 20 deciduos validos', () {
    final perm = [...Teeth.permanentUpper, ...Teeth.permanentLower];
    final dec = [...Teeth.deciduousUpper, ...Teeth.deciduousLower];
    expect(perm.toSet(), hasLength(32));
    expect(dec.toSet(), hasLength(20));
    expect([...perm, ...dec].every(Teeth.isValid), isTrue);
    expect(Teeth.isValid('19'), isFalse);
    expect(Teeth.isValid('56'), isFalse);
  });

  test('Pergunta de texto livre nao manda alerta', () {
    const q = AnamnesisQuestion(
      vcQuestion: 'Expectativa',
      type: QuestionType.text,
      idAlert: true,
    );
    expect(q.toJson(), {
      'vc_question': 'Expectativa',
      'it_type': 2,
      'id_alert': false,
    });
    final m = AnamnesisModelList.fromJson({
      'models': [
        {
          'nr_model': 1,
          'vc_name': 'Geral',
          'questions': [
            {'nr_question': 1, 'vc_question': 'Fuma?', 'it_type': 1},
          ],
        },
      ],
      'permission': {'id_update': true},
    });
    expect(m.models.single.questions.single.type, QuestionType.yesNo);
    expect(m.canUpdate, isTrue);
  });
}
