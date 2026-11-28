import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/daily_challenge.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/presentation/challenges/daily_challenge_card.dart';
import 'package:aurora_care/presentation/challenges/daily_challenge_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el calendario abre el resultado del día seleccionado', (
    tester,
  ) async {
    final date = DateTime(2026, 11, 5, 10);
    final session = Session(
      sessionId: 'practice',
      uuid: 'profile',
      domain: 'memoria',
      gameType: 'memorice_clasico',
      nivel: GameLevel.facil,
      startTime: date,
      endTime: date,
      metrics: const MemoriaMetrics(
        errores: 1,
        intentos: 4,
        tiempoSegundos: 30,
        tasaAciertoPct: 75,
      ),
    );
    final progress = DailyChallengeProgress.fromSessions([
      session,
    ], DateTime(2026, 11, 6, 10));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyChallengeProvider.overrideWithValue(progress),
          dailyChallengeSessionsProvider.overrideWithValue([session]),
        ],
        child: const MaterialApp(home: Scaffold(body: DailyChallengeCard())),
      ),
    );
    await tester.tap(find.text('Ver calendario de racha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('5 de noviembre de 2026'), findsOneWidget);
    expect(find.text('1 de 2 partidas'), findsOneWidget);
    expect(find.text('1 práctica registrada'), findsOneWidget);
    expect(find.text('Aciertos registrados: 75 %'), findsNothing);
    await tester.tap(find.text('1 partida'));
    await tester.pumpAndSettle();
    expect(find.text('Partida 1 de 1'), findsOneWidget);
    expect(find.text('Aciertos registrados: 75 %'), findsOneWidget);
  });
}
