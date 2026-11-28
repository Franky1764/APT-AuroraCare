import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Escena de práctica: una ilustración local con un detalle pequeño que se
/// aprecia mejor al ampliar. Los detalles quedan cerca del centro, porque el
/// zoom se aplica hacia el centro de la imagen.
class ZoomScene {
  const ZoomScene({
    required this.label,
    required this.of,
    required this.detail,
    required this.painter,
  });

  /// "la flor", "el árbol": para "Amplíe la flor para ver sus detalles".
  final String label;

  /// "de la flor", "del árbol": para "Imagen de la flor".
  final String of;

  /// Lo que se puede ver al ampliar: "la abejita".
  final String detail;
  final CustomPainter painter;
}

const zoomScenes = [
  ZoomScene(
    label: 'la flor',
    of: 'de la flor',
    detail: 'la abejita',
    painter: _FlowerPainter(),
  ),
  ZoomScene(
    label: 'el árbol',
    of: 'del árbol',
    detail: 'el pajarito',
    painter: _TreePainter(),
  ),
  ZoomScene(
    label: 'la casa',
    of: 'de la casa',
    detail: 'el gatito en la ventana',
    painter: _HousePainter(),
  ),
];

Paint _fill(Color color) => Paint()..color = color;

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _fill(AppColors.primaryLight));
    final center = Offset(size.width / 2, size.height * .42);
    final radius = size.shortestSide * .1;
    canvas.drawLine(
      center,
      Offset(center.dx, size.height),
      Paint()
        ..color = AppColors.primaryDark
        ..strokeWidth = 7,
    );
    final leaf = Path()
      ..moveTo(center.dx, size.height * .8)
      ..quadraticBezierTo(
        size.width * .2,
        size.height * .8,
        size.width * .23,
        size.height * .65,
      )
      ..quadraticBezierTo(
        size.width * .4,
        size.height * .6,
        center.dx,
        size.height * .8,
      );
    canvas.drawPath(leaf, _fill(AppColors.primary));
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.15,
        radius * .8,
        _fill(AppColors.primary),
      );
    }
    canvas.drawCircle(center, radius * .85, _fill(AppColors.accent));
    for (final point in [
      const Offset(-.3, -.2),
      const Offset(.25, -.2),
      const Offset(0, .25),
    ]) {
      canvas.drawCircle(
        center + point * radius,
        radius * .09,
        _fill(AppColors.primaryDark),
      );
    }
    // Detalle: una abejita posada sobre un pétalo.
    final bee = center + Offset(radius * 1.55, -radius * 1.25);
    final b = radius * .34;
    canvas.drawCircle(
      bee + Offset(-b * .5, -b * .9),
      b * .6,
      _fill(AppColors.surface),
    );
    canvas.drawOval(
      Rect.fromCenter(center: bee, width: b * 2.2, height: b * 1.4),
      _fill(AppColors.accent),
    );
    for (final dx in [-.35, .15]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: bee + Offset(b * dx, 0),
          width: b * .22,
          height: b * 1.3,
        ),
        _fill(AppColors.primaryDark),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TreePainter extends CustomPainter {
  const _TreePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, _fill(AppColors.primaryLight));
    canvas.drawRect(
      Rect.fromLTWH(0, h * .82, w, h * .18),
      _fill(AppColors.primary.withValues(alpha: .35)),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h * .66),
        width: w * .08,
        height: h * .36,
      ),
      _fill(AppColors.primaryDark),
    );
    final canopy = Offset(w / 2, h * .4);
    for (final o in [
      const Offset(0, 0),
      const Offset(-.13, .05),
      const Offset(.13, .05),
      const Offset(-.07, -.08),
      const Offset(.07, -.08),
    ]) {
      canvas.drawCircle(
        canopy + Offset(o.dx * w, o.dy * h),
        w * .12,
        _fill(AppColors.primary),
      );
    }
    // Detalle: un pajarito posado en el follaje, con su pico y su ojo.
    final bird = Offset(w * .56, h * .37);
    final s = w * .03;
    canvas.drawOval(
      Rect.fromCenter(center: bird, width: s * 2.4, height: s * 1.7),
      _fill(AppColors.accent),
    );
    canvas.drawCircle(
      bird + Offset(s * 1.0, -s * .7),
      s * .7,
      _fill(AppColors.accent),
    );
    final beak = Path()
      ..moveTo(bird.dx + s * 1.6, bird.dy - s * .8)
      ..lineTo(bird.dx + s * 2.2, bird.dy - s * .6)
      ..lineTo(bird.dx + s * 1.6, bird.dy - s * .4)
      ..close();
    canvas.drawPath(beak, _fill(AppColors.primaryDark));
    canvas.drawCircle(
      bird + Offset(s * 1.2, -s * .8),
      s * .12,
      _fill(AppColors.primaryDark),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HousePainter extends CustomPainter {
  const _HousePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, _fill(AppColors.primaryLight));
    canvas.drawRect(
      Rect.fromLTWH(0, h * .8, w, h * .2),
      _fill(AppColors.primary.withValues(alpha: .35)),
    );
    final body = Rect.fromCenter(
      center: Offset(w / 2, h * .6),
      width: w * .5,
      height: h * .36,
    );
    canvas.drawRect(body, _fill(AppColors.surface));
    canvas.drawRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primaryDark,
    );
    final roof = Path()
      ..moveTo(body.left - w * .04, body.top)
      ..lineTo(w / 2, h * .28)
      ..lineTo(body.right + w * .04, body.top)
      ..close();
    canvas.drawPath(roof, _fill(AppColors.primaryDark));
    canvas.drawRect(
      Rect.fromLTWH(body.left + w * .06, body.bottom - h * .17, w * .1, h * .17),
      _fill(AppColors.primary),
    );
    // Detalle: un gatito asomado a la ventana.
    final window = Rect.fromCenter(
      center: Offset(w * .56, h * .58),
      width: w * .14,
      height: h * .12,
    );
    canvas.drawRect(window, _fill(AppColors.accent));
    final cat = Offset(window.center.dx, window.center.dy + h * .012);
    final c = w * .028;
    canvas.drawCircle(cat, c, _fill(AppColors.primaryDark));
    for (final side in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(cat.dx + side * c * .95, cat.dy - c * .3)
        ..lineTo(cat.dx + side * c * .5, cat.dy - c * 1.5)
        ..lineTo(cat.dx + side * c * .05, cat.dy - c * .8)
        ..close();
      canvas.drawPath(ear, _fill(AppColors.primaryDark));
    }
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        cat + Offset(side * c * .4, -c * .1),
        c * .14,
        _fill(AppColors.accent),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(window.left, window.center.dy - 1, window.width, 2),
      _fill(AppColors.primaryDark),
    );
    canvas.drawRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryDark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
