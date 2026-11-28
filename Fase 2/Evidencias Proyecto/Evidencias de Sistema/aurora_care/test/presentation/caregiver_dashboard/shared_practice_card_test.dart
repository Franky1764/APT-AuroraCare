import 'package:aurora_care/presentation/caregiver_dashboard/shared_practice_card.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/shared_practice_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'muestra actividad y resultado desde una práctica sin tendencia',
    (tester) async {
      final today = Timestamp.fromDate(DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPracticeLinkProvider.overrideWith(
              (ref) => Stream.value('link'),
            ),
            sharedPracticeSummaryProvider('link').overrideWith(
              (ref) => Stream.value({
                'lastPracticeAt': today,
                'publishedAt': today,
                'memoria': {
                  'count': 1,
                  'metric': 'accuracy',
                  'value': 75,
                  'trend': 'insufficient',
                },
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: SharedPracticeCard(onOpenReport: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Practicó hoy.'), findsOneWidget);
      expect(
        find.text('Última práctica · Aciertos registrados: 75 %'),
        findsOneWidget,
      );
      expect(find.textContaining('Seguimiento inicial'), findsOneWidget);
      expect(find.text('Ver reporte'), findsOneWidget);
    },
  );
}
