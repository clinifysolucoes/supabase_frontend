import 'package:flutter/material.dart';

/// Icones desenhados para o menu (o Material nao tem pilha de moedas com
/// cifrao nem dente). Mesma grade 24x24 dos icones do Material: contorno
/// quando o item nao esta selecionado, cheio quando esta.
enum MenuGlyph { coins, toothDocument }

class MenuGlyphIcon extends StatelessWidget {
  const MenuGlyphIcon(
    this.glyph, {
    super.key,
    this.filled = false,
    this.size = 24,
    this.color,
  });

  final MenuGlyph glyph;
  final bool filled;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: switch (glyph) {
          MenuGlyph.coins => _CoinsPainter(c, filled),
          MenuGlyph.toothDocument => _ToothDocPainter(c, filled),
        },
      ),
    );
  }
}

abstract class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  Paint get stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint get fill => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  /// Recorte transparente (mostra o fundo do menu, inclusive o selecionado).
  static Paint get cut => Paint()..blendMode = BlendMode.clear;

  /// Desenha na grade 24x24 e escala para o tamanho pedido.
  void paint24(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.scale(size.width / 24, size.height / 24);
    paint24(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.color != color || old.filled != filled;
}

/// Pilha de moedas (atras) e uma moeda com cifrao na frente.
class _CoinsPainter extends _GlyphPainter {
  _CoinsPainter(super.color, super.filled);

  void _disc(Canvas canvas, double top) {
    // moeda vista de lado: elipse de cima + borda
    final rect = Rect.fromLTWH(2, top, 12, 4.4);
    final body = Path()
      ..moveTo(2, top + 2.2)
      ..lineTo(2, top + 4.2)
      ..arcTo(Rect.fromLTWH(2, top + 2, 12, 4.4), 3.1416, -3.1416, false)
      ..lineTo(14, top + 2.2);
    if (filled) {
      canvas.drawPath(body, fill);
      canvas.drawOval(rect, fill);
      canvas.drawOval(
        rect.deflate(0.9),
        _GlyphPainter.cut
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    } else {
      canvas.drawPath(body, stroke);
      canvas.drawOval(rect, stroke);
    }
  }

  @override
  void paint24(Canvas canvas) {
    _disc(canvas, 15.6);
    _disc(canvas, 11.6);
    _disc(canvas, 7.6);

    // moeda da frente
    const center = Offset(16.2, 13.4);
    const r = 6.3;
    if (filled) {
      // anel claro separa a moeda da pilha
      canvas.drawCircle(center, r + 1.1, _GlyphPainter.cut);
      canvas.drawCircle(center, r, fill);
    } else {
      canvas.drawCircle(center, r + 1.1, _GlyphPainter.cut);
      canvas.drawCircle(center, r, stroke);
    }
    final dollar = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          height: 1,
          foreground: filled ? _GlyphPainter.cut : (Paint()..color = color),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dollar.paint(canvas, center - Offset(dollar.width / 2, dollar.height / 2));
  }
}

/// Folha com a dobra no canto e um dente (molar) no meio.
class _ToothDocPainter extends _GlyphPainter {
  _ToothDocPainter(super.color, super.filled);

  static Path _paper() => Path()
    ..moveTo(6, 2)
    ..lineTo(14.5, 2)
    ..lineTo(20, 7.5)
    ..lineTo(20, 20)
    ..arcToPoint(const Offset(18, 22), radius: const Radius.circular(2))
    ..lineTo(6, 22)
    ..arcToPoint(const Offset(4, 20), radius: const Radius.circular(2))
    ..lineTo(4, 4)
    ..arcToPoint(const Offset(6, 2), radius: const Radius.circular(2))
    ..close();

  static Path _fold() => Path()
    ..moveTo(14.5, 2)
    ..lineTo(14.5, 6)
    ..arcToPoint(
      const Offset(16, 7.5),
      radius: const Radius.circular(1.5),
      clockwise: false,
    )
    ..lineTo(20, 7.5);

  /// Molar: coroa com duas cuspides e duas raizes.
  static Path _tooth() => Path()
    ..moveTo(8.2, 11)
    ..cubicTo(8.2, 9, 10.2, 8.4, 12, 9.3)
    ..cubicTo(13.8, 8.4, 15.8, 9, 15.8, 11)
    ..cubicTo(15.8, 12.8, 15.1, 13.6, 14.9, 15.4)
    ..cubicTo(14.7, 17.3, 14.2, 18.6, 13.4, 18.6)
    ..cubicTo(12.7, 18.6, 12.6, 16.4, 12, 16.4)
    ..cubicTo(11.4, 16.4, 11.3, 18.6, 10.6, 18.6)
    ..cubicTo(9.8, 18.6, 9.3, 17.3, 9.1, 15.4)
    ..cubicTo(8.9, 13.6, 8.2, 12.8, 8.2, 11)
    ..close();

  @override
  void paint24(Canvas canvas) {
    if (filled) {
      canvas.drawPath(_paper(), fill);
      canvas.drawPath(
        _fold(),
        _GlyphPainter.cut
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawPath(_tooth(), _GlyphPainter.cut);
    } else {
      canvas.drawPath(_paper(), stroke);
      canvas.drawPath(_fold(), stroke);
      canvas.drawPath(_tooth(), stroke..strokeWidth = 1.5);
    }
  }
}
