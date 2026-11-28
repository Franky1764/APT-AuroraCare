import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/data/repositories/fake_caregiver_invite_repository.dart';
import 'package:aurora_care/domain/repositories/caregiver_invite_repository.provider.dart';
import 'package:aurora_care/presentation/profile/caregiver_link_notifier.dart';
import 'package:aurora_care/presentation/profile/caregiver_link_screen.dart';

Future<SharedPreferences> _prefsVacias() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      caregiverInviteRepositoryProvider.overrideWith((ref) {
        final repo = FakeCaregiverInviteRepository(prefs);
        ref.onDispose(repo.dispose);
        return repo;
      }),
    ],
    child: const MaterialApp(home: CaregiverLinkScreen()),
  );
}

/// NUNCA pumpAndSettle() en estos tests: la pantalla tiene un
/// Timer.periodic propio (la cuenta regresiva) que nunca deja de
/// disparar solo, así que pumpAndSettle() jamás "asienta" — se agota el
/// límite de iteraciones. Se usan pumps acotados en su lugar (mismo
/// motivo documentado en breathing_session_screen_test.dart).
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _generarCodigo(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Generar código'));
  await _asentar(tester);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar y generar'));
  await _asentar(tester);
}

void main() {
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    testWidgets('en ${tamanio.width.toInt()}x${tamanio.height.toInt()}: estado '
        'inicial y activo se construyen sin overflow', (tester) async {
      final prefs = await _prefsVacias();
      tester.view.physicalSize = tamanio;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(prefs));
      await _asentar(tester);
      expect(tester.takeException(), isNull);

      await _generarCodigo(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  }

  testWidgets('con textScale 1,3 no hay overflow (se acepta scroll)', (
    tester,
  ) async {
    final prefs = await _prefsVacias();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(prefs),
      ),
    );
    await _asentar(tester);

    expect(tester.takeException(), isNull);
  });

  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    testWidgets('diálogo de consentimiento en ${tamanio.width.toInt()}x'
        '${tamanio.height.toInt()} (textScale 1,0): se ve completo, sin '
        'overflow y sin scroll', (tester) async {
      final prefs = await _prefsVacias();
      tester.view.physicalSize = tamanio;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(prefs));
      await _asentar(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Generar código'));
      await _asentar(tester);

      expect(tester.takeException(), isNull);
      // Los 4 puntos, cada uno en su propio Text (ya no un solo
      // párrafo corrido).
      expect(find.textContaining('quien lo escanee quedará'), findsOneWidget);
      expect(
        find.textContaining('Su cuidador podrá ver cuándo practicó'),
        findsOneWidget,
      );
      expect(
        find.textContaining('sirve una sola vez y vence en 10 minutos'),
        findsOneWidget,
      );
      expect(find.textContaining('Puede desvincularlo'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Aceptar y generar'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    });
  }

  testWidgets('diálogo de consentimiento en 360x640 con textScale 1,3: sin '
      'overflow (se acepta scroll)', (tester) async {
    final prefs = await _prefsVacias();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(prefs),
      ),
    );
    await _asentar(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Generar código'));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('quien lo escanee quedará'), findsOneWidget);
    expect(find.textContaining('Puede desvincularlo'), findsOneWidget);
  });

  testWidgets('sin aceptar el consentimiento, no se genera ningún código', (
    tester,
  ) async {
    final prefs = await _prefsVacias();
    await tester.pumpWidget(_app(prefs));
    await _asentar(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Generar código'));
    await _asentar(tester);
    expect(
      find.textContaining('quien lo escanee quedará vinculado'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await _asentar(tester);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Generar código'), findsOneWidget);
  });

  testWidgets(
    'al aceptar el consentimiento, muestra el QR y la cuenta regresiva',
    (tester) async {
      final prefs = await _prefsVacias();
      await tester.pumpWidget(_app(prefs));
      await _asentar(tester);

      await _generarCodigo(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Vence en'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar invitación'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancelar la invitación vuelve a la vista inicial', (
    tester,
  ) async {
    final prefs = await _prefsVacias();
    await tester.pumpWidget(_app(prefs));
    await _asentar(tester);

    await _generarCodigo(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cancelar invitación'),
    );
    await _asentar(tester);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Generar código'), findsOneWidget);
  });

  testWidgets(
    'cuando la invitación vence, muestra el mensaje y permite generar otra',
    (tester) async {
      final prefs = await _prefsVacias();
      await tester.pumpWidget(_app(prefs));
      await _asentar(tester);

      await _generarCodigo(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CaregiverLinkScreen)),
      );
      final repo = container.read(
        caregiverInviteRepositoryProvider,
      ) as FakeCaregiverInviteRepository;
      final token = container.read(caregiverLinkProvider).value!.invite!.token;
      await repo.cancelInvite(token);
      await _asentar(tester);

      expect(find.text('El código venció'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Generar uno nuevo'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cuando se vincula un cuidador, muestra el mensaje de éxito', (
    tester,
  ) async {
    final prefs = await _prefsVacias();
    await tester.pumpWidget(_app(prefs));
    await _asentar(tester);

    await _generarCodigo(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaregiverLinkScreen)),
    );
    final repo = container.read(
      caregiverInviteRepositoryProvider,
    ) as FakeCaregiverInviteRepository;
    final token = container.read(caregiverLinkProvider).value!.invite!.token;
    repo.simulateRedeemed(token);
    await _asentar(tester);

    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Volver'), findsOneWidget);
  });
}
