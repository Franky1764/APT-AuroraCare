// lib/presentation/onboarding/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/user_session_repository_impl.provider.dart';
import '../../domain/entities/session_info.dart';
import '../../core/router/navigation_session.dart';
import '../shared/current_mode_provider.dart';
import 'splash_screen.dart';

export '../../core/router/navigation_policy.dart';

/// Lee la sesión al arrancar. El router conserva después el estado de acceso
/// en memoria y lo actualiza en login, onboarding y cierre de sesión.
final startupSessionProvider = FutureProvider<SessionInfo?>((ref) async {
  final repository = ref.read(userSessionRepositoryProvider);
  final stopwatch = Stopwatch()..start();
  final session = await repository.readSession();

  // Mínimo ~800 ms para evitar parpadeo del splash.
  const minimumSplash = Duration(milliseconds: 800);
  final remaining = minimumSplash - stopwatch.elapsed;
  if (remaining > Duration.zero) {
    await Future.delayed(remaining);
  }
  return session;
});

/// Restaura la sesión antes de que GoRouter habilite rutas privadas.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Se inicia fuera de build para no modificar providers durante el render.
    Future.microtask(() async {
      SessionInfo? session;
      try {
        session = await ref.read(startupSessionProvider.future);
      } catch (_) {
        session = null;
      }
      if (!mounted) return;
      ref.read(currentModeProvider.notifier).state = session?.currentMode == 3
          ? 3
          : 2;
      ref.read(navigationSessionProvider.notifier).restore(session);
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
