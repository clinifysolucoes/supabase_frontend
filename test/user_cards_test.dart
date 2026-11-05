import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/theme/app_theme.dart';
import 'package:odonto_app/features/users/domain/company_user.dart';
import 'package:odonto_app/features/users/presentation/user_card_grid.dart';
import 'package:odonto_app/l10n/strings.dart';

CompanyUser _user({int status = 1}) => CompanyUser.fromJson({
  'nr_user': 7,
  'nr_company_user': 3,
  'vc_name': 'Regiane Zen',
  'vc_email': 'regiane@clinica.test',
  'vc_mobile': '41991296244',
  'it_status': status,
  'id_admin': false,
  'dh_last_login': '2026-11-05T15:45:00Z',
  'branches': [
    {
      'nr_branch': 1,
      'vc_branch': 'Matriz',
      'nr_profile': 2,
      'vc_profile': 'Profissional',
      'it_level': 10,
    },
    {
      'nr_branch': 2,
      'vc_branch': 'Centro',
      'nr_profile': 2,
      'vc_profile': 'Profissional',
      'it_level': 10,
    },
  ],
});

void main() {
  Future<List<UserCardAction>> pump(
    WidgetTester tester, {
    required CompanyUser user,
    bool canUpdate = true,
  }) async {
    final actions = <UserCardAction>[];
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: Scaffold(
          body: UserCardGrid(
            users: [user],
            canUpdate: canUpdate,
            onAction: (_, a) => actions.add(a),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return actions;
  }

  testWidgets('card: nome, perfis sem repetir, contato e ultimo acesso', (
    tester,
  ) async {
    await pump(tester, user: _user());
    expect(find.text('Regiane Zen'), findsOneWidget);
    expect(
      find.text('Profissional'),
      findsOneWidget,
      reason: 'perfil uma vez so',
    );
    expect(find.text('regiane@clinica.test'), findsOneWidget);
    expect(find.textContaining(Strings.lastLogin), findsOneWidget);
  });

  testWidgets('menu: redefinir senha, inativar e remover', (tester) async {
    final actions = await pump(tester, user: _user());
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text(Strings.resetPassword), findsOneWidget);
    expect(find.text(Strings.inactivateUser), findsOneWidget);
    expect(find.text(Strings.unlinkUser), findsOneWidget);
    await tester.tap(find.text(Strings.resetPassword));
    await tester.pumpAndSettle();
    expect(actions, [UserCardAction.password]);
  });

  testWidgets('inativo mostra Ativar; sem permissao nao tem menu', (
    tester,
  ) async {
    await pump(tester, user: _user(status: 90));
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text(Strings.activateUser), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await pump(tester, user: _user(), canUpdate: false);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });
}
