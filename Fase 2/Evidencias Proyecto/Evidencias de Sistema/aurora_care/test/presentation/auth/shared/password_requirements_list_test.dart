import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/presentation/auth/shared/password_policy.dart';
import 'package:aurora_care/presentation/auth/shared/password_requirements_list.dart';

void main() {
  const requisitos = [
    PasswordRequirement(label: 'De 12 a 20 caracteres', met: true),
    PasswordRequirement(label: 'Una letra mayúscula', met: false),
    PasswordRequirement(label: 'Una letra minúscula', met: true),
    PasswordRequirement(label: 'Un número', met: false),
  ];

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PasswordRequirementsList(requirements: requisitos),
        ),
      ),
    );
  }

  testWidgets('muestra los 4 requisitos con su texto', (tester) async {
    await pump(tester);

    for (final requisito in requisitos) {
      expect(find.text(requisito.label), findsOneWidget);
    }
  });

  testWidgets(
    'cumplidos muestran el ícono de check en verde; pendientes, el '
    'círculo vacío en el color secundario (nunca solo color)',
    (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));

      final iconoCumplido = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline_rounded).first,
      );
      expect(iconoCumplido.color, AppColors.success);

      final iconoPendiente = tester.widget<Icon>(
        find.byIcon(Icons.circle_outlined).first,
      );
      expect(iconoPendiente.color, AppColors.textSecondary);
    },
  );

  testWidgets(
    'cada requisito tiene un anuncio de accesibilidad con su estado',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        find.bySemanticsLabel('De 12 a 20 caracteres: cumplido'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Una letra mayúscula: pendiente'),
        findsOneWidget,
      );

      handle.dispose();
    },
  );

  testWidgets('se construye sin overflow con textScale 1,3 en 360x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsList(requirements: requisitos),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
