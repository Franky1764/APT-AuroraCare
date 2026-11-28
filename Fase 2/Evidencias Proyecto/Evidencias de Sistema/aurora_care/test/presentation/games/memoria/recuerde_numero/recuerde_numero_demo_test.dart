import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_demo.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size tamanio = const Size(360, 640),
  double textScale = 1.0,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = tamanio;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: const MaterialApp(
        home: Scaffold(body: Center(child: RecuerdeNumeroDemo())),
      ),
    ),
  );
}

void main() {
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    testWidgets(
      'en ${tamanio.width.toInt()}x${tamanio.height.toInt()}: se '
      'construye sin overflow',
      (tester) async {
        await _pump(tester, tamanio: tamanio);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('con textScale 1,3 no hay overflow', (tester) async {
    await _pump(tester, textScale: 1.3);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'con disableAnimations activo, se construye sin overflow y no '
    'anima (no hay ningún Timer/ticker pendiente)',
    (tester) async {
      await _pump(tester, disableAnimations: true);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la animación avanza con el tiempo cuando disableAnimations está '
    'apagado (recorre todo un ciclo sin overflow)',
    (tester) async {
      await _pump(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(tester.takeException(), isNull);
      // Pasa de largo un ciclo completo (5 s) para confirmar que
      // reinicia el bucle sin errores.
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tiene una única descripción accesible de la demo (la animación '
    'decorativa no se lee por separado)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp('un número de 3 dígitos')),
        findsOneWidget,
      );

      handle.dispose();
    },
  );
}
