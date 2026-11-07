import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tracos da assinatura (pontos em coordenadas do quadro; null separa tracos).
class SignaturePadController extends ChangeNotifier {
  final List<Offset?> _points = [];

  List<Offset?> get points => List.unmodifiable(_points);
  bool get isEmpty => !_points.any((p) => p != null);

  void add(Offset p) {
    _points.add(p);
    notifyListeners();
  }

  void end() {
    if (_points.isNotEmpty && _points.last != null) _points.add(null);
  }

  void clear() {
    _points.clear();
    notifyListeners();
  }

  /// PNG transparente com o traco, no tamanho [size] x [pixelRatio].
  Future<Uint8List> toPng(Size size, {double pixelRatio = 2}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    _SignaturePainter(_points).paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// Quadro onde o paciente assina com o dedo, caneta ou mouse.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 200});

  final SignaturePadController controller;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line, width: 1.5),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            right: 24,
            bottom: height * 0.25,
            child: Container(height: 1, color: AppColors.line),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => controller.add(d.localPosition),
            onPanUpdate: (d) => controller.add(d.localPosition),
            onPanEnd: (_) => controller.end(),
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => CustomPaint(
                painter: _SignaturePainter(controller.points),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F2A33)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      if (a == null) continue;
      final b = i + 1 < points.length ? points[i + 1] : null;
      if (b == null) {
        canvas.drawPoints(ui.PointMode.points, [a], paint);
      } else {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
