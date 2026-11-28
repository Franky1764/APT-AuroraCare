import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/presentation/auth/shared/password_policy.dart';
import 'package:aurora_care/presentation/auth/shared/password_strength_meter.dart';

Future<void> _pump(WidgetTester tester, PasswordStrength strength) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PasswordStrengthMeter(strength: strength)),
    ),
  );
}

void main() {
  testWidgets('vacío: no muestra nada (sin barras ni etiqueta)', (
    tester,
  ) async {
    await _pump(tester, PasswordStrength.empty);
    expect(find.byType(Container), findsNothing);
    expect(find.textContaining('Seguridad'), findsNothing);
  });

  testWidgets('débil: 1 barra activa, etiqueta "Débil" en rojo (error)', (
    tester,
  ) async {
    await _pump(tester, PasswordStrength.weak);

    expect(find.text('Seguridad: Débil'), findsOneWidget);
    final texto = tester.widget<Text>(find.text('Seguridad: Débil'));
    expect(texto.style?.color, AppColors.error);

    final barras = tester.widgetList<Container>(find.byType(Container));
    final activas = barras
        .where((c) => (c.decoration as BoxDecoration).color == AppColors.error)
        .length;
    expect(activas, 1);
  });

  testWidgets('media: 2 barras activas, etiqueta "Media" en el color de alerta', (
    tester,
  ) async {
    await _pump(tester, PasswordStrength.medium);

    expect(find.text('Seguridad: Media'), findsOneWidget);
    final barras = tester.widgetList<Container>(find.byType(Container));
    final activas = barras
        .where(
          (c) => (c.decoration as BoxDecoration).color == AppColors.warning,
        )
        .length;
    expect(activas, 2);
  });

  testWidgets('fuerte: 3 barras activas, etiqueta "Fuerte"', (tester) async {
    await _pump(tester, PasswordStrength.strong);

    expect(find.text('Seguridad: Fuerte'), findsOneWidget);
    final barras = tester.widgetList<Container>(find.byType(Container));
    final activas = barras
        .where(
          (c) => (c.decoration as BoxDecoration).color == AppColors.success,
        )
        .length;
    expect(activas, 3);
  });

  testWidgets('muy fuerte: 4 barras activas, etiqueta "Muy fuerte"', (
    tester,
  ) async {
    await _pump(tester, PasswordStrength.veryStrong);

    expect(find.text('Seguridad: Muy fuerte'), findsOneWidget);
    final barras = tester.widgetList<Container>(find.byType(Container));
    final activas = barras
        .where(
          (c) => (c.decoration as BoxDecoration).color == AppColors.primary,
        )
        .length;
    expect(activas, 4);
  });

  testWidgets(
    'el nivel no depende solo del color: siempre hay una etiqueta de '
    'texto distinta por nivel',
    (tester) async {
      final etiquetas = <PasswordStrength, String>{
        PasswordStrength.weak: 'Seguridad: Débil',
        PasswordStrength.medium: 'Seguridad: Media',
        PasswordStrength.strong: 'Seguridad: Fuerte',
        PasswordStrength.veryStrong: 'Seguridad: Muy fuerte',
      };
      for (final entry in etiquetas.entries) {
        await _pump(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget);
      }
    },
  );

  testWidgets('expone un anuncio de accesibilidad con el nivel', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, PasswordStrength.strong);

    expect(
      find.bySemanticsLabel('Seguridad de la contraseña: Fuerte'),
      findsOneWidget,
    );

    handle.dispose();
  });
}
