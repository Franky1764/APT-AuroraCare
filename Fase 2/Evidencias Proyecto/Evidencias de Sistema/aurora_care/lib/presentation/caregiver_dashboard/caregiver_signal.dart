// lib/presentation/caregiver_dashboard/caregiver_signal.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum _SignalKind { mejora, estable, atencion, revisar, inicial, pendiente }

/// Indicador visual de la tendencia publicada para el vínculo activo.
class CaregiverSignal {
  const CaregiverSignal._({
    required this.label,
    required this.message,
    required this.icon,
    required this._kind,
  });

  static const mejora = CaregiverSignal._(
    label: 'Mejora',
    message:
        'Sus sesiones muestran una tendencia de mejora en los últimos 28 días.',
    icon: Icons.trending_up,
    kind: _SignalKind.mejora,
  );
  static const estable = CaregiverSignal._(
    label: 'Estable',
    message: 'Sus sesiones muestran un rendimiento consistente en los últimos 28 días.',
    icon: Icons.check_circle_outline,
    kind: _SignalKind.estable,
  );
  static const atencion = CaregiverSignal._(
    label: 'Resultados más bajos',
    message:
        'Las partidas comparables recientes tuvieron resultados algo menores.',
    icon: Icons.visibility_outlined,
    kind: _SignalKind.atencion,
  );
  static const revisar = CaregiverSignal._(
    label: 'Resultados más bajos',
    message: 'Las partidas comparables recientes tuvieron resultados menores.',
    icon: Icons.info_outline,
    kind: _SignalKind.revisar,
  );
  static const inicial = CaregiverSignal._(
    label: 'Seguimiento inicial',
    message: 'Aún faltan partidas comparables para mostrar una tendencia.',
    icon: Icons.hourglass_empty,
    kind: _SignalKind.inicial,
  );
  static const pendiente = CaregiverSignal._(
    label: 'Resumen pendiente de actualización',
    message: 'La tendencia necesita una actualización.',
    icon: Icons.update,
    kind: _SignalKind.pendiente,
  );

  final String label;
  final String message;
  final IconData icon;
  final _SignalKind _kind;

  Color get color {
    switch (_kind) {
      case _SignalKind.mejora:
        return const Color(0xFF2F6FB3);
      case _SignalKind.estable:
        return AppColors.success;
      case _SignalKind.atencion:
      case _SignalKind.revisar:
        // Ámbar oscuro: el amarillo de marca no alcanza contraste 4,5:1 como texto.
        return const Color(0xFF8A6100);
      case _SignalKind.inicial:
      case _SignalKind.pendiente:
        return AppColors.textSecondary;
    }
  }

  Color get background {
    switch (_kind) {
      case _SignalKind.mejora:
        return const Color(0xFFE6F0FA);
      case _SignalKind.estable:
        return AppColors.successBackground;
      case _SignalKind.atencion:
      case _SignalKind.revisar:
        return AppColors.warningBackground;
      case _SignalKind.inicial:
      case _SignalKind.pendiente:
        return const Color(0xFFF0EFF4);
    }
  }

  static CaregiverSignal fromSummary(Object? trend, {required bool fresh}) {
    if (!fresh) return CaregiverSignal.pendiente;
    return switch (trend) {
      'improving' => CaregiverSignal.mejora,
      'stable' => CaregiverSignal.estable,
      'attention' => CaregiverSignal.atencion,
      'review' => CaregiverSignal.revisar,
      _ => CaregiverSignal.inicial,
    };
  }
}
