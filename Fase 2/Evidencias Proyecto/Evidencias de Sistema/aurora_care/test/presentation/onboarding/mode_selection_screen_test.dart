import 'package:aurora_care/presentation/shared/usage_mode_exceptions.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aurora_care/domain/exceptions/caregiver_revocation_unavailable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/presentation/onboarding/mode_selection_screen.dart';

bool _isHighlighted(WidgetTester tester, int mode) {
  final card = tester.widget<Card>(
    find.descendant(
      of: find.byKey(ValueKey('mode_card_$mode')),
      matching: find.byType(Card),
    ),
  );
  final side = (card.shape as RoundedRectangleBorder).side;
  return side.color == AppColors.primary && side.width == 3;
}

Finder _currentBadgeFor(int mode) => find.descendant(
  of: find.byKey(ValueKey('mode_card_$mode')),
  matching: find.text('Modo actual'),
);

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  testWidgets('ModeSelectionScreen renderiza solo los 2 títulos que quedan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ModeSelectionScreen(userName: 'Rosa')));

    expect(find.text('Solo jugar'), findsNothing);
    expect(find.text('Jugar y ver mi progreso'), findsOneWidget);
    expect(
      find.text('Jugar, ver mi progreso y conectar con un cuidador'),
      findsOneWidget,
    );
  });

  testWidgets('el Modo 1 (Solo jugar) ya no existe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ModeSelectionScreen(userName: 'Rosa')));

    expect(find.text('Solo jugar'), findsNothing);
    expect(find.byKey(const ValueKey('mode_card_1')), findsNothing);
  });

  testWidgets(
    'sin initialMode, el Modo 2 aparece resaltado por defecto (onboarding)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const ModeSelectionScreen(userName: 'Rosa')),
      );

      expect(_isHighlighted(tester, 2), isTrue);
      expect(_isHighlighted(tester, 3), isFalse);
    },
  );

  testWidgets('tocar cada tarjeta dispara onModeSelected con su número', (
    WidgetTester tester,
  ) async {
    final selected = <int>[];

    await tester.pumpWidget(
      _wrap(
        ModeSelectionScreen(
          userName: 'Rosa',
          onModeSelected: (mode) async => selected.add(mode),
        ),
      ),
    );

    await tester.tap(find.text('Jugar y ver mi progreso'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Jugar, ver mi progreso y conectar con un cuidador'),
    );
    await tester.pumpAndSettle();

    expect(selected, [2, 3]);
    expect(_isHighlighted(tester, 3), isTrue);
    expect(_isHighlighted(tester, 2), isFalse);
  });

  testWidgets('sin guardado conectado muestra error y conserva el modo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ModeSelectionScreen(
          userName: 'Rosa',
          initialMode: 2,
          isChangeMode: true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mode_card_3')));
    await tester.pumpAndSettle();
    expect(_isHighlighted(tester, 2), isTrue);
    expect(find.text('Su modo fue actualizado.'), findsNothing);
    expect(
      find.text(
        'No se pudo guardar su modo. Su progreso se conserva. Intente de nuevo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'muestra el banner de error y Reintentar cuando onModeSelected falla',
    (WidgetTester tester) async {
      var calls = 0;

      await tester.pumpWidget(
        _wrap(
          ModeSelectionScreen(
            userName: 'Rosa',
            onModeSelected: (mode) async {
              calls++;
              throw Exception('fallo simulado');
            },
          ),
        ),
      );

      await tester.tap(find.text('Jugar y ver mi progreso'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo guardar su modo. Su progreso se conserva. Intente de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Reintentar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(calls, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  testWidgets('initialMode: 3 muestra esa tarjeta resaltada al construir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ModeSelectionScreen(userName: 'Rosa', initialMode: 3)),
    );

    expect(_isHighlighted(tester, 3), isTrue);
    expect(_isHighlighted(tester, 2), isFalse);
  });

  testWidgets(
    'isChangeMode: true muestra el título "Mi modo de uso", la etiqueta '
    '"Modo actual" y oculta el pie de onboarding',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const ModeSelectionScreen(
            userName: 'Rosa',
            isChangeMode: true,
            initialMode: 3,
          ),
        ),
      );

      expect(find.text('Mi modo de uso'), findsOneWidget);
      expect(find.text('¿Cómo quiere usar la app?'), findsNothing);
      expect(_currentBadgeFor(3), findsOneWidget);
      expect(_currentBadgeFor(2), findsNothing);
      expect(find.text('Puede cambiar esto cuando quiera.'), findsNothing);
    },
  );

  testWidgets(
    'isChangeMode: true, bajar de 3 a 2 muestra el aviso y Cancelar no '
    'cambia nada',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const ModeSelectionScreen(
            userName: 'Rosa',
            isChangeMode: true,
            initialMode: 3,
          ),
        ),
      );

      await tester.tap(find.text('Jugar y ver mi progreso'));
      await tester.pumpAndSettle();

      expect(find.text('¿Volver al modo personal?'), findsOneWidget);
      expect(
        find.text(
          'Conservará todas sus partidas y su progreso. Se cancelará cualquier invitación pendiente. ',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Volver al modo personal?'), findsNothing);
      expect(_isHighlighted(tester, 3), isTrue);
      expect(_isHighlighted(tester, 2), isFalse);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'modo confirmado muestra seguimiento pendiente y permite reintentar',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          ModeSelectionScreen(
            userName: 'Rosa',
            initialMode: 2,
            isChangeMode: true,
            onModeSelected: (_) async {
              calls++;
              if (calls == 1) throw const UsageModeProfilePending(3);
            },
          ),
        ),
      );
      await tester.tap(
        find.text('Jugar, ver mi progreso y conectar con un cuidador'),
      );
      await tester.pumpAndSettle();
      expect(_isHighlighted(tester, 3), isTrue);
      expect(find.text('Su modo fue actualizado.'), findsNothing);
      expect(
        find.textContaining('Falta cargar su seguimiento'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('Falta cargar su seguimiento'), findsNothing);
      expect(find.text('Su modo fue actualizado.'), findsOneWidget);
    },
  );

  testWidgets('informa revocación confirmada sin cambiar la selección', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ModeSelectionScreen(
          userName: 'Rosa',
          initialMode: 3,
          isChangeMode: true,
          onModeSelected: (_) async =>
              throw const UsageModeSaveAfterRevocationFailed(),
        ),
      ),
    );
    await tester.tap(find.text('Jugar y ver mi progreso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cambiar'));
    await tester.pumpAndSettle();
    expect(_isHighlighted(tester, 3), isTrue);
    expect(find.textContaining('anteriores fueron retirados'), findsOneWidget);
    expect(find.text('Su modo fue actualizado.'), findsNothing);
  });

  testWidgets('sin revocación conserva el modo y no confirma el cambio', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ModeSelectionScreen(
          userName: 'Rosa',
          initialMode: 3,
          isChangeMode: true,
          onModeSelected: (_) async =>
              throw const CaregiverRevocationUnavailable(),
        ),
      ),
    );
    await tester.tap(find.text('Jugar y ver mi progreso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cambiar'));
    await tester.pumpAndSettle();
    expect(_isHighlighted(tester, 3), isTrue);
    expect(_currentBadgeFor(3), findsOneWidget);
    expect(find.text('Su modo fue actualizado.'), findsNothing);
    expect(
      find.text(
        'Por ahora no podemos confirmar la desvinculación del cuidador. Su modo actual se mantiene.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'isChangeMode: true, subir de 2 a 3 no muestra aviso y cambia directo',
    (WidgetTester tester) async {
      final saved = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          ModeSelectionScreen(
            userName: 'Rosa',
            onModeSelected: (_) => saved.future,
            isChangeMode: true,
            initialMode: 2,
          ),
        ),
      );

      await tester.tap(
        find.text('Jugar, ver mi progreso y conectar con un cuidador'),
      );
      await tester.pump();

      expect(find.text('¿Volver al modo personal?'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(_isHighlighted(tester, 2), isTrue);
      expect(find.text('Su modo fue actualizado.'), findsNothing);
      saved.complete();
      await tester.pump();
      await tester.pump();

      expect(_isHighlighted(tester, 3), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Su modo fue actualizado.'), findsOneWidget);
    },
  );

  testWidgets('isChangeMode: true, tocar el modo ya activo no hace nada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ModeSelectionScreen(
          userName: 'Rosa',
          isChangeMode: true,
          initialMode: 3,
        ),
      ),
    );

    await tester.tap(
      find.text('Jugar, ver mi progreso y conectar con un cuidador'),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Volver al modo personal?'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
