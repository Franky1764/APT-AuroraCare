import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/progress/progress_screen.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Future<ProgressSummary> Function() load,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressProvider.overrideWith((ref) => load())],
        child: const MaterialApp(home: ProgressScreen(userName: 'Carla')),
      ),
    );
  }

  testWidgets('loading, error and retry', (tester) async {
    final pending = Completer<ProgressSummary>();
    var calls = 0;
    await show(tester, () {
      calls++;
      return calls == 1
          ? pending.future
          : Future.value(const ProgressSummary(hasProfile: false));
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tu progreso.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
      find.text('No hay un perfil activo para consultar el progreso.'),
      findsOneWidget,
    );
  });
  testWidgets('empty sessions and domain states without demo data', (
    tester,
  ) async {
    await show(
      tester,
      () async => summarizeProgress([], uuid: 'p', now: DateTime(2026)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'No hay sesiones registradas en los últimos 28 días.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sin sesiones recientes'), findsNWidgets(3));
    for (final name in ['Memoria', 'Atención', 'Motricidad']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Muy bien esta semana'), findsNothing);
  });
  testWidgets('real counts and pending metrics without numeric scores', (
    tester,
  ) async {
    await show(
      tester,
      () async => const ProgressSummary(
        hasProfile: true,
        domains: [
          DomainSummary(domain: 'memoria', sessions: 3, scoredSessions: 0),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 sesiones registradas'), findsOneWidget);
    expect(find.text('Seguimiento inicial'), findsOneWidget);
  });
  testWidgets(
    'latest raw tracing metrics remain visible without a calibrated score',
    (tester) async {
      final date = DateTime(2026, 10, 30);
      await show(
        tester,
        () async => summarizeProgress(
          [
            Session(
              sessionId: 's1',
              uuid: 'p',
              domain: 'praxias',
              gameType: 'trazado_guiado',
              nivel: GameLevel.facil,
              startTime: date,
              endTime: date,
              metrics: const PraxiasMetrics(
                precisionPct: 91,
                correcciones: 0,
                tiempoSegundos: 10,
              ),
            ),
          ],
          uuid: 'p',
          now: date,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Última partida · Precisión del recorrido: 91 %'),
        findsOneWidget,
      );
      expect(find.text('Última partida'), findsNothing);
      expect(
        find.textContaining('Aún no hay puntuaciones calibradas'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Motricidad'));
      await tester.tap(find.text('Motricidad'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Precisión del recorrido: 91 %'), findsOneWidget);
      expect(find.text('Última partida'), findsOneWidget);
      expect(
        find.textContaining('Trazado guiado · 30/10/2026'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aún no hay puntuaciones calibradas'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cerrar detalle'));
      await tester.tap(find.text('Cerrar detalle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('injected UI requires no Firebase and report callback works', (
    tester,
  ) async {
    var called = false;
    const progress = DomainProgress(
      domain: 'Memoria',
      icon: Icons.spa,
      color: Colors.blue,
      statusText: 'Rendimiento estable',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProgressScreen(
            userName: 'Carla',
            memory: progress,
            attention: progress,
            motorSkills: progress,
            onGenerateReport: () => called = true,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Generar reporte de mi progreso'));
    await tester.tap(find.text('Generar reporte de mi progreso'));
    expect(called, true);
  });
  testWidgets(
    'unassigned legacy history stays out of the progress screen',
    (tester) async {
      await show(
        tester,
        () async =>
            const ProgressSummary(hasProfile: true, hasUnassignedHistory: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sobre las partidas anteriores'), findsNothing);
      expect(find.textContaining('legacy-private-profile'), findsNothing);
    },
  );
}
