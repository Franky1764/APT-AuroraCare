import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/presentation/games/shared/status_banner.dart';

void main() {
  testWidgets('muestra el texto y el ícono recibidos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusBanner(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            text: 'Diferencia encontrada, 1 de 3',
          ),
        ),
      ),
    );

    expect(find.text('Diferencia encontrada, 1 de 3'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.check_circle_outline_rounded);
    expect(icon.color, AppColors.success);
  });

  testWidgets(
    'el texto queda como Semantics liveRegion y no se anuncia dos veces',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusBanner(
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
              text: 'No es una diferencia',
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(StatusBanner));
      expect(semantics.label, 'No es una diferencia');
      expect(semantics.flagsCollection.isLiveRegion, isTrue);

      // La fila visual (ícono + texto) queda excluida de la semántica:
      // "No es una diferencia" aparece una sola vez en el árbol.
      expect(find.bySemanticsLabel('No es una diferencia'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('aplica el color recibido al ícono', (tester) async {
    final colorDePrueba = AppColors.primary;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusBanner(
            icon: Icons.touch_app_outlined,
            color: colorDePrueba,
            text: 'Toque la imagen donde note un cambio',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, colorDePrueba);
  });
}
