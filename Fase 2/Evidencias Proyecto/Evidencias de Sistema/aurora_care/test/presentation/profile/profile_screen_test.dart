import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/presentation/profile/profile_portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/audio/music_route_scope.dart';
import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/constants/app_palettes.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/user.dart';
import 'package:aurora_care/domain/repositories/auth_repository.dart';
import 'package:aurora_care/presentation/onboarding/mode_selection_screen.dart';
import 'package:aurora_care/presentation/profile/profile_screen.dart';
import 'package:aurora_care/presentation/profile/theme_selection_screen.dart';
import 'package:aurora_care/presentation/shared/current_mode_provider.dart';

import '../../helpers/fake_sound_service.dart';

class _FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<User> loginElder({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptDisclaimer({required String uid}) async {}

  @override
  Future<bool> hasMetricsConsent({required String uid}) async => true;

  @override
  Future<void> setMetricsConsent({
    required String uid,
    required bool given,
  }) async {}

  @override
  Future<void> updateCurrentMode({
    required String uid,
    required int mode,
  }) async {}
}

class _FailingAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {
    throw Exception('fallo simulado de red');
  }

  @override
  Future<User> loginElder({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptDisclaimer({required String uid}) async {}

  @override
  Future<bool> hasMetricsConsent({required String uid}) async => true;

  @override
  Future<void> setMetricsConsent({
    required String uid,
    required bool given,
  }) async {}

  @override
  Future<void> updateCurrentMode({
    required String uid,
    required int mode,
  }) async {}
}

/// Envuelve ProfileScreen en una ruta "raíz" empujada desde otra pantalla,
/// para reproducir cómo se llega a ProfileScreen desde Home y poder
/// verificar que el logout reemplaza toda la pila con buildWelcomeFlow(),
/// incluso si esa ruta raíz NO era una WelcomeScreen (caso de sesión
/// restaurada por AuthGate, que puede arrancar directo en Home).
Widget _appWithProfilePushedOnTop() {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const Text('Abrir perfil'),
          ),
        ),
      ),
    ),
  );
}

Widget _wrap(Widget child, {required ProviderContainer container}) {
  return UncontrolledProviderScope(container: container, child: child);
}

/// textScaleProvider/soundsEnabledProvider/notificationsEnabledProvider
/// ahora leen de SharedPreferences, así que todo test que construya
/// ProfileScreen necesita mockear sus valores iniciales y sobreescribir
/// sharedPreferencesProvider con la instancia (mock) real.
Future<ProviderContainer> _buildContainer({
  Map<String, Object> initialPrefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
}

class _FixedMusicEnabled extends MusicEnabledNotifier {
  _FixedMusicEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

void main() {
  testWidgets('desde Mi perfil se pueden consultar las preguntas de privacidad', (
    tester,
  ) async {
    final container = await _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container),
    );

    final help = find.text('Ayuda y soporte');
    await tester.ensureVisible(help);
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.text('Privacidad y datos'), findsOneWidget);

    await tester.tap(find.text('¿Qué datos guarda AuroraCare?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sincronizarse con Firebase'), findsOneWidget);

    final caregiverQuestion = find.text('¿Qué información ve un cuidador vinculado?');
    await tester.ensureVisible(caregiverQuestion);
    await tester.tap(caregiverQuestion);
    await tester.pumpAndSettle();

    expect(find.textContaining('sincronizarse con Firebase'), findsNothing);
    expect(find.textContaining('la fecha de la última práctica'), findsOneWidget);

    final reportQuestion = find.text('¿Dónde veo o guardo mi informe?');
    await tester.scrollUntilVisible(reportQuestion, 200);
    await tester.tap(reportQuestion);
    await tester.pumpAndSettle();

    expect(find.textContaining('la fecha de la última práctica'), findsNothing);
    expect(find.textContaining('para conservar el archivo'), findsOneWidget);
  });

  testWidgets('el avatar elegido se conserva solo para la cuenta activa', (
    tester,
  ) async {
    final container = await _buildContainer();
    addTearDown(container.dispose);
    final navigation = container.read(navigationSessionProvider.notifier);
    const owner = SessionInfo(uid: 'a', email: 'a@example.com', currentMode: 2);
    navigation.restore(owner);
    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container),
    );

    await tester.tap(find.byTooltip('Cambiar foto o avatar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoja'));
    await tester.pumpAndSettle();
    expect(container.read(profilePortraitProvider), 'avatar:leaf');
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);

    navigation.restore(
      const SessionInfo(uid: 'b', email: 'b@example.com', currentMode: 2),
    );
    await tester.pump();
    expect(container.read(profilePortraitProvider), isNull);
    navigation.restore(owner);
    await tester.pump();
    expect(container.read(profilePortraitProvider), 'avatar:leaf');
  });

  testWidgets('ProfileScreen renderiza el nombre del usuario', (
    WidgetTester tester,
  ) async {
    final container = await _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        const MaterialApp(home: ProfileScreen(userName: 'Rosa García')),
        container: container,
      ),
    );

    expect(find.text('Rosa García'), findsOneWidget);
  });

  testWidgets('tocar A+ actualiza textScaleProvider a 1.3 y lo guarda', (
    WidgetTester tester,
  ) async {
    final container = await _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container),
    );

    expect(container.read(textScaleProvider), 1.0);

    await tester.tap(find.text('A+'));
    await tester.pump();
    expect(container.read(textScaleProvider), 1.3);
    // Persistido de inmediato, no solo en memoria.
    expect(container.read(preferencesLocalSourceProvider).getTextScale(), 1.3);

    await tester.tap(find.text('A'));
    await tester.pump();
    expect(container.read(textScaleProvider), 1.0);
    expect(container.read(preferencesLocalSourceProvider).getTextScale(), 1.0);
  });

  testWidgets(
    'un valor de textScale inválido guardado cae a 1.0 al construir',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {'pref_text_scale': 2.5},
      );
      addTearDown(container.dispose);

      expect(container.read(textScaleProvider), 1.0);
    },
  );

  testWidgets(
    'la fila "Tema" muestra el nombre del tema actual',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {'pref_theme_id': AppPalettes.oceano.id},
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      expect(find.text('Tema'), findsOneWidget);
      expect(find.text(AppPalettes.oceano.nombre), findsOneWidget);
    },
  );

  testWidgets(
    'tocar la fila "Tema" abre la pantalla de selección de temas',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final filaTema = find.text('Tema');
      await tester.ensureVisible(filaTema);
      await tester.tap(filaTema);
      await tester.pumpAndSettle();

      expect(find.byType(ThemeSelectionScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Elegir tema'), findsOneWidget);
    },
  );

  testWidgets(
    'un id de tema inválido guardado cae a Aurora al construir',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {'pref_theme_id': 'no_existe'},
      );
      addTearDown(container.dispose);

      expect(container.read(themeProvider).id, AppPalettes.aurora.id);
    },
  );

  testWidgets(
    'Sonidos y Notificaciones guardados se muestran al abrir Mi perfil',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {
          'pref_sounds': false,
          'pref_notifications_opt_in_v2': false,
        },
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final soundsSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Sonidos'),
      );
      final notificationsSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Notificaciones'),
      );
      expect(soundsSwitch.value, isFalse);
      expect(notificationsSwitch.value, isFalse);
    },
  );

  testWidgets(
    '"Música de fondo" aparece apagada por defecto, independiente de '
    '"Sonidos"',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': true},
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final sonidos = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Sonidos'),
      );
      final musica = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Música de fondo'),
      );
      expect(sonidos.value, isTrue);
      expect(musica.value, isFalse);
    },
  );

  testWidgets(
    'activar "Música de fondo" suena musica_menu de inmediato y persiste '
    'la preferencia, sin afectar "Sonidos"',
    (WidgetTester tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final musica = find.widgetWithText(SwitchListTile, 'Música de fondo');
      await tester.ensureVisible(musica);
      await tester.tap(musica);
      await tester.pump();

      expect(fakeSound.musicStarted, [MusicTrack.menu]);
      expect(fakeSound.played, isEmpty); // No toca los efectos de "Sonidos".
      expect(
        container.read(preferencesLocalSourceProvider).getMusicEnabled(),
        isTrue,
      );
      expect(container.read(soundsEnabledProvider), isTrue); // Sin cambios.

      await tester.tap(musica);
      await tester.pump();

      expect(fakeSound.musicStoppedCount, 1);
      expect(
        container.read(preferencesLocalSourceProvider).getMusicEnabled(),
        isFalse,
      );
    },
  );

  testWidgets(
    'activar "Sonidos" reproduce acierto_1 como vista previa, sin afectar '
    '"Música de fondo"',
    (WidgetTester tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': false},
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final sonidos = find.widgetWithText(SwitchListTile, 'Sonidos');
      await tester.ensureVisible(sonidos);
      await tester.tap(sonidos);
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.acierto1]);
      expect(fakeSound.musicStarted, isEmpty); // No toca "Música de fondo".
      expect(container.read(musicEnabledProvider), isFalse); // Sin cambios.
    },
  );

  testWidgets('el perfil guarda los niveles y permite probar la vibración', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _buildContainer(
      overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
    );
    addTearDown(container.dispose);
    final messenger = tester.binding.defaultBinaryMessenger;
    const feedback = MethodChannel('auroracare/practice_feedback');
    final calls = <String>[];
    messenger.setMockMethodCallHandler(feedback, (call) async {
      calls.add(call.method);
      return call.method == 'touchFeedbackEnabled' ? false : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(feedback, null));

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container),
    );

    final volume = find.widgetWithText(
      DropdownButtonFormField<int>,
      'Volumen de los efectos',
    );
    await tester.ensureVisible(volume);
    await tester.tap(volume);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bajo').last);
    await tester.pumpAndSettle();
    final preferences = container.read(preferencesLocalSourceProvider);
    expect(preferences.getSoundLevel(), 1);
    expect(fakeSound.played, [SoundEffect.acierto1]);

    final vibration = find.widgetWithText(
      DropdownButtonFormField<int>,
      'Vibración en los ejercicios',
    );
    await tester.ensureVisible(vibration);
    await tester.tap(vibration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuerte').last);
    await tester.pumpAndSettle();
    expect(preferences.getVibrationLevel(), 2);
    await tester.tap(find.text('Abrir ajustes de sonido'));
    await tester.pumpAndSettle();
    expect(calls, ['touchFeedbackEnabled', 'soundSettings']);

    await tester.ensureVisible(vibration);
    await tester.tap(vibration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivada').last);
    await tester.pumpAndSettle();
    expect(preferences.getVibrationLevel(), 0);
    expect(find.text('Probar vibración'), findsNothing);
  });

  testWidgets(
    'Notificaciones solicita permiso y Sonidos actualiza la preferencia',
    (WidgetTester tester) async {
      const channel = MethodChannel('auroracare/practice_feedback');
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      var granted = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'requestPermission' ? granted : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final sonidos = find.widgetWithText(SwitchListTile, 'Sonidos');
      final notificaciones = find.widgetWithText(
        SwitchListTile,
        'Notificaciones',
      );
      await tester.ensureVisible(sonidos);
      await tester.tap(sonidos);
      await tester.pump();
      await tester.ensureVisible(notificaciones);
      await tester.tap(notificaciones);
      await tester.pump();

      final source = container.read(preferencesLocalSourceProvider);
      expect(source.getSoundsEnabled(), isFalse);
      expect(source.getNotificationsEnabled(), isFalse);
      expect(calls, contains('requestPermission'));

      granted = true;
      await tester.ensureVisible(notificaciones);
      await tester.tap(notificaciones);
      await tester.pumpAndSettle();
      expect(source.getNotificationsEnabled(), isTrue);
      expect(calls, contains('configure'));
    },
  );

  testWidgets(
    'no existe ningún texto ni ListTile con nombre de cuidador vinculado',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      expect(find.textContaining('Mi cuidador'), findsNothing);
    },
  );

  testWidgets(
    '"Mi modo de uso" siempre existe y muestra el modo actual (Modo 2 '
    'por defecto)',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      expect(find.widgetWithText(ListTile, 'Mi modo de uso'), findsOneWidget);
      expect(find.text('Jugar y ver mi progreso'), findsOneWidget);
    },
  );

  testWidgets('"Vincular Cuidador" no aparece en Modo 2 pero sí en Modo 3', (
    WidgetTester tester,
  ) async {
    final container2 = await _buildContainer();
    addTearDown(container2.dispose);

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container2),
    );
    expect(find.widgetWithText(ListTile, 'Vincular Cuidador'), findsNothing);

    final container3 = await _buildContainer(
      overrides: [currentModeProvider.overrideWith((ref) => 3)],
    );
    addTearDown(container3.dispose);

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container3),
    );

    expect(find.widgetWithText(ListTile, 'Vincular Cuidador'), findsOneWidget);
    expect(
      find.text('Jugar, ver mi progreso y conectar con un cuidador'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tocar "Mi modo de uso" abre ModeSelectionScreen en modo cambio',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(const MaterialApp(home: ProfileScreen()), container: container),
      );

      final miModoDeUso = find.widgetWithText(ListTile, 'Mi modo de uso');
      await tester.ensureVisible(miModoDeUso);
      await tester.tap(miModoDeUso);
      await tester.pumpAndSettle();

      final screen = tester.widget<ModeSelectionScreen>(
        find.byType(ModeSelectionScreen),
      );
      expect(screen.isChangeMode, isTrue);
      expect(screen.initialMode, 2);
      expect(find.text('Mi modo de uso'), findsOneWidget);
    },
  );

  testWidgets('el botón Cerrar sesión existe con color rojo', (
    WidgetTester tester,
  ) async {
    final container = await _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(const MaterialApp(home: ProfileScreen()), container: container),
    );

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cerrar sesión'),
    );

    expect(button.style?.foregroundColor?.resolve({}), AppColors.error);
  });

  testWidgets(
    'Cerrar sesión llama a AuthRepository.logout() y reemplaza toda la '
    'pila por buildWelcomeFlow()',
    (WidgetTester tester) async {
      final fakeAuthRepository = _FakeAuthRepository();
      final container = await _buildContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(_appWithProfilePushedOnTop(), container: container),
      );

      await tester.tap(find.text('Abrir perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      final logoutButton = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(fakeAuthRepository.logoutCalls, 1);
      expect(find.byType(ProfileScreen), findsNothing);
      // La pila se reemplazó por completo: ni la ruta raíz original
      // ("Abrir perfil") ni ProfileScreen siguen ahí, solo WelcomeScreen.
      expect(find.text('Abrir perfil'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Comenzar'), findsOneWidget);
    },
  );

  testWidgets(
    'con sesión activa y "Música de fondo" activada, entrar a Perfil '
    'pide musica_menu',
    (WidgetTester tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          musicEnabledProvider.overrideWith(() => _FixedMusicEnabled(true)),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(navigationSessionProvider.notifier)
          .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));

      await tester.pumpWidget(
        _wrap(
          MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: const ProfileScreen(),
          ),
          container: container,
        ),
      );
      await tester.pump();

      expect(fakeSound.musicStarted, [MusicTrack.menu]);
    },
  );

  testWidgets(
    'Cerrar sesión detiene la música de inmediato',
    (WidgetTester tester) async {
      final fakeSound = FakeSoundService();
      final fakeAuthRepository = _FakeAuthRepository();
      final container = await _buildContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepository),
          soundServiceProvider.overrideWithValue(fakeSound),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(navigationSessionProvider.notifier)
          .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));

      await tester.pumpWidget(
        _wrap(_appWithProfilePushedOnTop(), container: container),
      );

      await tester.tap(find.text('Abrir perfil'));
      await tester.pumpAndSettle();

      // Simula música sonando (lo pediría MusicRouteScope al entrar a
      // Perfil con el ajuste activo; acá se fuerza para no depender de
      // ese ajuste en este test).
      await fakeSound.playMusic(MusicTrack.menu);
      expect(fakeSound.isMusicPlaying, isTrue);

      final logoutButton = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(fakeSound.isMusicPlaying, isFalse);
      expect(fakeSound.musicStoppedCount, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('si logout() falla, muestra un SnackBar de error y no navega', (
    WidgetTester tester,
  ) async {
    final container = await _buildContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FailingAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(_appWithProfilePushedOnTop(), container: container),
    );

    await tester.tap(find.text('Abrir perfil'));
    await tester.pumpAndSettle();

    final logoutButton = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo cerrar la sesión. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
