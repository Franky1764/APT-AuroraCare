// lib/core/constants/app_palettes.dart

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Un tema seleccionable desde el perfil: un id estable (para guardarlo en
/// preferencias), un nombre visible en español, una frase corta que lo
/// describe (para la pantalla de selección), y la paleta de colores que
/// activa.
class AppThemeOption {
  const AppThemeOption(this.id, this.nombre, this.descripcion, this.paleta);

  final String id;
  final String nombre;
  final String descripcion;
  final AppPalette paleta;
}

/// Todos los temas de color disponibles en AuroraCare. Todas las paletas
/// (salvo Aurora, que ya existía antes de esta tarea) cumplen la prueba de
/// contraste de test/core/constants/app_colors_contrast_test.dart SIN
/// excepciones: texto 4,5:1, elementos no textuales 3:1.
class AppPalettes {
  AppPalettes._();

  static const aurora = AppThemeOption(
    'aurora',
    'Aurora',
    'Morado, el de siempre',
    AppPalette.aurora,
  );

  static const oceano = AppThemeOption(
    'oceano',
    'Océano',
    'Azules y turquesa, tranquilo',
    AppPalette(
      primary: Color(0xFF0E6FA8),
      primaryDark: Color(0xFF0B4A6F),
      primaryLight: Color(0xFFE0F0F8),
      accent: Color(0xFF00796B),
      background: Color(0xFFF5FAFC),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFCFE6EF),
      textPrimary: Color(0xFF0B4A6F),
      textSecondary: Color(0xFF4F6E80),
      textOnPrimary: Color(0xFFFFFFFF),
      success: Color(0xFF1E7F4F),
      successBackground: Color(0xFFE2F3E8),
      warning: Color(0xFF9A5B00),
      warningBackground: Color(0xFFFBEEDD),
      error: Color(0xFFC22B2B),
      errorBackground: Color(0xFFFBE4E4),
    ),
  );

  static const atardecer = AppThemeOption(
    'atardecer',
    'Atardecer',
    'Naranjas cálidos, muy llamativo',
    AppPalette(
      primary: Color(0xFFC13D14),
      primaryDark: Color(0xFF8A2E12),
      primaryLight: Color(0xFFFBE7DD),
      accent: Color(0xFFB0287A),
      background: Color(0xFFFFF8F4),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFF3DACB),
      textPrimary: Color(0xFF8A2E12),
      textSecondary: Color(0xFF7A5042),
      textOnPrimary: Color(0xFFFFFFFF),
      success: Color(0xFF1E7F4F),
      successBackground: Color(0xFFE2F3E8),
      warning: Color(0xFF9A5B00),
      warningBackground: Color(0xFFFDEFDC),
      error: Color(0xFFC22B2B),
      errorBackground: Color(0xFFFBE4E4),
    ),
  );

  static const bosque = AppThemeOption(
    'bosque',
    'Bosque',
    'Verdes suaves',
    AppPalette(
      primary: Color(0xFF2E7D4F),
      primaryDark: Color(0xFF1D4E32),
      primaryLight: Color(0xFFE3F0E7),
      accent: Color(0xFF7A6A1E),
      background: Color(0xFFF6FAF6),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFD6E8DA),
      textPrimary: Color(0xFF1D4E32),
      textSecondary: Color(0xFF51685A),
      textOnPrimary: Color(0xFFFFFFFF),
      success: Color(0xFF1E7F4F),
      successBackground: Color(0xFFE2F3E8),
      warning: Color(0xFF9A5B00),
      warningBackground: Color(0xFFFBEEDD),
      error: Color(0xFFC22B2B),
      errorBackground: Color(0xFFFBE4E4),
    ),
  );

  /// Basada en la paleta Okabe-Ito (azul, naranja, celeste, amarillo), que
  /// evita a propósito el par rojo-verde. success/warning/error se eligieron
  /// para quedar separados por tono Y por luminosidad: una simulación de
  /// protanopia/deuteranopia (ver app_palettes_cvd_test.dart) confirma que
  /// las 3 siguen siendo claramente distintas entre sí. Siempre van además
  /// acompañadas de ícono y texto, nunca solo del color.
  static const daltonismo = AppThemeOption(
    'daltonismo',
    'Accesible para daltonismo',
    'Pensado para quienes distinguen mal algunos colores',
    AppPalette(
      primary: Color(0xFF0072B2),
      primaryDark: Color(0xFF00486F),
      primaryLight: Color(0xFFE0EEF7),
      accent: Color(0xFFB37400),
      background: Color(0xFFF7FAFC),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFFD2E3ED),
      textPrimary: Color(0xFF00486F),
      textSecondary: Color(0xFF49616F),
      textOnPrimary: Color(0xFFFFFFFF),
      success: Color(0xFF00805E),
      successBackground: Color(0xFFDEF3EC),
      warning: Color(0xFF9C5B00),
      warningBackground: Color(0xFFFCEFD9),
      error: Color(0xFF6400B4),
      errorBackground: Color(0xFFF2E6F8),
    ),
  );

  static const altoContraste = AppThemeOption(
    'alto_contraste',
    'Alto contraste',
    'Máxima claridad',
    AppPalette(
      primary: Color(0xFF1A1A1A),
      primaryDark: Color(0xFF000000),
      primaryLight: Color(0xFFE8E8E8),
      accent: Color(0xFF004C9E),
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      border: Color(0xFF4D4D4D),
      textPrimary: Color(0xFF000000),
      textSecondary: Color(0xFF2B2B2B),
      textOnPrimary: Color(0xFFFFFFFF),
      success: Color(0xFF0B6B2E),
      successBackground: Color(0xFFE3F3E6),
      warning: Color(0xFF7A4B00),
      warningBackground: Color(0xFFFBEEDC),
      error: Color(0xFFA3121F),
      errorBackground: Color(0xFFFBE2E4),
    ),
  );

  /// Todos los temas, en el orden en que se muestran en el perfil. Aurora
  /// siempre primero (es el valor por defecto).
  static const todas = [aurora, oceano, atardecer, bosque, daltonismo, altoContraste];

  /// Busca un tema por su id guardado. Devuelve null si no existe (por
  /// ejemplo, un id guardado de una versión anterior que ya no existe).
  static AppThemeOption? porId(String id) {
    for (final tema in todas) {
      if (tema.id == id) return tema;
    }
    return null;
  }
}
