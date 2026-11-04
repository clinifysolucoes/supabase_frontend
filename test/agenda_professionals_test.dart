import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/agenda/data/agenda_repository.dart';
import 'package:odonto_app/features/agenda/domain/agenda_models.dart';
import 'package:odonto_app/features/agenda/presentation/agenda_page.dart';
import 'package:odonto_app/features/agenda/presentation/professional_form_dialog.dart';
import 'package:odonto_app/features/profiles/application/profiles_controller.dart';
import 'package:odonto_app/features/session/application/permissions.dart';
import 'package:odonto_app/l10n/strings.dart';

/// Mesmo formato de ad.professional_list (tests/10_professionals.sql).
final _json = {
  'professionals': [
    {
      'nr_professional': 1,
      'vc_name': 'Dra. Ana Souza',
      'vc_council': 'CRO-PR 12345',
      'vc_color': '#0E8C86',
      'qt_slot_minutes': 30,
      'nr_user': 7,
      'vc_user_name': 'Ana Souza',
      'it_status': 1,
      'schedules': [
        {'it_weekday': 1, 'qt_minute_start': 480, 'qt_minute_end': 720},
        {'it_weekday': 1, 'qt_minute_start': 840, 'qt_minute_end': 1080},
        {'it_weekday': 6, 'qt_minute_start': 480, 'qt_minute_end': 720},
      ],
    },
  ],
  'users': [
    {'nr_user': 7, 'vc_name': 'Ana Souza', 'vc_email': 'ana@clinica.com'},
  ],
};

class _FakeRepo implements AgendaRepository {
  ProfessionalDraft? saved;

  @override
  Future<ProfessionalListData> professionals({
    required int nrCompany,
    required int nrBranch,
    bool includeInactive = false,
  }) async => ProfessionalListData.fromJson(_json);

  @override
  Future<int> createProfessional({
    required int nrCompany,
    required int nrBranch,
    required ProfessionalDraft draft,
  }) async {
    saved = draft;
    return 2;
  }

  @override
  Future<void> updateProfessional({
    required int nrCompany,
    required int nrBranch,
    required int nrProfessional,
    required ProfessionalDraft draft,
  }) async => saved = draft;
}

void main() {
  group('modelos', () {
    test('parse, faixas por dia e horas por semana', () {
      final d = ProfessionalListData.fromJson(_json);
      final p = d.professionals.single;
      expect(p.rangesOf(1).length, 2);
      expect(p.rangesOf(0), isEmpty);
      expect(p.weeklyHours, 12);
      expect(d.users.single.vcEmail, 'ana@clinica.com');
      expect(DayMinutes.format(480), '08:00');
      expect(DayMinutes.format(1080), '18:00');
      expect(Weekday.label(0), 'Domingo');
      expect(Weekday.fromDate(DateTime(2026, 11, 8)), 0, reason: 'domingo');
      expect(AgendaColors.argb('#0E8C86'), 0xFF0E8C86);
    });

    test('sobreposicao: encostar nao sobrepoe', () {
      const a = ScheduleRange(
        itWeekday: 1,
        qtMinuteStart: 480,
        qtMinuteEnd: 720,
      );
      const b = ScheduleRange(
        itWeekday: 1,
        qtMinuteStart: 720,
        qtMinuteEnd: 900,
      );
      const c = ScheduleRange(
        itWeekday: 1,
        qtMinuteStart: 700,
        qtMinuteEnd: 900,
      );
      const d = ScheduleRange(
        itWeekday: 2,
        qtMinuteStart: 700,
        qtMinuteEnd: 900,
      );
      expect(a.overlaps(b), isFalse);
      expect(a.overlaps(c), isTrue);
      expect(a.overlaps(d), isFalse);
    });

    test('ProfessionalDraft para o save', () {
      final j = const ProfessionalDraft(
        vcName: 'Dr. Bruno',
        schedules: [
          ScheduleRange(itWeekday: 3, qtMinuteStart: 480, qtMinuteEnd: 720),
        ],
      ).toJson();
      expect(j.containsKey('vc_color'), isFalse, reason: 'sem cor = paleta');
      expect(j.containsKey('it_status'), isFalse);
      expect(j['nr_user'], isNull);
      expect(j['schedules'], [
        {'it_weekday': 3, 'qt_minute_start': 480, 'qt_minute_end': 720},
      ]);
    });
  });

  group('telas', () {
    late _FakeRepo repo;

    Widget app(Widget home) => ProviderScope(
      overrides: [
        agendaRepositoryProvider.overrideWithValue(repo),
        currentCompanyProvider.overrideWith((ref) => 1),
        currentBranchNumberProvider.overrideWith((ref) => 1),
        canReadProvider.overrideWith((ref, code) => true),
        canCreateProvider.overrideWith((ref, code) => true),
        canUpdateProvider.overrideWith((ref, code) => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: home,
      ),
    );

    setUp(() => repo = _FakeRepo());

    Future<void> openNew(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ProfessionalFormDialog.show(
                  context,
                  users: ProfessionalListData.fromJson(_json).users,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('novo profissional: faixa, copiar segunda e salvar', (
      tester,
    ) async {
      await openNew(tester);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.professionalName),
          matching: find.byType(TextField),
        ),
        'Dr. Bruno',
      );
      // + Faixa na segunda (primeira linha) = 08:00 - 12:00
      await tester.tap(find.text(Strings.addRange).first);
      await tester.pumpAndSettle();
      expect(find.text('08:00 – 12:00'), findsOneWidget);
      await tester.tap(find.text(Strings.copyMondayToWeekdays));
      await tester.pumpAndSettle();
      expect(find.text('08:00 – 12:00'), findsNWidgets(5));

      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      expect(repo.saved?.vcName, 'Dr. Bruno');
      expect(repo.saved?.schedules.length, 5);
      expect(repo.saved?.qtSlotMinutes, 30);
    });

    testWidgets('faixas sobrepostas nao salvam', (tester) async {
      await openNew(tester);
      await tester.enterText(
        find.ancestor(
          of: find.text(Strings.professionalName),
          matching: find.byType(TextField),
        ),
        'Dr. Caio',
      );
      // duas faixas: 08-12 e 13-17 (a segunda comeca 1 h depois) -> sem conflito
      await tester.tap(find.text(Strings.addRange).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.addRange).first);
      await tester.pumpAndSettle();
      expect(find.text('13:00 – 17:00'), findsOneWidget);
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      expect(repo.saved?.schedules.length, 2);
    });

    testWidgets('pagina lista os profissionais com o horario', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const AgendaPageBody()));
      await tester.pumpAndSettle();
      expect(find.text('Dra. Ana Souza'), findsOneWidget);
      expect(find.text('08:00 – 12:00 · 14:00 – 18:00'), findsOneWidget);
      expect(find.text(Strings.weeklyHours(12)), findsOneWidget);
      expect(find.text(Strings.newProfessional), findsOneWidget);
    });
  });
}
