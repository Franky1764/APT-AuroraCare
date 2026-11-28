import 'dart:async';

import 'package:aurora_care/core/constants/app_colors.dart';

/// Antes de cada prueba, vuelve a la paleta Aurora. La paleta activa de
/// AppColors es estado global (static) — sin este reset, una prueba que
/// cambie de tema podría dejar otra paleta activa y afectar pruebas
/// siguientes que no tienen nada que ver con temas.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppColors.usarPaleta(AppPalette.aurora);
  await testMain();
}
