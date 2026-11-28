import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_controller.dart';

/// Timer falso para la vista previa: en vez de esperar la duración real
/// (hasta 13 s en Avanzado), guarda el callback y lo deja disparar a
/// mano con [endPreview].
class _FakePreviewTimer implements Timer {
  bool _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

class _FakePreviewTimerFactory {
  Duration? duracionPedida;
  void Function()? _callback;

  Timer call(Duration duration, void Function() callback) {
    duracionPedida = duration;
    _callback = callback;
    return _FakePreviewTimer();
  }

  void endPreview() => _callback!();
}

/// Encuentra el primer par (i, j) con faceIndex igual que todavía no esté
/// emparejado. Evita depender del orden exacto del mezclado.
(int, int) _findPair(MemoriceClasicoState state) {
  for (var i = 0; i < state.cards.length; i++) {
    if (state.cards[i].isMatched) continue;
    for (var j = i + 1; j < state.cards.length; j++) {
      if (state.cards[j].isMatched) continue;
      if (state.cards[i].faceIndex == state.cards[j].faceIndex) {
        return (i, j);
      }
    }
  }
  throw StateError('No quedan pares sin emparejar');
}

/// Encuentra dos cartas (a, b) con faceIndex distinto, ninguna emparejada.
(int, int) _findMismatch(MemoriceClasicoState state) {
  for (var i = 0; i < state.cards.length; i++) {
    if (state.cards[i].isMatched) continue;
    for (var j = i + 1; j < state.cards.length; j++) {
      if (state.cards[j].isMatched) continue;
      if (state.cards[i].faceIndex != state.cards[j].faceIndex) {
        return (i, j);
      }
    }
  }
  throw StateError('No se encontraron dos cartas distintas');
}

void main() {
  test('paresParaNivel: 6/8/10 según Fácil/Intermedio/Avanzado', () {
    expect(paresParaNivel(GameLevel.facil), 6);
    expect(paresParaNivel(GameLevel.intermedio), 8);
    expect(paresParaNivel(GameLevel.avanzado), 10);
  });

  test(
    'memoricePreviewDuration: 3 s + 1 s por pareja (9/11/13 s)',
    () {
      expect(memoricePreviewDuration(GameLevel.facil), const Duration(seconds: 9));
      expect(
        memoricePreviewDuration(GameLevel.intermedio),
        const Duration(seconds: 11),
      );
      expect(
        memoricePreviewDuration(GameLevel.avanzado),
        const Duration(seconds: 13),
      );
    },
  );

  test(
    'al iniciar, todas las cartas están boca arriba (vista previa) y no '
    'responden al toque',
    () {
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);
      final state = container.read(provider);

      expect(state.cards.length, 12);
      expect(state.totalPares, 6);
      expect(state.isPreviewPhase, isTrue);
      expect(state.cards.every((c) => c.isFaceUp && !c.isMatched), isTrue);
      expect(fakePreview.duracionPedida, const Duration(seconds: 9));

      final counts = <int, int>{};
      for (final card in state.cards) {
        counts[card.faceIndex] = (counts[card.faceIndex] ?? 0) + 1;
      }
      expect(counts.values, everyElement(2));

      // Tocar durante la vista previa no hace nada: ni intentos ni
      // cartas cambian.
      notifier.flipCard(0);
      final despuesDelToque = container.read(provider);
      expect(despuesDelToque.intentos, 0);
      expect(despuesDelToque, same(state));
    },
  );

  test(
    'tras la duración de la vista previa las cartas se tapan y empiezan a '
    'responder',
    () {
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);

      fakePreview.endPreview();
      final state = container.read(provider);
      expect(state.isPreviewPhase, isFalse);
      expect(state.cards.every((c) => !c.isFaceUp), isTrue);

      notifier.flipCard(0);
      expect(container.read(provider).cards[0].isFaceUp, isTrue);
      expect(container.read(provider).intentos, 1);
    },
  );

  test(
    'el reloj de la partida no avanza durante la vista previa: arranca '
    'al taparse las cartas, no en el primer volteo',
    () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoriceClockProvider.overrideWithValue(() => fakeNow),
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      // Pasan 9 s "de reloj" mientras se supone que dura la vista previa:
      // no deben contar.
      fakeNow = fakeNow.add(const Duration(seconds: 9));
      fakePreview.endPreview();

      // El reloj YA arrancó al tapar las cartas: este 1 s antes del
      // primer toque sí cuenta.
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      final (a, b) = _findPair(container.read(provider));
      notifier.flipCard(a);
      fakeNow = fakeNow.add(const Duration(seconds: 4));
      notifier.flipCard(b);

      // Encuentra el resto de los pares para terminar la partida.
      for (var p = 0; p < 5; p++) {
        final state = container.read(provider);
        if (state.isFinished) break;
        final (i, j) = _findPair(state);
        notifier.flipCard(i);
        notifier.flipCard(j);
      }

      final metrics = container.read(provider).metrics!;
      // 1 s (tapadas, antes del primer toque) + 4 s (entre el primer y
      // segundo volteo del primer par). Los 9 s de vista previa no
      // cuentan.
      expect(metrics.tiempoSegundos, 5);
    },
  );

  test(
    'pausar()/reanudar(): el tiempo pausado (ej. "Ver cómo se juega") '
    'no cuenta en tiempoSegundos',
    () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoriceClockProvider.overrideWithValue(() => fakeNow),
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      fakePreview.endPreview();

      // Abre "Ver cómo se juega" antes del primer toque: 30 s pausados.
      notifier.pausar();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      notifier.reanudar();

      final (a, b) = _findPair(container.read(provider));
      notifier.flipCard(a);
      fakeNow = fakeNow.add(const Duration(seconds: 6));
      notifier.flipCard(b);

      for (var p = 0; p < 5; p++) {
        final state = container.read(provider);
        if (state.isFinished) break;
        final (i, j) = _findPair(state);
        notifier.flipCard(i);
        notifier.flipCard(j);
      }

      final metrics = container.read(provider).metrics!;
      // Solo los 6 s entre el primer y segundo volteo: los 30 s de
      // pausa no cuentan.
      expect(metrics.tiempoSegundos, 6);
    },
  );

  test('reanudar() sin pausar() antes no hace nada (idempotente)', () {
    final fakePreview = _FakePreviewTimerFactory();
    final container = ProviderContainer(
      overrides: [
        memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
      ],
    );
    addTearDown(container.dispose);

    final provider = memoriceClasicoControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);
    fakePreview.endPreview();

    expect(() => notifier.reanudar(), returnsNormally);
  });

  test('pausar() no hace nada si la partida ya terminó', () {
    var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
    final fakePreview = _FakePreviewTimerFactory();
    final container = ProviderContainer(
      overrides: [
        memoriceClockProvider.overrideWithValue(() => fakeNow),
        memoriceMismatchDelayProvider.overrideWithValue(
          const Duration(milliseconds: 5),
        ),
        memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
      ],
    );
    addTearDown(container.dispose);

    final provider = memoriceClasicoControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier);
    fakePreview.endPreview();

    for (var p = 0; p < 6; p++) {
      final state = container.read(provider);
      if (state.isFinished) break;
      final (i, j) = _findPair(state);
      notifier.flipCard(i);
      notifier.flipCard(j);
    }
    expect(container.read(provider).isFinished, isTrue);

    final metricsAntes = container.read(provider).metrics;
    notifier.pausar();
    fakeNow = fakeNow.add(const Duration(seconds: 100));
    notifier.reanudar();
    expect(container.read(provider).metrics, same(metricsAntes));
  });

  test(
    'al reiniciar (nueva instancia del controlador) la vista previa se '
    'repite',
    () {
      final fakePreview1 = _FakePreviewTimerFactory();
      final container1 = ProviderContainer(
        overrides: [
          memoricePreviewTimerFactoryProvider.overrideWithValue(
            fakePreview1.call,
          ),
        ],
      );
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      expect(container1.read(provider).isPreviewPhase, isTrue);
      fakePreview1.endPreview();
      expect(container1.read(provider).isPreviewPhase, isFalse);
      container1.dispose();

      // "Reiniciar" en este juego significa una instancia nueva del
      // controlador (ver Paso 0): no hay forma de barajar de nuevo sin
      // salir y volver a entrar a la pantalla, lo que destruye y
      // recrea el provider autoDispose.
      final fakePreview2 = _FakePreviewTimerFactory();
      final container2 = ProviderContainer(
        overrides: [
          memoricePreviewTimerFactoryProvider.overrideWithValue(
            fakePreview2.call,
          ),
        ],
      );
      addTearDown(container2.dispose);
      expect(container2.read(provider).isPreviewPhase, isTrue);
    },
  );

  test(
    'un par correcto suma 1 a paresEncontrados y 2 a intentos, sin errores',
    () {
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);
      fakePreview.endPreview();

      final (i, j) = _findPair(container.read(provider));
      notifier.flipCard(i);
      expect(container.read(provider).intentos, 1);

      notifier.flipCard(j);
      final state = container.read(provider);
      expect(state.intentos, 2);
      expect(state.errores, 0);
      expect(state.paresEncontrados, 1);
      expect(state.cards[i].isMatched, isTrue);
      expect(state.cards[j].isMatched, isTrue);
      expect(state.locked, isFalse);
    },
  );

  test(
    'un error bloquea una tercera carta hasta que se resuelve el temporizador',
    () async {
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      // El provider es autoDispose: sin un listener activo, Riverpod lo
      // destruye (cancelando su Timer) en cuanto el test hace un await,
      // perdiendo el progreso de la partida. Mantenerlo vivo es necesario
      // para testear algo que depende de tiempo real.
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);
      fakePreview.endPreview();

      final (a, b) = _findMismatch(container.read(provider));
      notifier.flipCard(a);
      notifier.flipCard(b);

      var state = container.read(provider);
      expect(state.errores, 1);
      expect(state.locked, isTrue);
      expect(state.cards[a].isFaceUp, isTrue);
      expect(state.cards[b].isFaceUp, isTrue);

      // Tercera carta distinta: ignorada mientras locked == true.
      final blockedIndex = state.cards.indexWhere(
        (c) => !c.isMatched && !c.isFaceUp,
      );
      final intentosAntes = state.intentos;
      notifier.flipCard(blockedIndex);
      state = container.read(provider);
      expect(state.intentos, intentosAntes);
      expect(state.cards[blockedIndex].isFaceUp, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      state = container.read(provider);
      expect(state.locked, isFalse);
      expect(state.cards[a].isFaceUp, isFalse);
      expect(state.cards[b].isFaceUp, isFalse);
      expect(state.revealedIndices, isEmpty);
    },
  );

  test(
    'al encontrar el último par, metrics queda con errores/intentos/tiempo/'
    'tasaAciertoPct correctos y el juego no acepta más toques',
    () async {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final fakePreview = _FakePreviewTimerFactory();
      final container = ProviderContainer(
        overrides: [
          memoriceClockProvider.overrideWithValue(() => fakeNow),
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          memoricePreviewTimerFactoryProvider.overrideWithValue(fakePreview.call),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      // Ídem: sin listener, el provider autoDispose se destruye en el
      // primer await y pierde el progreso de la partida.
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);
      fakePreview.endPreview();

      // 1 error antes de empezar a emparejar.
      final (a, b) = _findMismatch(container.read(provider));
      notifier.flipCard(a);
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      notifier.flipCard(b);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      fakeNow = fakeNow.add(const Duration(seconds: 9));

      // Encuentra los 6 pares.
      for (var p = 0; p < 6; p++) {
        final state = container.read(provider);
        if (state.isFinished) break;
        final (i, j) = _findPair(state);
        notifier.flipCard(i);
        notifier.flipCard(j);
      }

      final finalState = container.read(provider);
      expect(finalState.isFinished, isTrue);
      final metrics = finalState.metrics!;

      expect(metrics.errores, 1);
      // 2 toques del error + 2 toques por cada uno de los 6 pares = 14.
      expect(metrics.intentos, 14);
      expect(metrics.tiempoSegundos, 10);
      // 6 pares correctos / (6 + 1 error) * 100.
      expect(metrics.tasaAciertoPct, closeTo(85.7, 0.1));

      // El juego ya terminó: tocar cualquier carta no hace nada.
      final beforeFinish = container.read(provider);
      notifier.flipCard(0);
      expect(container.read(provider), same(beforeFinish));
    },
  );
}
