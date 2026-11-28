import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/presentation/breathing/breathing_duration_screen.dart';
import 'package:aurora_care/presentation/breathing/breathing_session_screen.dart';

bool _isSelected(WidgetTester tester, String title) {
  final card = tester.widget<Card>(
    find.ancestor(of: find.text(title), matching: find.byType(Card)),
  );
  final side = (card.shape as RoundedRectangleBorder).side;
  return side.color == AppColors.primary && side.width == 3;
}

/// preferencesLocalSourceProvider (y por lo tanto BreathingDurationScreen)
/// lee de SharedPreferences, así que todo test necesita mockear sus
/// valores iniciales y sobreescribir sharedPreferencesProvider.
Future<SharedPreferences> _mockPrefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs, {String userName = 'Rosa'}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: BreathingDurationScreen(userName: userName)),
  );
}

void main() {
  testWidgets(
    'muestra las 3 opciones de duración, con "5 minutos" preseleccionada '
    'cuando no hay preferencia guardada',
    (WidgetTester tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));

      expect(find.text('2 minutos'), findsOneWidget);
      expect(find.text('Corto'), findsOneWidget);
      expect(find.text('5 minutos'), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);
      expect(find.text('10 minutos'), findsOneWidget);
      expect(find.text('Largo'), findsOneWidget);

      expect(_isSelected(tester, '5 minutos'), isTrue);
      expect(_isSelected(tester, '2 minutos'), isFalse);
      expect(_isSelected(tester, '10 minutos'), isFalse);
    },
  );

  testWidgets('tocar otra duración la selecciona', (WidgetTester tester) async {
    final prefs = await _mockPrefs();
    await tester.pumpWidget(_app(prefs));

    await tester.tap(find.text('10 minutos'));
    await tester.pump();

    expect(_isSelected(tester, '10 minutos'), isTrue);
    expect(_isSelected(tester, '5 minutos'), isFalse);
  });

  testWidgets(
    '"Comenzar" navega a BreathingSessionScreen con la duración elegida '
    'y la guarda como preferencia',
    (WidgetTester tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));

      await tester.tap(find.text('2 minutos'));
      await tester.pump();

      final startButton = find.widgetWithText(ElevatedButton, 'Comenzar');
      await tester.ensureVisible(startButton);
      await tester.pump();
      await tester.tap(startButton);
      await tester.pump();

      final session = tester.widget<BreathingSessionScreen>(
        find.byType(BreathingSessionScreen, skipOffstage: false),
      );
      expect(session.minutes, 2);
      expect(session.userName, 'Rosa');
      expect(prefs.getInt('pref_breathing_minutes'), 2);
    },
  );

  testWidgets(
    'preselecciona la última duración guardada',
    (WidgetTester tester) async {
      final prefs = await _mockPrefs({'pref_breathing_minutes': 10});
      await tester.pumpWidget(_app(prefs));

      expect(_isSelected(tester, '10 minutos'), isTrue);
      expect(_isSelected(tester, '5 minutos'), isFalse);
    },
  );

  testWidgets(
    'un valor guardado inválido cae a 5 minutos',
    (WidgetTester tester) async {
      final prefs = await _mockPrefs({'pref_breathing_minutes': 7});
      await tester.pumpWidget(_app(prefs));

      expect(_isSelected(tester, '5 minutos'), isTrue);
      expect(_isSelected(tester, '2 minutos'), isFalse);
      expect(_isSelected(tester, '10 minutos'), isFalse);
    },
  );

  testWidgets('las tarjetas de duración tienen etiquetas de semántica claras', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();

    final prefs = await _mockPrefs();
    await tester.pumpWidget(_app(prefs));

    expect(
      find.bySemanticsLabel('5 minutos, Recomendado, seleccionado'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('2 minutos, Corto'), findsOneWidget);
    expect(find.bySemanticsLabel('10 minutos, Largo'), findsOneWidget);
    expect(find.bySemanticsLabel('Comenzar'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('se construye sin overflow con textScaler 1.3', (
    WidgetTester tester,
  ) async {
    final prefs = await _mockPrefs();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(prefs),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
