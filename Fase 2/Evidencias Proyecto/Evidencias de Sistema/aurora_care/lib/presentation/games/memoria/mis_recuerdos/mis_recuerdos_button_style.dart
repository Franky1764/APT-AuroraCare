// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_button_style.dart
import 'package:flutter/material.dart';

/// Padding cómodo para los botones grandes de "Mis recuerdos". El tema
/// global (app_theme.dart) solo define padding vertical para
/// ElevatedButton/OutlinedButton, así que en botones angostos (ej. mitad
/// del ancho) o con texto largo ("Completar mis recuerdos") el texto
/// queda pegado al borde. No se toca el tema global (afectaría toda la
/// app) — este padding se aplica solo a los botones de este feature.
const EdgeInsets misRecuerdosBotonPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 14,
);
