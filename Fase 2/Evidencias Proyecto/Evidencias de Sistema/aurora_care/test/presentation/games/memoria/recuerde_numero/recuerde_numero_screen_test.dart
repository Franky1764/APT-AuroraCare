import 'package:flutter/rendering.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_controller.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_demo.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_keypad.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/shared/status_banner.dart';

/// soundsEnabledProvider es un NotifierProvider: no tiene overrideWithValue.
/// Sin esto, necesitaría sharedPreferencesProvider (que lanza si no se
/// sobreescribe) en cada test que confirme una ronda, aunque no le
/// importe el sonido — este fija el valor sin tocar prefs.
class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

GameRun _fakeRun(GameLevel nivel, {void Function(CognitiveMetrics)? onFinish}) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 240),
    elapsed: () => Duration.zero,
    finish: onFinish ?? (_) {},
  );
}

/// Espera a que el controller llegue a [fase]. Usa un listener de
/// Riverpod (no una duración fija a ciegas) para saber EXACTAMENTE
/// cuándo se alcanzó — los Timers del controller son reales, así que
/// de todos modos hace falta "pump" para que el reloj falso avance,
/// pero la condición de salida es el propio estado, no un número de
/// milisegundos adivinado.
Future<void> _esperarFase(
  WidgetTester tester,
  ProviderContainer container,
  ProviderListenable<RecuerdeNumeroState> provider,
  RecuerdeNumeroFase fase,
) async {
  if (container.read(provider).fase == fase) return;
  final completer = Completer<void>();
  final sub = container.listen(provider, (_, next) {
    if (next.fase == fase && !completer.isCompleted) completer.complete();
  });
  var intentos = 0;
  while (!completer.isCompleted) {
    await tester.pump(const Duration(milliseconds: 20));
    intentos++;
    if (intentos > 500) {
      fail('No se alcanzó la fase $fase a tiempo');
    }
  }
  sub.close();
}

/// Overrides que aceleran los temporizadores del controller para que
/// las pruebas no dependan de esperar los 3-5 s reales de "mostrando".
List<Override> _overridesRapidos() => [
  recuerdeNumeroTiempoVisualizacionProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  recuerdeNumeroFeedbackDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
  soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
];

void main() {
  const tamanios = [Size(360, 640), Size(360, 800)];

  for (final nivel in GameLevel.values) {
    for (final tamanio in tamanios) {
      testWidgets('nivel ${nivel.label} en ${tamanio.width.toInt()}x'
          '${tamanio.height.toInt()}: sin overflow en ambas fases, con el '
          'mismo tamaño de la zona inferior', (tester) async {
        tester.view.physicalSize = tamanio;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(),
                body: RecuerdeNumeroScreen(run: _fakeRun(nivel)),
              ),
            ),
          ),
        );

        // Fase "mostrando" (estado inicial).
        expect(tester.takeException(), isNull);
        final expandedMostrando = tester.getRect(find.byType(Expanded));

        // Fase "esperandoRespuesta": el teclado debe caber sin overflow,
        // con teclas de al menos 48dp.
        await tester.pump(const Duration(seconds: 10));
        expect(tester.takeException(), isNull);

        final expandedEsperando = tester.getRect(find.byType(Expanded));
        expect(
          expandedEsperando,
          expandedMostrando,
          reason: 'la zona inferior cambió de tamaño entre fases',
        );

        expect(find.byType(RecuerdeNumeroKeypad), findsOneWidget);
        final teclaUno = find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text('1'),
        );
        // El contenedor de la tecla (no el texto) es el que debe medir
        // >=48dp; se verifica a través del SizedBox padre.
        final teclaBox = tester.getSize(
          find.ancestor(of: teclaUno, matching: find.byType(SizedBox)).first,
        );
        expect(teclaBox.width, greaterThanOrEqualTo(48));
        expect(teclaBox.height, greaterThanOrEqualTo(48));
      });
    }
  }

  testWidgets('con textScale 1.3 no hay overflow en ninguna fase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.avanzado)),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'escribir el número correcto y confirmar suma a rondasCorrectas',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 10));

      final numero = container.read(provider).numero;
      for (final c in numero.split('')) {
        // Acotado al teclado: los casilleros de arriba también muestran
        // el dígito como texto una vez escrito, y podrían confundirse
        // con la tecla.
        await tester.tap(
          find.descendant(
            of: find.byType(RecuerdeNumeroKeypad),
            matching: find.text(c),
          ),
        );
        await tester.pump();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text('Listo'),
        ),
      );
      await tester.pump();

      final state = container.read(provider);
      expect(state.ultimaRondaCorrecta, isTrue);
      expect(state.rondasCorrectas, 1);

      // El juego sigue (1 de 5 aciertos): queda un Timer pendiente para
      // la ronda nueva. Se cancela explícitamente (dispose es idempotente)
      // para que la verificación de invariantes del binding no falle al
      // terminar el test con un Timer todavía activo.
      container.dispose();
    },
  );

  testWidgets(
    'estado inicial ("mostrando"): no aparece ningún ícono de acierto '
    'ni de error',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      expect(find.byType(StatusBanner), findsNothing);
    },
  );

  testWidgets('al acertar la ronda, el banner de retroalimentación muestra el '
      'check verde con "¡Correcto!"', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: _overridesRapidos());
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
          ),
        ),
      ),
    );

    await _esperarFase(
      tester,
      container,
      provider,
      RecuerdeNumeroFase.esperandoRespuesta,
    );
    expect(find.byType(StatusBanner), findsNothing);

    final numero = container.read(provider).numero;
    for (final c in numero.split('')) {
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text(c),
        ),
      );
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(RecuerdeNumeroKeypad),
        matching: find.text('Listo'),
      ),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(StatusBanner),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.check_circle_outline_rounded);
    expect(icon.color, AppColors.success);
    expect(tester.getSemantics(find.byType(StatusBanner)).label, '¡Correcto!');

    // El juego sigue: queda un Timer pendiente para la ronda nueva
    // (ver el mismo comentario en el test de "rondasCorrectas").
    container.dispose();
    handle.dispose();
  });

  testWidgets('al fallar la ronda, el banner de retroalimentación muestra la '
      'equis roja con el mensaje completo (el número correcto incluido)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: _overridesRapidos());
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.avanzado);
    container.listen(provider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.avanzado)),
          ),
        ),
      ),
    );

    await _esperarFase(
      tester,
      container,
      provider,
      RecuerdeNumeroFase.esperandoRespuesta,
    );

    final numeroCorrecto = container.read(provider).numero;
    final primerDigito = int.parse(numeroCorrecto[0]);
    final otroDigito = (primerDigito + 1) % 10 == 0
        ? 1
        : (primerDigito + 1) % 10;
    await tester.tap(
      find.descendant(
        of: find.byType(RecuerdeNumeroKeypad),
        matching: find.text('$otroDigito'),
      ),
    );
    await tester.pump();
    for (var i = 1; i < numeroCorrecto.length; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text(numeroCorrecto[i]),
        ),
      );
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(RecuerdeNumeroKeypad),
        matching: find.text('Listo'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(StatusBanner),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.cancel_outlined);
    expect(icon.color, AppColors.error);
    expect(
      tester.getSemantics(find.byType(StatusBanner)).label,
      'No importa, siga intentando. El número era $numeroCorrecto.',
    );

    // El juego sigue: queda un Timer pendiente para la ronda nueva
    // (ver el mismo comentario en el test de "rondasCorrectas").
    container.dispose();
    handle.dispose();
  });

  testWidgets('el aviso de error puede crecer con el texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: _overridesRapidos());
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.avanzado);
    container.listen(provider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(),
            body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.avanzado)),
          ),
        ),
      ),
    );

    final alturaMostrando = tester
        .getSize(find.byKey(const ValueKey('recuerde_numero_mensaje')))
        .height;

    await _esperarFase(
      tester,
      container,
      provider,
      RecuerdeNumeroFase.esperandoRespuesta,
    );
    final alturaEsperando = tester
        .getSize(find.byKey(const ValueKey('recuerde_numero_mensaje')))
        .height;
    expect(alturaEsperando, alturaMostrando);

    // Falla a propósito: banner de error (el más largo de los dos).
    final numeroCorrecto = container.read(provider).numero;
    final primerDigito = int.parse(numeroCorrecto[0]);
    final otroDigito = (primerDigito + 1) % 10 == 0
        ? 1
        : (primerDigito + 1) % 10;
    await tester.tap(
      find.descendant(
        of: find.byType(RecuerdeNumeroKeypad),
        matching: find.text('$otroDigito'),
      ),
    );
    await tester.pump();
    for (var i = 1; i < numeroCorrecto.length; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text(numeroCorrecto[i]),
        ),
      );
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(RecuerdeNumeroKeypad),
        matching: find.text('Listo'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final alturaError = tester
        .getSize(find.byKey(const ValueKey('recuerde_numero_mensaje')))
        .height;
    expect(alturaError, greaterThanOrEqualTo(alturaMostrando));
    final message = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(StatusBanner),
        matching: find.byType(Text),
      ),
    );
    expect(
      message.size.height,
      greaterThanOrEqualTo(message.getMaxIntrinsicHeight(message.size.width)),
    );

    // El juego sigue: queda un Timer pendiente para la ronda nueva
    // (ver el mismo comentario en el test de "rondasCorrectas").
    container.dispose();
  });

  testWidgets(
    'nivel Avanzado en 360x640: el banner de error con el número de 5 '
    'dígitos no provoca overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: _overridesRapidos());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.avanzado);
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.avanzado)),
            ),
          ),
        ),
      );

      await _esperarFase(
        tester,
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );

      final numeroCorrecto = container.read(provider).numero;
      final primerDigito = int.parse(numeroCorrecto[0]);
      final otroDigito = (primerDigito + 1) % 10 == 0
          ? 1
          : (primerDigito + 1) % 10;
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text('$otroDigito'),
        ),
      );
      await tester.pump();
      for (var i = 1; i < numeroCorrecto.length; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(RecuerdeNumeroKeypad),
            matching: find.text(numeroCorrecto[i]),
          ),
        );
        await tester.pump();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text('Listo'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusBanner), findsOneWidget);

      // El juego sigue: queda un Timer pendiente para la ronda nueva
      // (ver el mismo comentario en el test de "rondasCorrectas").
      container.dispose();
    },
  );

  testWidgets(
    '"Ver cómo se juega" se muestra en la ronda 1, abre el diálogo con '
    'la demo, y "Volver al juego" lo cierra sin cambiar el puntaje ni '
    'el tiempo de la partida',
    (tester) async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          recuerdeNumeroClockProvider.overrideWithValue(() => ahora),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      expect(find.text('Ver cómo se juega'), findsOneWidget);
      final estadoAntes = container.read(provider);

      // No se usa pumpAndSettle: la demo dentro del diálogo anima en
      // bucle. Se pumpean solo ~300 ms, bien por debajo de los 3000 ms
      // de "mostrando" de Fácil.
      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.byType(RecuerdeNumeroDemo), findsOneWidget);
      expect(
        find.text('Memorice el número antes de que desaparezca.'),
        findsOneWidget,
      );

      ahora = ahora.add(const Duration(seconds: 30));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al juego'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsNothing);
      final estadoDespues = container.read(provider);
      // La pantalla pausa el controlador al abrir el diálogo y lo
      // reanuda al cerrarlo: nada puntuable cambió, Y los 30 s no
      // deben contar en tiempoSegundos (se verifica más abajo).
      expect(estadoDespues.rondasJugadas, estadoAntes.rondasJugadas);
      expect(estadoDespues.rondasCorrectas, estadoAntes.rondasCorrectas);
      expect(estadoDespues.rondasConError, estadoAntes.rondasConError);
      expect(estadoDespues.metrics, isNull);
      expect(find.text('Ver cómo se juega'), findsOneWidget);
      // reanudar() reinicia el tiempo de visualización completo: no se
      // perdió la ronda por haber pausado a mitad de "mostrando".
      expect(estadoDespues.fase, RecuerdeNumeroFase.mostrando);

      // Deja que se muestre el número completo de nuevo y termina la
      // partida: tiempoSegundos debe reflejar solo el tiempo jugado
      // después de reanudar, sin los 30 s pausados.
      ahora = ahora.add(const Duration(seconds: 7));
      for (var ronda = 0; ronda < 5; ronda++) {
        await _esperarFase(
          tester,
          container,
          provider,
          RecuerdeNumeroFase.esperandoRespuesta,
        );
        final numero = container.read(provider).numero;
        for (final c in numero.split('')) {
          await tester.tap(
            find.descendant(
              of: find.byType(RecuerdeNumeroKeypad),
              matching: find.text(c),
            ),
          );
          await tester.pump();
        }
        await tester.tap(
          find.descendant(
            of: find.byType(RecuerdeNumeroKeypad),
            matching: find.text('Listo'),
          ),
        );
        await tester.pump();
      }
      expect(container.read(provider).metrics!.tiempoSegundos, 7);
    },
  );

  testWidgets(
    'cerrar el diálogo con el botón atrás también reanuda (no queda '
    'pausado para siempre)',
    (tester) async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          recuerdeNumeroClockProvider.overrideWithValue(() => ahora),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Cómo jugar'), findsOneWidget);

      ahora = ahora.add(const Duration(seconds: 30));

      await tester.binding.handlePopRoute();
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Cómo jugar'), findsNothing);
      expect(container.read(provider).fase, RecuerdeNumeroFase.mostrando);

      container.dispose();
    },
  );

  testWidgets(
    '"Ver cómo se juega" desaparece al resolver la ronda 1 (acierto o '
    'error) y no vuelve a aparecer en rondas posteriores',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: _overridesRapidos());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      expect(find.text('Ver cómo se juega'), findsOneWidget);

      await _esperarFase(
        tester,
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );
      expect(find.text('Ver cómo se juega'), findsOneWidget);

      final numero = container.read(provider).numero;
      for (final c in numero.split('')) {
        await tester.tap(
          find.descendant(
            of: find.byType(RecuerdeNumeroKeypad),
            matching: find.text(c),
          ),
        );
        await tester.pump();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(RecuerdeNumeroKeypad),
          matching: find.text('Listo'),
        ),
      );
      await tester.pump();

      expect(find.text('Ver cómo se juega'), findsNothing);

      // Retroalimentación + nueva ronda: tampoco reaparece.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Ver cómo se juega'), findsNothing);

      container.dispose();
    },
  );

  testWidgets(
    'el tamaño de la zona inferior (número/teclado) en Avanzado no '
    'cambia antes y después de resolver la ronda 1, ni se mueve el '
    'número ni el teclado (la franja del botón no cambia de alto)',
    (tester) async {
      for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
        tester.view.physicalSize = tamanio;
        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer(overrides: _overridesRapidos());
        final provider = recuerdeNumeroControllerProvider(GameLevel.avanzado);
        container.listen(provider, (_, _) {});

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(),
                body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.avanzado)),
              ),
            ),
          ),
        );

        // .last, no el finder desnudo: StatusBanner (lib/presentation/
        // games/shared/status_banner.dart, no se toca) también usa un
        // Expanded propio para su texto, y aparece un segundo Expanded
        // en el árbol en cuanto se muestra el banner de retroalimentación.
        // El de esta pantalla (número/teclado) es el último en el orden
        // de recorrido, porque va después del área de mensaje en la Column.
        final expandedAntes = tester.getRect(find.byType(Expanded).last);
        final mensajeAntes = tester.getRect(
          find.byKey(const ValueKey('recuerde_numero_mensaje')),
        );

        await _esperarFase(
          tester,
          container,
          provider,
          RecuerdeNumeroFase.esperandoRespuesta,
        );
        final numeroCorrecto = container.read(provider).numero;
        for (final c in numeroCorrecto.split('')) {
          await tester.tap(
            find.descendant(
              of: find.byType(RecuerdeNumeroKeypad),
              matching: find.text(c),
            ),
          );
          await tester.pump();
        }
        await tester.tap(
          find.descendant(
            of: find.byType(RecuerdeNumeroKeypad),
            matching: find.text('Listo'),
          ),
        );
        await tester.pump();

        final expandedDespues = tester.getRect(find.byType(Expanded).last);
        final mensajeDespues = tester.getRect(
          find.byKey(const ValueKey('recuerde_numero_mensaje')),
        );

        expect(
          expandedDespues,
          expandedAntes,
          reason:
              'la zona del número/teclado se movió o cambió de tamaño '
              'al resolver la ronda 1 en '
              '${tamanio.width.toInt()}x${tamanio.height.toInt()}',
        );
        expect(
          mensajeDespues,
          mensajeAntes,
          reason:
              'el área de mensaje (52dp) se movió al resolver la ronda 1 '
              'en ${tamanio.width.toInt()}x${tamanio.height.toInt()}',
        );

        tester.view.reset();
        container.dispose();
      }
    },
  );

  // Auditoría: el mensaje de retroalimentación usa ConstrainedBox(
  // minHeight: _mensajeAlturaMinima), no una altura fija — puede
  // crecer, no recortar. Se confirma con Rects, en los 2 anchos y las
  // 2 escalas de texto, con el mensaje de error más largo (número de
  // 5 dígitos en Avanzado).
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'auditoría en ${tamanio.width.toInt()}x${tamanio.height.toInt()} '
        'con textScale $textScale: el banner de error (número de 5 '
        'dígitos) no se solapa con los casilleros',
        (tester) async {
          final handle = tester.ensureSemantics();
          final container = ProviderContainer(overrides: _overridesRapidos());
          addTearDown(container.dispose);
          final provider = recuerdeNumeroControllerProvider(
            GameLevel.avanzado,
          );
          container.listen(provider, (_, _) {});

          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: Scaffold(
                    appBar: AppBar(),
                    body: RecuerdeNumeroScreen(
                      run: _fakeRun(GameLevel.avanzado),
                    ),
                  ),
                ),
              ),
            ),
          );

          await _esperarFase(
            tester,
            container,
            provider,
            RecuerdeNumeroFase.esperandoRespuesta,
          );
          final numeroCorrecto = container.read(provider).numero;
          final primerDigito = int.parse(numeroCorrecto[0]);
          final otroDigito = (primerDigito + 1) % 10 == 0
              ? 1
              : (primerDigito + 1) % 10;
          await tester.tap(
            find.descendant(
              of: find.byType(RecuerdeNumeroKeypad),
              matching: find.text('$otroDigito'),
            ),
          );
          await tester.pump();
          for (var i = 1; i < numeroCorrecto.length; i++) {
            await tester.tap(
              find.descendant(
                of: find.byType(RecuerdeNumeroKeypad),
                matching: find.text(numeroCorrecto[i]),
              ),
            );
            await tester.pump();
          }
          await tester.tap(
            find.descendant(
              of: find.byType(RecuerdeNumeroKeypad),
              matching: find.text('Listo'),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          final bannerRect = tester.getRect(
            find.byKey(const ValueKey('recuerde_numero_mensaje')),
          );
          final casilleroRect = tester.getRect(
            find.bySemanticsLabel(RegExp('Casillero 1')),
          );
          expect(
            bannerRect.bottom,
            lessThanOrEqualTo(casilleroRect.top),
            reason:
                'el banner de error se solapa con los casilleros en '
                '${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
                'textScale $textScale',
          );

          handle.dispose();
          container.dispose();
        },
      );
    }
  }
}
