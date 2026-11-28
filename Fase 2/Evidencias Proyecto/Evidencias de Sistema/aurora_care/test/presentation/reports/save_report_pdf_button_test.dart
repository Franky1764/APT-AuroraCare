import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/reports/save_report_pdf_button.dart';

void main() {
  testWidgets('save and share send current summary and three activity bars', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('auroracare/report_pdf');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SaveReportPdfButton(
            text: 'Resumen con observaciones',
            sections: [
              {
                'title': 'Memoria',
                'rows': [
                  {
                    'game': 'Memorice',
                    'level': 'Fácil',
                    'count': '1',
                    'results': '80 %',
                  },
                ],
              },
            ],
            activity: {'Memoria': 1, 'Atención': 0, 'Motricidad': 2},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guardar PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartir PDF'));
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.method), ['save', 'share']);
    for (final call in calls) {
      expect(call.arguments['sections'].first['title'], 'Memoria');
      expect(call.arguments['text'], 'Resumen con observaciones');
      expect(call.arguments['activity'], {
        'Memoria': 1,
        'Atención': 0,
        'Motricidad': 2,
      });
    }
  });
}
