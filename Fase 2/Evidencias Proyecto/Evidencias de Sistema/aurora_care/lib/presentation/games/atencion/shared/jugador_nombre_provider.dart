// lib/presentation/games/atencion/shared/jugador_nombre_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase_providers.dart';

/// Nombre de la persona para los mensajes de ánimo de los juegos de
/// Atención ("¡Muy bien, Rosa!"). Misma regla que resolveUserName() de
/// auth_gate.dart: nombre visible y, si no hay, la parte del correo antes
/// de la @. Devuelve null si no hay sesión: el juego dice solo "¡Muy bien!".
///
/// El nombre solo se muestra en pantalla: no se guarda en la sesión ni se
/// envía a ningún servidor (ARCHITECTURE.md §6).
final jugadorNombreProvider = Provider<String?>((ref) {
  try {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return null;
    final nombre = user.displayName?.trim();
    if (nombre != null && nombre.isNotEmpty) return nombre.split(' ').first;
    final prefijo = (user.email ?? '').split('@').first.trim();
    return prefijo.isEmpty ? null : prefijo;
  } catch (_) {
    // Firebase no inicializado (por ejemplo, en pruebas).
    return null;
  }
});
