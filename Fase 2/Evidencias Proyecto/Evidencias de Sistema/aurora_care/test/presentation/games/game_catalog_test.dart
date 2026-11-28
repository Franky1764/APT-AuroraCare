import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/presentation/games/domain_games_screen.dart';
import 'package:aurora_care/presentation/games/game_catalog.dart';

/// Fake mínimo: DomainGamesScreen solo lee `currentUser` para resolver el
/// uid que pasa a "Mis recuerdos"; el resto de FirebaseAuth no se usa en
/// estas pruebas.
class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _withProviders(Widget child) {
  return ProviderScope(
    overrides: [firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth())],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('catálogo de juegos', () {
    test('todos los dominios tienen al menos un juego', () {
      for (final d in GameDomain.values) {
        expect(juegosDeDominio(d), isNotEmpty, reason: d.name);
      }
    });

    test('cada juego está en el dominio que declara (clave interna)', () {
      for (final d in GameDomain.values) {
        for (final j in juegosDeDominio(d)) {
          expect(j.domain, d.key, reason: j.gameType);
        }
      }
    });

    test('no hay dos juegos con el mismo gameType', () {
      final tipos = [
        for (final d in GameDomain.values)
          for (final j in juegosDeDominio(d)) j.gameType,
      ];
      expect(tipos.toSet().length, tipos.length);
    });

    test('están registrados los juegos entregados hasta ahora', () {
      final tipos = {
        for (final d in GameDomain.values)
          for (final j in juegosDeDominio(d)) j.gameType,
      };
      expect(
        tipos,
        containsAll([
          'memorice_clasico',
          'secuencias_colores',
          'trazado_guiado',
          'conecta_puntos',
        ]),
      );
    });

    test('praxias se muestra como Motricidad', () {
      expect(GameDomain.praxias.key, 'praxias');
      expect(GameDomain.praxias.label, 'Motricidad');
    });

    test('dominioPorHomeId reconoce dominios y descarta lo demás', () {
      expect(dominioPorHomeId('memoria'), GameDomain.memoria);
      expect(dominioPorHomeId('atencion'), GameDomain.atencion);
      expect(dominioPorHomeId('praxias'), GameDomain.praxias);
      expect(dominioPorHomeId('respiracion'), isNull);
      expect(dominioPorHomeId('otra_cosa'), isNull);
    });
  });

  group('DomainGamesScreen', () {
    testWidgets('Motricidad lista Trazado guiado y Conecta los puntos', (
      tester,
    ) async {
      await tester.pumpWidget(
        _withProviders(const DomainGamesScreen(domain: GameDomain.praxias)),
      );

      expect(find.text('Motricidad'), findsOneWidget);
      await tester.tap(find.text('Ejercitar mis movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('Trazado guiado'), findsOneWidget);
      expect(find.text('Conecta los puntos'), findsOneWidget);
      expect(find.text('Tocar botones e imágenes'), findsNothing);
    });

    testWidgets('phone practice is separate from general movement exercises', (
      tester,
    ) async {
      await tester.pumpWidget(
        _withProviders(const DomainGamesScreen(domain: GameDomain.praxias)),
      );
      await tester.tap(find.text('Practicar con mi teléfono'));
      await tester.pumpAndSettle();
      expect(find.text('Tocar botones e imágenes'), findsOneWidget);
      expect(find.text('Deslizar entre imágenes'), findsOneWidget);
      expect(find.text('Arrastrar a su lugar'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ampliar una imagen'), 200);
      expect(find.text('Buscar en una lista'), findsOneWidget);
      expect(find.text('Ampliar una imagen'), findsOneWidget);
      expect(find.text('Trazado guiado'), findsNothing);
    });

    testWidgets('Memoria lista Memorice clásico', (tester) async {
      await tester.pumpWidget(
        _withProviders(const DomainGamesScreen(domain: GameDomain.memoria)),
      );

      expect(find.text('Memoria'), findsOneWidget);
      expect(find.text('Memorice clásico'), findsOneWidget);
    });
  });
}
