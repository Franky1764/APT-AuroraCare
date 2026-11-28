import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/memory_category.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_controller.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_screen.dart';

import '../../../../helpers/fake_sound_service.dart';

const _familia = MemoryCategory(
  id: 'familia',
  name: 'Familia y amistades',
  isPredefined: true,
  iconKey: 'familia',
);

/// 5 respuestas distintas: ya jugable (>=5 respondidas, >=4 distintas).
const _datosJugablesBase = {
  'mis_recuerdos_v1_uid1':
      '{"version": 1, "avisoPrivacidadVisto": true, '
      '"respuestasSugeridas": {'
      '"familia_padre": {"answer": "Juan", "status": "respondida"}, '
      '"familia_madre": {"answer": "Rosa", "status": "respondida"}, '
      '"familia_pareja": {"answer": "Ana", "status": "respondida"}, '
      '"familia_hijo_mayor": {"answer": "Pedro", "status": "respondida"}, '
      '"familia_hermano": {"answer": "Luis", "status": "respondida"}'
      '}, "preguntasPropias": []}',
};

Future<SharedPreferences> _mockPrefs({required bool soundsEnabled}) async {
  SharedPreferences.setMockInitialValues({
    ..._datosJugablesBase,
    'pref_sounds': soundsEnabled,
  });
  return SharedPreferences.getInstance();
}

ProviderContainer _buildContainer(SharedPreferences prefs, FakeSoundService soundService) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
  container.listen(
    misRecuerdosQuizControllerProvider(('uid1', 'familia')),
    (_, _) {},
  );
  return container;
}

Future<void> _pumpQuiz(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('con sonidos activados, elegir la respuesta correcta suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final prefs = await _mockPrefs(soundsEnabled: true);
    final container = _buildContainer(prefs, fakeSound);
    addTearDown(container.dispose);

    await _pumpQuiz(tester, container);

    final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));
    final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
    await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha de aciertos sube hasta acierto_5 y se queda ahí; al '
    'terminar (5 de 5), suena resultado_excelente',
    (tester) async {
      final fakeSound = FakeSoundService();
      final prefs = await _mockPrefs(soundsEnabled: true);
      final container = _buildContainer(prefs, fakeSound);
      addTearDown(container.dispose);

      await _pumpQuiz(tester, container);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

      for (var i = 0; i < 5; i++) {
        final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
        await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
        await tester.pump();
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
        SoundEffect.resultadoExcelente,
      ]);
    },
  );

  testWidgets(
    'un error suena error_suave y reinicia la racha (vuelve a sonar '
    'acierto_1 en el siguiente acierto)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final prefs = await _mockPrefs(soundsEnabled: true);
      final container = _buildContainer(prefs, fakeSound);
      addTearDown(container.dispose);

      await _pumpQuiz(tester, container);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

      final indiceCorrecto1 = container.read(provider).value!.actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto1));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();

      final actual2 = container.read(provider).value!.actual;
      final indiceIncorrecto = (actual2.indiceCorrecto + 1) % 4;
      await tester.tap(find.byType(OutlinedButton).at(indiceIncorrecto));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.errorSuave]);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();

      final indiceCorrecto3 = container.read(provider).value!.actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto3));
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.acierto1, SoundEffect.errorSuave, SoundEffect.acierto1],
      );
    },
  );

  testWidgets(
    'con 3 de 5 (60%) al terminar, suena resultado_bien (no excelente ni '
    'ánimo)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final prefs = await _mockPrefs(soundsEnabled: true);
      final container = _buildContainer(prefs, fakeSound);
      addTearDown(container.dispose);

      await _pumpQuiz(tester, container);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

      // Acierta las preguntas 1-3, falla las 2 últimas: 3 de 5 = 60%.
      for (var i = 0; i < 5; i++) {
        final actual = container.read(provider).value!.actual;
        final indice = i < 3
            ? actual.indiceCorrecto
            : (actual.indiceCorrecto + 1) % 4;
        await tester.tap(find.byType(OutlinedButton).at(indice));
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
        await tester.pump();
      }

      expect(fakeSound.played.last, SoundEffect.resultadoBien);
      expect(container.read(provider).value!.aciertos, 3);
    },
  );

  testWidgets('"Jugar otra vez" reinicia la racha: vuelve a sonar acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final prefs = await _mockPrefs(soundsEnabled: true);
    final container = _buildContainer(prefs, fakeSound);
    addTearDown(container.dispose);

    await _pumpQuiz(tester, container);
    final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

    for (var i = 0; i < 5; i++) {
      final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();
    }
    fakeSound.played.clear();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Jugar otra vez'));
    await tester.pump();
    await tester.pump();

    final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
    await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets('con sonidos desactivados, no suena nada: ni acierto, ni error, ni cierre', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final prefs = await _mockPrefs(soundsEnabled: false);
    final container = _buildContainer(prefs, fakeSound);
    addTearDown(container.dispose);

    await _pumpQuiz(tester, container);
    final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

    for (var i = 0; i < 5; i++) {
      final actual = container.read(provider).value!.actual;
      final indice = i == 0 ? (actual.indiceCorrecto + 1) % 4 : actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indice));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();
    }

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (pregunta ya respondida) no suena otra vez',
    (tester) async {
      final fakeSound = FakeSoundService();
      final prefs = await _mockPrefs(soundsEnabled: true);
      final container = _buildContainer(prefs, fakeSound);
      addTearDown(container.dispose);

      await _pumpQuiz(tester, container);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));

      final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // Las opciones quedan deshabilitadas (onTap: null) tras responder,
      // pero aunque el controller llegara a recibir el toque, elegirOpcion
      // lo ignora (respondioActual ya es true): no debe sonar de nuevo.
      await tester.tap(find.byType(OutlinedButton).first, warnIfMissed: false);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );
}
