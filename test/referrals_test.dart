import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/patients/domain/patient_models.dart';
import 'package:odonto_app/features/referrals/domain/referral_models.dart';
import 'package:odonto_app/features/referrals/presentation/referrals_page.dart';

final _json = {
  'totals': {
    'qt_new': 5,
    'qt_referred': 3,
    'qt_converted': 2,
    'pc_conversion': 66.7,
    'qt_pending_reward': 1,
    'qt_rewarded': 1,
    'vl_rewards': 50,
  },
  'referrers': [
    {
      'vc_key': 'p1',
      'nr_referrer': 1,
      'vc_referrer': 'Ana Ref',
      'qt_referred': 2,
      'qt_converted': 1,
      'vl_approved': 500,
      'vl_received': 0,
      'qt_rewarded': 1,
      'qt_pending': 0,
    },
    {
      'vc_key': 'tdr. paulo',
      'vc_referrer': 'Dr. Paulo',
      'qt_referred': 1,
      'qt_converted': 1,
      'vl_approved': 300,
      'vl_received': null,
      'qt_rewarded': 0,
      'qt_pending': 1,
    },
  ],
  'referrals': [
    {
      'nr_patient': 3,
      'vc_patient': 'Caio Ref',
      'dh_created': '2026-11-10T13:00:00Z',
      'vc_referrer': 'Dr. Paulo',
      'id_converted': true,
      'vl_approved': 300,
    },
    {
      'nr_patient': 2,
      'vc_patient': 'Beto Ref',
      'dh_created': '2026-11-09T13:00:00Z',
      'nr_referrer': 1,
      'vc_referrer': 'Ana Ref',
      'id_converted': true,
      'vl_approved': 500,
      'dt_reward': '2026-11-11',
      'vc_reward': 'Kit clareamento',
      'vl_reward': 50,
    },
    {
      'nr_patient': 5,
      'vc_patient': 'Eva Ref',
      'nr_referrer': 1,
      'vc_referrer': 'Ana Ref',
      'id_converted': false,
    },
  ],
  'by_source': [
    {'it_source': 4, 'qt_new': 3, 'qt_converted': 2},
    {'it_source': null, 'qt_new': 1, 'qt_converted': 0},
  ],
  'permission': {'id_update': true, 'id_budgets': true, 'id_finance': true},
};

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  test('Le indicados, ranking e origem', () {
    final d = ReferralData.fromJson(_json);
    expect(d.referrals.first.isPending, isTrue);
    expect(d.referrals[1].isRewarded, isTrue);
    expect(d.referrals.last.isPending, isFalse);
    expect(d.referrers.first.isPatient, isTrue);
    expect(d.referrers.last.vlReceived, isNull);
    expect(d.bySource.last.source, isNull);
    expect(d.canUpdate, isTrue);
  });

  test('Ficha mostra quem indicou', () {
    final p = Patient.fromJson({
      'nr_patient': 2,
      'vc_name': 'Beto',
      'it_status': 1,
      'it_source': 4,
      'nr_referrer': 1,
      'vc_referrer': 'Ana Ref',
    });
    expect(p.sourceLabel, 'Indicação: Ana Ref');
  });

  testWidgets('Abas desenham', (tester) async {
    final d = ReferralData.fromJson(_json);
    await _pump(tester, ListView(children: [ReferralTotals(data: d)]));
    expect(find.text('Recompensas pendentes'), findsOneWidget);
    await _pump(tester, ReferralListTab(data: d));
    expect(find.text('Registrar recompensa'), findsNWidgets(2));
    expect(find.textContaining('Kit clareamento'), findsOneWidget);
    await _pump(tester, ReferrerRankingTab(data: d));
    expect(find.text('Ana Ref'), findsOneWidget);
    expect(find.text('0 (1 pendente)'), findsOneWidget);
    await _pump(tester, ReferralSourcesTab(data: d));
    expect(find.text('Não informado'), findsOneWidget);
  });
}
