import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/home/home_screen.dart';

// Tamaño de teléfono para que las 4 tarjetas y el botón sean visibles sin scroll.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('HomeScreen renderiza saludo, dominios y botón de progreso', (
    WidgetTester tester,
  ) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          userName: 'Rosa',
          onGameSelected: (_) {},
          onViewProgress: () {},
          onAvatarTap: () {},
        ),
      ),
    );

    expect(find.text('Hola, Rosa 🌿'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('Memoria'), findsOneWidget);
    expect(find.text('Atención'), findsOneWidget);
    expect(find.text('Motricidad'), findsOneWidget);
    expect(find.text('Respiración'), findsOneWidget);
    expect(find.text('Ver mi progreso'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('tocar cada tarjeta dispara onGameSelected con su id', (
    WidgetTester tester,
  ) async {
    _usePhoneSize(tester);
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          userName: 'Rosa',
          onGameSelected: selected.add,
          onViewProgress: () {},
          onAvatarTap: () {},
        ),
      ),
    );

    await tester.tap(find.text('Memoria'));
    await tester.tap(find.text('Atención'));
    await tester.tap(find.text('Motricidad'));
    await tester.tap(find.text('Respiración'));

    expect(selected, ['memoria', 'atencion', 'praxias', 'respiracion']);
  });

  testWidgets('el botón de progreso y el avatar disparan sus callbacks', (
    WidgetTester tester,
  ) async {
    _usePhoneSize(tester);
    var progressTapped = false;
    var avatarTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          userName: 'Rosa',
          onGameSelected: (_) {},
          onViewProgress: () => progressTapped = true,
          onAvatarTap: () => avatarTapped = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.ensureVisible(find.text('Ver mi progreso'));
    await tester.tap(find.text('Ver mi progreso'));

    expect(progressTapped, isTrue);
    expect(avatarTapped, isTrue);
  });
}
