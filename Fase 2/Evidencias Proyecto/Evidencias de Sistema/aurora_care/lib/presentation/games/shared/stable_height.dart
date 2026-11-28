import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reserva el alto del texto más largo entre varias opciones, para que lo que
/// está debajo no se mueva cuando el texto cambia de cantidad de líneas.
///
/// Mide con el mismo estilo efectivo que usa el Text real (el del tema más
/// [style]), el mismo tamaño de letra del usuario y el ancho disponible.
class StableHeight extends StatefulWidget {
  const StableHeight({
    super.key,
    required this.candidates,
    required this.style,
    required this.child,
    this.reservedWidth = 0,
    this.minHeight = 0,
  });

  /// Todos los textos que pueden aparecer en este lugar.
  final List<String> candidates;
  final TextStyle style;

  /// Ancho que ocupa lo que acompaña al texto (ícono, separación).
  final double reservedWidth;
  final double minHeight;
  final Widget child;

  @override
  State<StableHeight> createState() => _StableHeightState();
}

class _StableHeightState extends State<StableHeight> {
  String? _cacheKey;
  double _cacheHeight = 0;

  double _tallest(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final key =
        '$maxWidth|${scaler.scale(18)}|${style.height}|${style.fontSize}';
    if (key == _cacheKey) return _cacheHeight;
    var tallest = widget.minHeight;
    for (final text in widget.candidates) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(0, maxWidth - widget.reservedWidth));
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    _cacheKey = key;
    return _cacheHeight = tallest;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: _tallest(context, box.maxWidth)),
        child: widget.child,
      ),
    );
  }
}
