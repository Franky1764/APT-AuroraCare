import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/memory_category.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_fill_screen.dart';

import '../../../../helpers/fake_sound_service.dart';

const _familia = MemoryCategory(
  id: 'familia',
  name: 'Familia y amistades',
  isPredefined: true,
  iconKey: 'familia',
);

Future<SharedPreferences> _mockPrefs({required bool soundsEnabled}) async {
  SharedPreferences.setMockInitialValues({'pref_sounds': soundsEnabled});
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs, FakeSoundService soundService) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(soundService),
    ],
    child: const MaterialApp(
      home: MisRecuerdosFillScreen(categoria: _familia, uid: 'uid1'),
    ),
  );
}

void main() {
  testWidgets(
    'con sonidos activados, guardar una respuesta nueva suena '
    'nivel_completado',
    (tester) async {
      final fakeSound = FakeSoundService();
      final prefs = await _mockPrefs(soundsEnabled: true);
      await tester.pumpWidget(_app(prefs, fakeSound));
      await tester.pumpAndSettle();

      final campoPadre = find.descendant(
        of: find.ancestor(
          of: find.text('Nombre de su padre'),
          matching: find.byType(Card),
        ),
        matching: find.byType(TextField),
      );
      await tester.enterText(campoPadre, 'Juan');
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Guardar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Sus respuestas se guardaron.'), findsOneWidget);
      expect(fakeSound.played, [SoundEffect.nivelCompletado]);
    },
  );

  testWidgets('con sonidos desactivados, guardar no suena nada', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final prefs = await _mockPrefs(soundsEnabled: false);
    await tester.pumpWidget(_app(prefs, fakeSound));
    await tester.pumpAndSettle();

    final campoPadre = find.descendant(
      of: find.ancestor(
        of: find.text('Nombre de su padre'),
        matching: find.byType(Card),
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(campoPadre, 'Juan');
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Guardar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Sus respuestas se guardaron.'), findsOneWidget);
    expect(fakeSound.played, isEmpty);
  });
}
