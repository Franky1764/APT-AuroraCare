import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_palettes.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/audio/background_music_lifecycle_observer.dart';
import 'core/firebase_providers.dart';
import 'core/providers/accessibility_providers.dart';
import 'data/repositories/caregiver_invite_repository_impl.provider.dart';
import 'data/sources/preferences_local_source.dart';

import 'core/router/app_router.dart';
import 'core/router/navigation_session.dart';
import 'data/sources/practice_feedback_platform.dart';
import 'domain/entities/account_role.dart';
import 'presentation/caregiver_dashboard/elder_caregiver_departure.dart';
import 'presentation/elder_alerts/elder_alerts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPreferences = await SharedPreferences.getInstance();

  // Activar el tema guardado ANTES de runApp: la primera pantalla ya se
  // pinta con la paleta correcta, sin parpadeo de Aurora a la paleta real.
  final temaGuardado = AppPalettes.porId(
    PreferencesLocalSource(sharedPreferences).getThemeId(),
  );
  AppColors.usarPaleta((temaGuardado ?? AppPalettes.aurora).paleta);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        caregiverInviteRepositoryOverride,
        exerciseVibrationProvider.overrideWith(
          (ref) =>
              () => ref.read(vibrationLevelProvider.notifier).pulse(),
        ),
      ],
      child: const AuroraCareApp(),
    ),
  );
}

class AuroraCareApp extends ConsumerWidget {
  const AuroraCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avisa al adulto mayor si su cuidador termina el vínculo.
    ref.watch(elderCaregiverDepartureProvider);
    // Avisos de ánimo del adulto mayor (16:00, 20:00 y domingo 18:00).
    ref.watch(elderAlertsSyncProvider);
    ref.listen(navigationSessionProvider, (previous, next) {
      if (!next.initialized) return;
      if (previous?.initialized == true &&
          previous?.session?.uid == next.session?.uid &&
          previous?.session?.role == next.session?.role) {
        return;
      }
      final session = next.session;
      unawaited(
        ref
            .read(practiceFeedbackPlatformProvider)
            .configure(
              account: session?.role == AccountRole.elder ? session?.uid : null,
              enabled: ref.read(notificationsEnabledProvider),
            ),
      );
    });
    // Tema de color (SCRUM-temas de color): AppColors.x son getters sobre
    // estado global, no datos que fluyan por un InheritedWidget — así que
    // un ref.watch no basta para refrescar pantallas ya construidas.
    // No usamos una Key en la raíz: eso destruiría todo el árbol de
    // Elements y cerraría cualquier pantalla abierta (ej. perfil),
    // reiniciando la navegación. En vez de eso, activamos la paleta y
    // marcamos TODOS los elementos ya montados para que se reconstruyan
    // en su lugar: cada widget vuelve a ejecutar build() y relee
    // AppColors.x, pero ningún Element ni State se recrea, así que la
    // navegación se conserva intacta.
    ref.listen(themeProvider, (previous, next) {
      if (previous?.id == next.id) return;
      AppColors.usarPaleta(next.paleta);
      _reconstruirDesdeLaRaiz(context as Element);
    });
    return BackgroundMusicLifecycleObserver(
      child: MaterialApp.router(
        theme: AppTheme.light,
        title: 'AuroraCare',
        // Tamaño de texto global (SCRUM-perfil): el toggle A/A+ de
        // profile_screen.dart escribe en textScaleProvider, y este builder
        // aplica el TextScaler a toda la app, no solo a esa pantalla.
        builder: (context, child) {
          final scale = ref.watch(textScaleProvider);
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        routerConfig: ref.watch(appRouterProvider),
      ),
    );
  }
}

/// Marca [elemento] y todos sus descendientes para reconstrucción, sin
/// recrear ninguno. markNeedsBuild() no depende de comparar el widget
/// viejo con uno nuevo (por eso no lo frena un widget const en el medio
/// del árbol, a diferencia de una reconstrucción "normal" de más arriba):
/// simplemente obliga a ese Element a volver a ejecutar build() en el
/// próximo frame, conservando su State tal cual está.
void _reconstruirDesdeLaRaiz(Element elemento) {
  elemento.markNeedsBuild();
  elemento.visitChildren(_reconstruirDesdeLaRaiz);
}
