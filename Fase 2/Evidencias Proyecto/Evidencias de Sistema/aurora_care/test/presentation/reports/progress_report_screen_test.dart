import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/reports/progress_report_screen.dart';
import 'package:aurora_care/presentation/reports/report_providers.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/domain/entities/progress_report.dart';

void main() {
  testWidgets(
    'historical unscored sessions appear without a fabricated trend',
    (tester) async {
      const summary = ProgressSummary(
        hasProfile: true,
        domains: [
          DomainSummary(domain: 'memoria', sessions: 18, scoredSessions: 0),
          DomainSummary(domain: 'atencion', sessions: 12, scoredSessions: 0),
          DomainSummary(domain: 'praxias', sessions: 61, scoredSessions: 0),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressProvider.overrideWith((ref) async => summary),
            progressReportProvider.overrideWith(
              (ref) async => localProgressReport(reportDomains(summary)),
            ),
          ],
          child: const MaterialApp(home: ProgressReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('18 prácticas · Ver resultados'), findsOneWidget);
      expect(find.text('12 prácticas · Ver resultados'), findsOneWidget);
      expect(find.text('61 prácticas · Ver resultados'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('tendencia de mejora'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
