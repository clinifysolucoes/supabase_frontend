import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/shared/widgets/menu_icons.dart';

void main() {
  testWidgets('Icones desenhados: contorno e cheio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final g in MenuGlyph.values)
                for (final filled in [false, true])
                  MenuGlyphIcon(
                    g,
                    filled: filled,
                    size: 22,
                    color: Colors.teal,
                  ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(MenuGlyphIcon), findsNWidgets(4));
    expect(
      tester.getSize(find.byType(MenuGlyphIcon).first),
      const Size(22, 22),
    );
  });
}
