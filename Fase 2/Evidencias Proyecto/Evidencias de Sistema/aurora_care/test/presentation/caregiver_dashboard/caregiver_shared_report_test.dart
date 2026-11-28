import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_shared_report.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/shared_practice_provider.dart';

void main() {
  testWidgets(
    'export is visible initially and revoked link hides an open result',
    (tester) async {
      final links = StreamController<String?>();
      addTearDown(links.close);
      final today = Timestamp.fromDate(DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPracticeLinkProvider.overrideWith((ref) => links.stream),
            sharedPracticeSummaryProvider('link').overrideWith(
              (ref) => Stream.value({
                'publishedAt': today,
                'lastPracticeAt': today,
                'memoria': {
                  'count': 59,
                  'metric': 'accuracy',
                  'value': 75,
                  'trend': 'insufficient',
                  'latestGame': 'memorice_clasico',
                  'latestLevel': 1,
                  'latestAt': today,
                },
              }),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CaregiverSharedReport()),
          ),
        ),
      );
      links.add('link');
      await tester.pumpAndSettle();
      expect(find.text('Guardar PDF').hitTestable(), findsOneWidget);
      expect(find.text('Compartir PDF').hitTestable(), findsOneWidget);
      expect(find.text('75 %'), findsNothing);
      final area = find.widgetWithText(ListTile, 'Memoria');
      await tester.scrollUntilVisible(area, 300);
      await tester.tap(area);
      await tester.pumpAndSettle();
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('Nivel Fácil'), findsOneWidget);
      expect(find.textContaining('Última práctica'), findsWidgets);
      links.add(null);
      await tester.pumpAndSettle();
      expect(find.text('75 %'), findsNothing);
      expect(find.text('Este resumen ya no está disponible.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
