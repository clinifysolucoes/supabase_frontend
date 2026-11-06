import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/agenda/application/agenda_controllers.dart';
import 'package:odonto_app/features/agenda/data/agenda_repository.dart';
import 'package:odonto_app/features/agenda/domain/agenda_models.dart';
import 'package:odonto_app/features/agenda/presentation/agenda_calendar_tab.dart';
import 'package:odonto_app/features/agenda/presentation/agenda_grid.dart';
import 'package:odonto_app/features/profiles/application/profiles_controller.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

final _day = DateTime(2026, 11, 3); // terca

/// ISO com fuso, como devolve o banco, para [h]:[m] local do dia de teste.
String _iso(int h, int m) =>
    DateTime(2026, 11, 3, h, m).toUtc().toIso8601String();

Map<String, dynamic> _appt(
  int nr,
  int prof,
  int h1,
  int m1,
  int h2,
  int m2, {
  String patient = 'Paciente Um',
  int status = 1,
  bool fitIn = false,
}) => {
  'nr_appointment': nr,
  'it_type': 1,
  'nr_patient': nr,
  'vc_patient_name': patient,
  'nr_professional': prof,
  'vc_professional_name': prof == 1 ? 'Dra. Ana' : 'Dr. Bruno',
  'vc_professional_color': prof == 1 ? '#0E8C86' : '#E9A23B',
  'dh_start': _iso(h1, m1),
  'dh_end': _iso(h2, m2),
  'id_fit_in': fitIn,
  'it_status': status,
  'vc_created_by': 'Recepção',
  'dh_created': _iso(8, 0),
};

final _profs = ProfessionalListData.fromJson({
  'professionals': [
    {
      'nr_professional': 1,
      'vc_name': 'Dra. Ana',
      'vc_color': '#0E8C86',
      'qt_slot_minutes': 30,
      'it_status': 1,
      'schedules': [
        {'it_weekday': 2, 'qt_minute_start': 480, 'qt_minute_end': 720},
      ],
    },
    {
      'nr_professional': 2,
      'vc_name': 'Dr. Bruno',
      'vc_color': '#E9A23B',
      'qt_slot_minutes': 30,
      'it_status': 1,
      'schedules': [
        {'it_weekday': 2, 'qt_minute_start': 780, 'qt_minute_end': 1080},
      ],
    },
  ],
  'users': [],
});

class _FakeRepo implements AgendaRepository {
  final changes = <Map<String, dynamic>>[];
  AppointmentDraft? created;

  @override
  Future<ProfessionalListData> professionals({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async => _profs;

  @override
  Future<AppointmentListData> appointments({
    required int nrCompany,
    required int nrBranch,
    required DateTime from,
    required DateTime to,
    List<int>? professionals,
    bool includeCancelled = false,
  }) async => AppointmentListData.fromJson({
    'appointments': [
      _appt(1, 1, 9, 0, 10, 0),
      _appt(2, 2, 14, 0, 14, 30, patient: 'Paciente Dois', status: 2),
    ],
    'return_alerts': [],
  });

  @override
  Future<double?> createAppointment({
    required int nrCompany,
    required int nrBranch,
    required AppointmentDraft draft,
    bool debtOverride = false,
  }) async {
    created = draft;
    return null;
  }

  @override
  Future<double?> updateAppointment({
    required int nrCompany,
    required int nrBranch,
    required int nrAppointment,
    required Map<String, dynamic> changes,
    bool debtOverride = false,
  }) async {
    this.changes.add({'nr': nrAppointment, ...changes});
    return null;
  }

  @override
  Future<int> createProfessional({
    required int nrCompany,
    required int nrBranch,
    required ProfessionalDraft draft,
  }) async => 1;

  @override
  Future<void> updateProfessional({
    required int nrCompany,
    required int nrBranch,
    required int nrProfessional,
    required ProfessionalDraft draft,
  }) async {}
}

void main() {
  group('modelos', () {
    test('periodo de cada visao', () {
      final d = agendaRange(AgendaView.day, _day);
      expect(d.from, _day);
      expect(d.to, _day);
      final w = agendaRange(AgendaView.week, _day);
      expect(w.from, DateTime(2026, 11, 1), reason: 'domingo');
      expect(w.to, DateTime(2026, 11, 7));
      final m = agendaRange(AgendaView.month, _day);
      expect(m.from, DateTime(2026, 11, 1), reason: '01/11/2026 e domingo');
      expect(m.to.difference(m.from).inDays, 41);
    });

    test('agendamento: hora local, minutos e coluna', () {
      final a = Appointment.fromJson(_appt(1, 1, 9, 0, 10, 0));
      expect(a.dhStart, DateTime(2026, 11, 3, 9));
      expect(a.startMinute, 540);
      expect(a.endMinute, 600);
      expect(a.durationMinutes, 60);
      expect(a.occursOn(_day), isTrue);
      expect(a.belongsTo(1), isTrue);
      expect(a.belongsTo(2), isFalse);
      final clinic = Appointment.fromJson({
        'nr_appointment': 9,
        'it_type': 2,
        'vc_title': 'Reunião',
        'dh_start': _iso(12, 0),
        'dh_end': _iso(13, 0),
      });
      expect(clinic.isClinicWide, isTrue);
      expect(clinic.belongsTo(2), isTrue, reason: 'clinica toda em todas');
      expect(clinic.headline, 'Reunião');
    });

    test('rascunho vai em UTC', () {
      final j = AppointmentDraft(
        itType: AppointmentType.consultation,
        dhStart: DateTime(2026, 11, 3, 9),
        dhEnd: DateTime(2026, 11, 3, 10),
        nrPatient: 1,
        nrProfessional: 1,
      ).toJson();
      expect(j['dh_start'], DateTime(2026, 11, 3, 9).toUtc().toIso8601String());
      expect((j['dh_start'] as String).endsWith('Z'), isTrue);
      expect(j.containsKey('it_status'), isFalse);
    });

    test('encaixes lado a lado', () {
      final a = Appointment.fromJson(_appt(1, 1, 9, 0, 10, 0));
      final b = Appointment.fromJson(_appt(2, 1, 9, 30, 9, 45, fitIn: true));
      final c = Appointment.fromJson(_appt(3, 1, 10, 0, 10, 30));
      final placed = layoutLanes([c, b, a]);
      int lanesOf(Appointment x) =>
          placed.firstWhere((p) => p.a.nrAppointment == x.nrAppointment).lanes;
      expect(lanesOf(a), 2);
      expect(lanesOf(b), 2);
      expect(lanesOf(c), 1, reason: 'encostado nao divide');
    });

    test('janela da grade', () {
      final w = TimeGrid.window(
        _profs.professionals.expand((p) => p.schedules),
        const [],
      );
      expect(w.from, 480);
      expect(w.to, 1080);
      expect(TimeGrid.window(const [], const []).from, 480);
    });

    test('titulo e navegacao', () {
      expect(
        AgendaCalendarTab.title(AgendaView.day, _day),
        'Terça, 3 de novembro de 2026',
      );
      expect(
        AgendaCalendarTab.shift(AgendaView.month, DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 1),
      );
    });
  });

  group('tela', () {
    late _FakeRepo repo;

    Widget app() => ProviderScope(
      overrides: [
        agendaRepositoryProvider.overrideWithValue(repo),
        currentCompanyProvider.overrideWith((ref) => 1),
        currentBranchNumberProvider.overrideWith((ref) => 1),
        canReadProvider.overrideWith((ref, code) => true),
        canCreateProvider.overrideWith((ref, code) => true),
        canUpdateProvider.overrideWith((ref, code) => true),
        agendaDayProvider.overrideWith((ref) => _day),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AgendaCalendarTab(),
          ),
        ),
      ),
    );

    setUp(() => repo = _FakeRepo());

    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    testWidgets('dia: colunas por profissional e cartoes', (tester) async {
      await pump(tester, const Size(1400, 900));
      expect(find.text('Dra. Ana'), findsWidgets);
      expect(find.text('Dr. Bruno'), findsWidgets);
      expect(find.text('Paciente Um'), findsOneWidget);
      expect(find.text('09:00 – 10:00'), findsOneWidget);
      expect(find.text(Strings.patientsCount(1)), findsNWidgets(2));
      expect(find.text(Strings.returnAlerts), findsOneWidget);
    });

    testWidgets('detalhe: troca a situacao', (tester) async {
      await pump(tester, const Size(1400, 900));
      await tester.tap(find.text('Paciente Um'));
      await tester.pumpAndSettle();
      expect(
        find.text(Strings.scheduledBy('Recepção', '03/11/2026 08:00')),
        findsOneWidget,
      );
      await tester.tap(find.text(Strings.statusConfirmed));
      await tester.pumpAndSettle();
      expect(repo.changes.single, {'nr': 1, 'it_status': 2});
    });

    testWidgets('semana e mes', (tester) async {
      await pump(tester, const Size(1400, 900));
      await tester.tap(find.text(Strings.viewWeek));
      await tester.pumpAndSettle();
      expect(find.text('Ter 03'), findsOneWidget);
      expect(find.text('Paciente Dois'), findsOneWidget);
      await tester.tap(find.text(Strings.viewMonth));
      await tester.pumpAndSettle();
      expect(find.text('09:00 Paciente Um'), findsWidgets);
    });

    testWidgets('celular: lista do dia', (tester) async {
      await pump(tester, const Size(390, 800));
      expect(find.text(Strings.viewWeek), findsNothing);
      expect(find.text('Paciente Um'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
    });
  });
}
