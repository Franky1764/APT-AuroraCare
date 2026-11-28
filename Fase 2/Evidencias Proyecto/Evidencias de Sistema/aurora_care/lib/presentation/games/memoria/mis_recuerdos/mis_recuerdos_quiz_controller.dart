// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/memories_repository_impl.provider.dart';
import 'mis_recuerdos_providers.dart';
import 'mis_recuerdos_quiz_builder.dart';

class MisRecuerdosQuizState {
  const MisRecuerdosQuizState({
    required this.preguntas,
    required this.indiceActual,
    required this.opcionElegida,
    required this.aciertos,
  });

  final List<MisRecuerdosQuizQuestion> preguntas;
  final int indiceActual;

  /// Índice de la opción que la persona tocó en la pregunta actual, o
  /// null si todavía no responde esta pregunta.
  final int? opcionElegida;

  final int aciertos;

  int get total => preguntas.length;

  /// true cuando ya se respondieron todas las preguntas de la ronda.
  bool get terminada => indiceActual >= total;

  MisRecuerdosQuizQuestion get actual => preguntas[indiceActual];
  bool get respondioActual => opcionElegida != null;
  bool get esCorrectaElegida => opcionElegida == actual.indiceCorrecto;

  MisRecuerdosQuizState copyWith({
    int? indiceActual,
    int? opcionElegida,
    int? aciertos,
    bool limpiarOpcion = false,
  }) {
    return MisRecuerdosQuizState(
      preguntas: preguntas,
      indiceActual: indiceActual ?? this.indiceActual,
      opcionElegida: limpiarOpcion ? null : (opcionElegida ?? this.opcionElegida),
      aciertos: aciertos ?? this.aciertos,
    );
  }
}

/// Partida de "Mis recuerdos" para una categoría. A diferencia de los
/// otros juegos de Memoria, no tiene niveles ni maxDuration — es un
/// AsyncNotifier porque armar la ronda requiere leer el repositorio
/// (asíncrono). El family arg es un record (uid, categoryId): no depende
/// de FirebaseAuth, el llamador ya resolvió el uid.
class MisRecuerdosQuizController
    extends
        AutoDisposeFamilyAsyncNotifier<
          MisRecuerdosQuizState,
          (String uid, String categoryId)
        > {
  @override
  Future<MisRecuerdosQuizState> build((String uid, String categoryId) args) async {
    final repo = ref.read(memoriesRepositoryProvider);
    final preguntas = await repo.loadQuestions(
      uid: args.$1,
      categoryId: args.$2,
    );
    final random = ref.read(misRecuerdosRandomProvider);
    final ronda = armarRonda(preguntas, random: random);
    return MisRecuerdosQuizState(
      preguntas: ronda,
      indiceActual: 0,
      opcionElegida: null,
      aciertos: 0,
    );
  }

  void elegirOpcion(int indice) {
    final current = state.valueOrNull;
    if (current == null || current.terminada || current.respondioActual) return;
    state = AsyncData(current.copyWith(opcionElegida: indice));
  }

  void siguiente() {
    final current = state.valueOrNull;
    if (current == null || !current.respondioActual) return;
    final acerto = current.esCorrectaElegida;
    state = AsyncData(
      current.copyWith(
        indiceActual: current.indiceActual + 1,
        aciertos: current.aciertos + (acerto ? 1 : 0),
        limpiarOpcion: true,
      ),
    );
  }
}

final misRecuerdosQuizControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      MisRecuerdosQuizController,
      MisRecuerdosQuizState,
      (String uid, String categoryId)
    >(MisRecuerdosQuizController.new);
