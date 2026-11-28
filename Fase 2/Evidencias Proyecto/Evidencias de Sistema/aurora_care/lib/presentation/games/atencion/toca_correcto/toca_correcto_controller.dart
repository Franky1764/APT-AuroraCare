// lib/presentation/games/atencion/toca_correcto/toca_correcto_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

/// Cuántas formas y colores hay (ver `tocaFormas` y `tocaColores` en
/// toca_correcto_figuras.dart). Una figura es una forma con un color.
const int tocaCantidadFormas = 6;
const int tocaCantidadColores = 5;

/// Una figura: índice de forma y de color. Los records comparan por valor,
/// así que dos figuras con la misma forma y color son iguales.
typedef TocaFiguraId = ({int forma, int color});

/// Proporción de estímulos que son el objetivo.
const double tocaProporcionObjetivos = 0.4;

/// Pausa antes de la primera figura ("Prepárese…").
const Duration tocaPausaInicial = Duration(milliseconds: 2000);

/// Cuánto se ve la respuesta (acierto, error o nada) antes de la siguiente.
const Duration tocaPausaRetro = Duration(milliseconds: 800);

/// Qué tan parecidas al objetivo son las figuras que NO hay que tocar.
enum TocaParecido {
  /// Otra forma y otro color: muy fáciles de distinguir.
  distintas,

  /// Mitad distintas y mitad parecidas.
  mezcla,

  /// Misma forma o mismo color que el objetivo: hay que fijarse más.
  parecidas,
}

/// Parámetros de un nivel (plantilla SCORING §2.5). Propuesta del dueño del
/// dominio, a calibrar en la sesión con usuarios.
class TocaNivel {
  const TocaNivel({
    required this.estimulos,
    required this.tiempoVisible,
    required this.parecido,
  });

  /// Cuántas figuras aparecen en la partida.
  final int estimulos;

  /// Cuánto se ve cada figura antes de desaparecer.
  final Duration tiempoVisible;

  /// Qué tan parecidas al objetivo son las demás figuras.
  final TocaParecido parecido;
}

TocaNivel tocaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const TocaNivel(
        estimulos: 12,
        tiempoVisible: Duration(milliseconds: 2500),
        parecido: TocaParecido.distintas,
      );
    case GameLevel.intermedio:
      return const TocaNivel(
        estimulos: 16,
        tiempoVisible: Duration(milliseconds: 1800),
        parecido: TocaParecido.mezcla,
      );
    case GameLevel.avanzado:
      return const TocaNivel(
        estimulos: 20,
        tiempoVisible: Duration(milliseconds: 1200),
        parecido: TocaParecido.parecidas,
      );
  }
}

/// true si [f] comparte la forma o el color con [objetivo] (sin ser igual).
bool tocaEsParecida(TocaFiguraId f, TocaFiguraId objetivo) =>
    f != objetivo && (f.forma == objetivo.forma || f.color == objetivo.color);

enum TocaFase {
  /// Antes de la primera figura: se muestra cuál hay que tocar.
  preparando,

  /// Hay una figura en pantalla y se puede tocar.
  mostrando,

  /// Se está mostrando qué pasó con la figura anterior.
  retro,

  /// Terminó la partida. `metrics` ya no es null.
  terminado,
}

/// Qué pasó con la última figura.
enum TocaResultado {
  /// Tocó el objetivo.
  acierto,

  /// Tocó una figura que no era el objetivo.
  tocoDistractor,

  /// No tocó el objetivo a tiempo.
  seLePaso,

  /// No tocó una figura que no era el objetivo (lo correcto).
  dejoPasar,
}

class TocaCorrectoState {
  const TocaCorrectoState({
    required this.objetivo,
    required this.figuras,
    required this.indice,
    required this.fase,
    required this.aciertos,
    required this.errores,
    required this.rachaActual,
    required this.rachaMaxima,
    required this.tiemposReaccionMs,
    this.ultimoResultado,
    this.metrics,
  });

  /// La figura que hay que tocar en esta partida (cambia en cada partida).
  final TocaFiguraId objetivo;

  /// Figuras de la partida, en orden de aparición.
  final List<TocaFiguraId> figuras;

  /// Figura actual (0 = la primera).
  final int indice;
  final TocaFase fase;
  final int aciertos;

  /// Toques a una figura incorrecta + objetivos que se dejaron pasar.
  final int errores;
  final int rachaActual;

  /// Mayor cantidad de aciertos seguidos (SCORING §2.3, "alcance").
  final int rachaMaxima;

  /// Tiempo desde que aparece el objetivo hasta que se toca, por acierto.
  final List<int> tiemposReaccionMs;
  final TocaResultado? ultimoResultado;
  final AtencionMetrics? metrics;

  TocaFiguraId get figuraActual => figuras[indice];
  bool get esObjetivo => figuraActual == objetivo;
  bool get isFinished => metrics != null;

  TocaCorrectoState copyWith({
    int? indice,
    TocaFase? fase,
    int? aciertos,
    int? errores,
    int? rachaActual,
    int? rachaMaxima,
    List<int>? tiemposReaccionMs,
    TocaResultado? ultimoResultado,
    AtencionMetrics? metrics,
  }) {
    return TocaCorrectoState(
      objetivo: objetivo,
      figuras: figuras,
      indice: indice ?? this.indice,
      fase: fase ?? this.fase,
      aciertos: aciertos ?? this.aciertos,
      errores: errores ?? this.errores,
      rachaActual: rachaActual ?? this.rachaActual,
      rachaMaxima: rachaMaxima ?? this.rachaMaxima,
      tiemposReaccionMs: tiemposReaccionMs ?? this.tiemposReaccionMs,
      ultimoResultado: ultimoResultado ?? this.ultimoResultado,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Generador para armar la partida. Sobreescribible en tests.
final tocaRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir el tiempo de reacción. Sobreescribible en tests.
final tocaClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Si es true, los temporizadores avanzan el juego solos. En tests se pone
/// en false y se llama a empezar() / expirar() / continuar() a mano.
final tocaAutoPlayProvider = Provider<bool>((ref) => true);

class TocaCorrectoController
    extends AutoDisposeFamilyNotifier<TocaCorrectoState, GameLevel> {
  Timer? _timer;
  DateTime? _aparicion;

  @override
  TocaCorrectoState build(GameLevel arg) {
    ref.onDispose(() => _timer?.cancel());
    _programar(tocaPausaInicial, empezar);

    final random = ref.read(tocaRandomProvider);
    final objetivo = (
      forma: random.nextInt(tocaCantidadFormas),
      color: random.nextInt(tocaCantidadColores),
    );
    return TocaCorrectoState(
      objetivo: objetivo,
      figuras: _armarPartida(tocaNivel(arg), objetivo, random),
      indice: 0,
      fase: TocaFase.preparando,
      aciertos: 0,
      errores: 0,
      rachaActual: 0,
      rachaMaxima: 0,
      tiemposReaccionMs: const [],
    );
  }

  /// 40% objetivos y el resto figuras distintas o parecidas según el nivel,
  /// todo mezclado.
  List<TocaFiguraId> _armarPartida(
    TocaNivel nivel,
    TocaFiguraId objetivo,
    Random random,
  ) {
    final todas = [
      for (var f = 0; f < tocaCantidadFormas; f++)
        for (var c = 0; c < tocaCantidadColores; c++) (forma: f, color: c),
    ];
    final distintas = todas
        .where((x) => x.forma != objetivo.forma && x.color != objetivo.color)
        .toList();
    final parecidas = todas.where((x) => tocaEsParecida(x, objetivo)).toList();

    List<TocaFiguraId> poolPara(int i) {
      switch (nivel.parecido) {
        case TocaParecido.distintas:
          return distintas;
        case TocaParecido.mezcla:
          return i.isEven ? distintas : parecidas;
        case TocaParecido.parecidas:
          return parecidas;
      }
    }

    final objetivos = (nivel.estimulos * tocaProporcionObjetivos).round();
    final figuras = <TocaFiguraId>[
      for (var i = 0; i < objetivos; i++) objetivo,
      for (var i = 0; i < nivel.estimulos - objetivos; i++)
        () {
          final pool = poolPara(i);
          return pool[random.nextInt(pool.length)];
        }(),
    ];
    figuras.shuffle(random);
    return figuras;
  }

  void _programar(Duration espera, void Function() accion) {
    _timer?.cancel();
    if (!ref.read(tocaAutoPlayProvider)) return;
    _timer = Timer(espera, accion);
  }

  void _mostrar() {
    _aparicion = ref.read(tocaClockProvider)();
    _programar(tocaNivel(arg).tiempoVisible, expirar);
  }

  /// Muestra la primera figura.
  void empezar() {
    if (state.fase != TocaFase.preparando) return;
    state = state.copyWith(fase: TocaFase.mostrando);
    _mostrar();
  }

  /// La persona toca la figura que está en pantalla.
  void tocar() {
    final s = state;
    if (s.fase != TocaFase.mostrando) return;
    _timer?.cancel();

    if (s.esObjetivo) {
      final ahora = ref.read(tocaClockProvider)();
      final tiempo = ahora.difference(_aparicion ?? ahora).inMilliseconds;
      final racha = s.rachaActual + 1;
      state = s.copyWith(
        fase: TocaFase.retro,
        ultimoResultado: TocaResultado.acierto,
        aciertos: s.aciertos + 1,
        rachaActual: racha,
        rachaMaxima: max(s.rachaMaxima, racha),
        tiemposReaccionMs: [...s.tiemposReaccionMs, tiempo],
      );
    } else {
      state = s.copyWith(
        fase: TocaFase.retro,
        ultimoResultado: TocaResultado.tocoDistractor,
        errores: s.errores + 1,
        rachaActual: 0,
      );
    }
    _programar(tocaPausaRetro, continuar);
  }

  /// Se acabó el tiempo de la figura sin que la persona la tocara.
  void expirar() {
    final s = state;
    if (s.fase != TocaFase.mostrando) return;

    if (s.esObjetivo) {
      state = s.copyWith(
        fase: TocaFase.retro,
        ultimoResultado: TocaResultado.seLePaso,
        errores: s.errores + 1,
        rachaActual: 0,
      );
    } else {
      state = s.copyWith(
        fase: TocaFase.retro,
        ultimoResultado: TocaResultado.dejoPasar,
      );
    }
    _programar(tocaPausaRetro, continuar);
  }

  /// Pasa a la figura siguiente o termina la partida.
  void continuar() {
    final s = state;
    if (s.fase != TocaFase.retro) return;

    if (s.indice + 1 >= s.figuras.length) {
      state = s.copyWith(fase: TocaFase.terminado, metrics: _metricas(s));
      return;
    }
    state = s.copyWith(indice: s.indice + 1, fase: TocaFase.mostrando);
    _mostrar();
  }

  /// Métricas de SCORING §2.3 para Toca el correcto.
  AtencionMetrics _metricas(TocaCorrectoState s) {
    final total = s.aciertos + s.errores;
    final promedio = s.tiemposReaccionMs.isEmpty
        ? 0
        : (s.tiemposReaccionMs.reduce((a, b) => a + b) /
                  s.tiemposReaccionMs.length)
              .round();
    return AtencionMetrics(
      tiempoRespuestaMs: promedio,
      tasaErrorPct: total == 0 ? 0.0 : s.errores / total * 100,
      alcance: s.rachaMaxima,
    );
  }
}

final tocaCorrectoControllerProvider = NotifierProvider.autoDispose
    .family<TocaCorrectoController, TocaCorrectoState, GameLevel>(
      TocaCorrectoController.new,
    );
