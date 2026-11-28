import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/presentation/reports/practice_report_summary.dart';
import 'package:aurora_care/presentation/reports/report_area_details.dart';

void main() {
  testWidgets(
    'shows only selected level with a plain label and preserves values',
    (tester) async {
      final now = DateTime(2026, 11, 27);
      final summary = summarizeProgress(
        [
          for (final level in [GameLevel.facil, GameLevel.avanzado])
            Session(
              sessionId: level.name,
              uuid: 'profile',
              domain: 'memoria',
              gameType: 'memorice_clasico',
              nivel: level,
              startTime: now,
              endTime: now,
              metrics: MemoriaMetrics(
                errores: 0,
                intentos: 5,
                tiempoSegundos: 60,
                tasaAciertoPct: level == GameLevel.facil ? 80 : 60,
              ),
            ),
        ],
        uuid: 'profile',
        now: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showReportAreaDetails(
                  context,
                  PracticeReportSummary(summary, now),
                  summary.domains.first,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Respuestas correctas'), findsOneWidget);
      expect(find.text('80,0 %'), findsOneWidget);
      expect(find.text('60,0 %'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Avanzado'));
      await tester.pumpAndSettle();
      expect(find.text('60,0 %'), findsOneWidget);
      expect(find.text('80,0 %'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar resultados'));
      await tester.pumpAndSettle();
      expect(find.text('Respuestas correctas'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
