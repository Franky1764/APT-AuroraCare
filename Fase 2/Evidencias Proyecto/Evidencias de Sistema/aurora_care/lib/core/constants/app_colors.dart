// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

/// Los 16 colores con nombre que usa toda la app (ver AppColors). Una
/// paleta es un conjunto completo de estos 16 valores — "Aurora" es la
/// paleta de hoy; otras paletas (Paso 3, lib/core/constants/
/// app_palettes.dart) son instancias distintas de esta misma clase.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.success,
    required this.successBackground,
    required this.warning,
    required this.warningBackground,
    required this.error,
    required this.errorBackground,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color success;
  final Color successBackground;
  final Color warning;
  final Color warningBackground;
  final Color error;
  final Color errorBackground;

  /// La paleta de hoy, con los valores EXACTOS de antes de esta tarea.
  /// textPrimary y warning quedan iguales a primaryDark y accent, como ya
  /// estaban (no es un alias nuevo, es el mismo valor que ya tenían).
  static const aurora = AppPalette(
    primary: Color(0xFF5B4BB5),
    primaryDark: Color(0xFF3B2F72),
    primaryLight: Color(0xFFEDEAFA),
    accent: Color(0xFFE8B33C),
    background: Color(0xFFFBFAFE),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE4E1F0),
    textPrimary: Color(0xFF3B2F72),
    textSecondary: Color(0xFF6E6B85),
    textOnPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF2E9E5B),
    successBackground: Color(0xFFE7F7EC),
    warning: Color(0xFFE8B33C),
    warningBackground: Color(0xFFFFF6DF),
    error: Color(0xFFD64545),
    errorBackground: Color(0xFFFDEAEA),
  );
}

/// Paleta de colores de AuroraCare. Responsable: Daniela Castillo — no
/// modificar sin revisión.
///
/// Cada color es un getter sobre la paleta ACTIVA (ver [usarPaleta]), no
/// una constante fija: así toda la app puede cambiar de tema sin que
/// cambie la sintaxis `AppColors.x` en ningún otro archivo. Por defecto
/// la paleta activa es [AppPalette.aurora] — si nadie llama a
/// [usarPaleta], el comportamiento es idéntico al de antes de esta
/// clase existir.
class AppColors {
  AppColors._();

  static AppPalette _activa = AppPalette.aurora;

  /// Cambia la paleta activa para toda la app. Por sí solo NO reconstruye
  /// ningún widget ya en pantalla — quien llama a esto es responsable de
  /// disparar la reconstrucción (ver Paso 4: themeProvider y main.dart).
  static void usarPaleta(AppPalette paleta) {
    _activa = paleta;
  }

  /// La paleta activa en este momento, por si algún lugar necesita leer
  /// más de un color a la vez (ej. construir un ThemeData completo).
  static AppPalette get paletaActiva => _activa;

  // Primario — morado de marca
  static Color get primary => _activa.primary;
  static Color get primaryDark => _activa.primaryDark;
  static Color get primaryLight => _activa.primaryLight;

  // Acento — dorado (usado en logros/trofeos)
  static Color get accent => _activa.accent;

  // Fondo y superficies
  static Color get background => _activa.background;
  static Color get surface => _activa.surface;
  static Color get border => _activa.border;

  // Texto
  static Color get textPrimary => _activa.textPrimary;
  static Color get textSecondary => _activa.textSecondary;
  static Color get textOnPrimary => _activa.textOnPrimary;

  // Estados semánticos (tags de progreso, evaluaciones)
  static Color get success => _activa.success;
  static Color get successBackground => _activa.successBackground;

  static Color get warning => _activa.warning;
  static Color get warningBackground => _activa.warningBackground;

  static Color get error => _activa.error;
  static Color get errorBackground => _activa.errorBackground;
}
