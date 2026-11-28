import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/constants/app_palettes.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/main.dart';
import 'package:aurora_care/presentation/onboarding/auth_gate.dart';

/// Pantalla de prueba que solo existe para esta prueba: lee AppColors.primary
/// en su build(), igual que cualquier pantalla real de la app.
class _SondaDeColor extends StatefulWidget {
  const _SondaDeColor();

  @override
  State<_SondaDeColor> createState() => _SondaDeColorState();
}

class _SondaDeColorState extends State<_SondaDeColor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(key: const ValueKey('sonda-color'), color: AppColors.primary),
    );
  }
}

void main() {
  testWidgets(
    'cambiar de tema actualiza los colores en pantalla sin perder la navegación',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Sin sesión guardada: evita tocar Firebase y el splash de 800 ms.
          startupSessionProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const AuroraCareApp()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Por defecto, Aurora.
      expect(AppColors.primary, AppPalettes.aurora.paleta.primary);

      // Empuja una pantalla encima de la actual (como abrir el perfil desde
      // home), para poder comprobar que un cambio de tema no la cierra.
      final contextRaiz = tester.element(find.byType(Navigator).first);
      Navigator.of(contextRaiz).push(
        MaterialPageRoute<void>(builder: (_) => const _SondaDeColor()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sonda-color')), findsOneWidget);
      final estadoAntes = tester.state(find.byType(_SondaDeColor));
      expect(
        tester.widget<Container>(find.byKey(const ValueKey('sonda-color'))).color,
        AppPalettes.aurora.paleta.primary,
      );

      // Cambia el tema, como si se hubiera elegido "Océano" en el perfil.
      await container.read(themeProvider.notifier).set(AppPalettes.oceano);
      await tester.pump();
      await tester.pumpAndSettle();

      // La pantalla sigue siendo la MISMA instancia (no se recreó: la
      // navegación no se perdió), pero su color ya refleja la nueva paleta.
      expect(find.byKey(const ValueKey('sonda-color')), findsOneWidget);
      final estadoDespues = tester.state(find.byType(_SondaDeColor));
      expect(
        identical(estadoAntes, estadoDespues),
        isTrue,
        reason: 'La pantalla no debería haberse recreado al cambiar de tema.',
      );
      expect(
        tester.widget<Container>(find.byKey(const ValueKey('sonda-color'))).color,
        AppPalettes.oceano.paleta.primary,
      );
      expect(AppColors.primary, AppPalettes.oceano.paleta.primary);
    },
  );
}
