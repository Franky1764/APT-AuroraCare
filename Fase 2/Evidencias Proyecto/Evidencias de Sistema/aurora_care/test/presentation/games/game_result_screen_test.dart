import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/shared/game_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('return home closes all intermediate practice screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('Inicio de prueba')),
      ),
    );
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (final title in [
      'Motricidad',
      'Practicar con mi teléfono',
      'Elegir práctica',
    ]) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(title))),
      );
      await tester.pumpAndSettle();
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const GameResultScreen(
          title: 'Tocar botones e imágenes',
          nivel: GameLevel.facil,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Volver al inicio'));
    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio de prueba'), findsOneWidget);
    expect(navigator.canPop(), isFalse);
  });
  testWidgets(
    'attention card uses seconds and explains its average inside the modal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const GameResultScreen(
            title: 'Contador de objetos',
            nivel: GameLevel.facil,
            gameType: 'contador_objetos',
            metrics: AtencionMetrics(
              tiempoRespuestaMs: 1628,
              tasaErrorPct: 0,
              alcance: 3,
            ),
          ),
        ),
      );
      expect(
        find.text('Tiempo promedio para responder: 1,6 segundos'),
        findsOneWidget,
      );
      expect(find.textContaining('opciones de respuesta'), findsNothing);
      await tester.ensureVisible(find.text('Ver detalle'));
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('opciones de respuesta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'raw tracing result is available without scoring or history on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const GameResultScreen(
              title: 'Trazado guiado',
              nivel: GameLevel.facil,
              gameType: 'trazado_guiado',
              recorded: true,
              metrics: PraxiasMetrics(
                precisionPct: 87,
                correcciones: 0,
                tiempoSegundos: 10,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Precisión del recorrido: 87 %'), findsOneWidget);
      expect(find.textContaining('puntuación calibrada'), findsOneWidget);
      expect(find.textContaining('Mi progreso'), findsOneWidget);
      expect(find.textContaining('Su análisis está pendiente'), findsNothing);
      expect(find.textContaining('Una partida por sí sola'), findsNothing);
      await tester.ensureVisible(find.text('Ver detalle'));
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Una partida por sí sola'), findsOneWidget);
      await tester.ensureVisible(find.text('Cerrar detalle'));
      await tester.tap(find.text('Cerrar detalle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('Volver al inicio'));
      expect(tester.takeException(), isNull);
    },
  );
}
