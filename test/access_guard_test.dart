import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/profiles/application/profiles_controller.dart';
import 'package:odonto_app/features/session/presentation/access_guard.dart';
import 'package:odonto_app/l10n/strings.dart';

Widget _app(Map<String, dynamic> response, void Function(AccessGrant?) done) =>
    ProviderScope(
      overrides: [
        currentCompanyProvider.overrideWith((ref) => 1),
        currentBranchNumberProvider.overrideWith((ref) => 1),
        accessRequestProvider.overrideWithValue((_) async => response),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async => done(
                await ensureAccess(
                  context,
                  ref,
                  kind: AccessKind.print,
                  target: 'Orçamento 1',
                ),
              ),
              child: const Text('imprimir'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Sem exigencia: segue direto', (tester) async {
    AccessGrant? grant;
    var called = false;
    await tester.pumpWidget(
      _app({'id_required': false}, (g) {
        called = true;
        grant = g;
      }),
    );
    await tester.tap(find.text('imprimir'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(grant, isNotNull);
    expect(grant!.uuRequest, isNull);
    expect(find.text(Strings.accessAuthPrintTitle), findsNothing);
  });

  testWidgets('Com exigencia: pede o administrador e cancelar nao segue', (
    tester,
  ) async {
    AccessGrant? grant = (uuRequest: 'x');
    await tester.pumpWidget(
      _app({'id_required': true, 'uu_request': 'abc'}, (g) => grant = g),
    );
    await tester.tap(find.text('imprimir'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.accessAuthPrintTitle), findsOneWidget);
    expect(find.text(Strings.accessAuthEmail), findsOneWidget);
    await tester.tap(find.text(Strings.accessAuthConfirm));
    await tester.pump();
    expect(find.text(Strings.accessAuthFill), findsOneWidget);
    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();
    expect(grant, isNull);
  });
}
