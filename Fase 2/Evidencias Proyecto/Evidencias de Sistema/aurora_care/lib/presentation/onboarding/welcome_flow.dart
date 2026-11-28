import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/router/navigation_policy.dart';
import '../../core/router/navigation_session.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import '../../data/repositories/user_session_repository_impl.provider.dart';
import '../../domain/entities/session_info.dart';
import '../../domain/usecases/get_or_create_cognitive_profile.dart';
import '../../domain/usecases/get_or_create_cognitive_profile.provider.dart';
import '../shared/current_mode_provider.dart';
import 'medical_disclaimer_screen.dart';
import 'mode_selection_screen.dart';
import 'welcome_screen.dart';

/// Las pantallas reciben callbacks de negocio; GoRouter centraliza sus destinos.
Widget buildWelcomeFlow() => const WelcomeScreen();

Widget buildDisclaimerStep(String userName) => Builder(
  builder: (context) => MedicalDisclaimerScreen(
    userName: userName,
    onAccept: () => _acceptDisclaimerAndContinue(context),
  ),
);

Widget buildModeSelectionStep(String userName) => Builder(
  builder: (context) => ModeSelectionScreen(
    userName: userName,
    onModeSelected: (mode) => handleModeSelected(context, mode, userName),
  ),
);

/// Tras autenticar, se vuelve a leer la sesión: nunca se concede acceso
/// privado usando únicamente el nombre escrito en el formulario.
Future<void> continueAfterAuth(
  BuildContext context,
  String fallbackName,
) async {
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  SessionInfo? session;
  try {
    session = await container.read(userSessionRepositoryProvider).readSession();
  } catch (_) {
    session = null;
  }
  if (!context.mounted) return;
  if (session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos confirmar su sesión. Intente de nuevo.'),
      ),
    );
    return;
  }
  container.read(currentModeProvider.notifier).state = session.currentMode == 3
      ? 3
      : 2;
  container
      .read(navigationSessionProvider.notifier)
      .restore(session, fallbackName: fallbackName);
  router.go(destinationForSession(container.read(navigationSessionProvider)));
}

Future<void> _acceptDisclaimerAndContinue(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  final session = container.read(navigationSessionProvider).session;
  if (session == null) throw StateError('Se necesita una sesión activa');
  await container
      .read(authRepositoryProvider)
      .acceptDisclaimer(uid: session.uid);
  if (!context.mounted) return;
  if (container.read(navigationSessionProvider).session?.uid != session.uid) {
    throw StateError('La sesión cambió durante el guardado');
  }
  container.read(navigationSessionProvider.notifier).acceptDisclaimer();
  router.go(AppRoutes.modeSelection);
}

Future<void> handleModeSelected(
  BuildContext context,
  int mode,
  String userName,
) async {
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  final session = container.read(navigationSessionProvider).session;
  if (session == null) throw StateError('Se necesita una sesión activa');
  await container
      .read(authRepositoryProvider)
      .updateCurrentMode(uid: session.uid, mode: mode);
  await container.read(getOrCreateCognitiveProfileProvider)(
    GetOrCreateCognitiveProfileParams(activeMode: mode),
  );
  if (!context.mounted) return;
  container.read(currentModeProvider.notifier).state = mode == 3 ? 3 : 2;
  container.read(navigationSessionProvider.notifier).selectMode(mode);
  router.go(AppRoutes.home);
}
