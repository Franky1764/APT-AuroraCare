import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/shared/memoria_help_dialog.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el tutorial pausa el reloj hasta cerrar el diálogo', (
    tester,
  ) async {
    final events = <String>[];
    final run = GameRun(
      nivel: GameLevel.facil,
      maxDuration: const Duration(minutes: 3),
      elapsed: () => Duration.zero,
      finish: (_) {},
      pauseClock: () => events.add('pausa'),
      resumeClock: () => events.add('reanuda'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMemoriaHelpDialog(
                context: context,
                title: 'Cómo jugar',
                puntos: const ['Busque las parejas.'],
                run: run,
              ),
              child: const Text('Abrir tutorial'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir tutorial'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(events, ['pausa']);
    await tester.tap(find.text('Volver al juego'));
    await tester.pumpAndSettle();
    expect(events, ['pausa', 'reanuda']);
  });
}
