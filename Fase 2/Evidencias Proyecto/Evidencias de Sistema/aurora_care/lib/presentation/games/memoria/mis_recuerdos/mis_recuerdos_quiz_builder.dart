// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_builder.dart
import 'dart:math';

import '../../../../domain/entities/memory_question.dart';

/// Una pregunta ya armada para el juego: 4 opciones en orden aleatorio,
/// con el índice de la correcta.
class MisRecuerdosQuizQuestion {
  const MisRecuerdosQuizQuestion({
    required this.pregunta,
    required this.opciones,
    required this.indiceCorrecto,
  });

  final MemoryQuestion pregunta;
  final List<String> opciones;
  final int indiceCorrecto;
}

/// Arma una ronda de [cantidadPreguntas] preguntas al azar entre las
/// respondidas de la categoría, cada una con [cantidadOpciones] opciones:
/// la correcta y el resto incorrectas, tomadas de otras respuestas de la
/// MISMA categoría, sin duplicados (sin distinguir mayúsculas),
/// priorizando el mismo answerGroup y completando con otros grupos si no
/// alcanzan. Lógica pura, sin Flutter — testeable sin widgets.
///
/// Asume que la categoría ya es jugable (ver mis_recuerdos_rules.dart):
/// al menos [cantidadPreguntas] respondidas y al menos [cantidadOpciones]
/// respuestas distintas en total.
List<MisRecuerdosQuizQuestion> armarRonda(
  List<MemoryQuestion> preguntasCategoria, {
  int cantidadPreguntas = 5,
  int cantidadOpciones = 4,
  Random? random,
}) {
  final rnd = random ?? Random();
  final respondidas = preguntasCategoria
      .where(
        (q) =>
            q.status == MemoryQuestionStatus.respondida &&
            (q.answer?.trim().isNotEmpty ?? false),
      )
      .toList();

  final seleccion = ([...respondidas]..shuffle(rnd)).take(cantidadPreguntas).toList();

  return [
    for (final pregunta in seleccion)
      _armarPregunta(pregunta, respondidas, cantidadOpciones, rnd),
  ];
}

MisRecuerdosQuizQuestion _armarPregunta(
  MemoryQuestion pregunta,
  List<MemoryQuestion> todasRespondidas,
  int cantidadOpciones,
  Random rnd,
) {
  final respuestaCorrecta = pregunta.answer!.trim();
  final normalizadaCorrecta = respuestaCorrecta.toLowerCase();

  final candidatas = todasRespondidas.where((q) => q.id != pregunta.id).toList();
  final mismoGrupo = (candidatas.where((q) => q.answerGroup == pregunta.answerGroup).toList()
    ..shuffle(rnd));
  final otroGrupo = (candidatas.where((q) => q.answerGroup != pregunta.answerGroup).toList()
    ..shuffle(rnd));

  final incorrectas = <String>[];
  final vistas = <String>{};
  for (final q in [...mismoGrupo, ...otroGrupo]) {
    if (incorrectas.length >= cantidadOpciones - 1) break;
    final respuesta = (q.answer ?? '').trim();
    if (respuesta.isEmpty) continue;
    final normalizada = respuesta.toLowerCase();
    if (normalizada == normalizadaCorrecta) continue;
    if (vistas.contains(normalizada)) continue;
    vistas.add(normalizada);
    incorrectas.add(respuesta);
  }

  final opciones = [respuestaCorrecta, ...incorrectas]..shuffle(rnd);
  final indiceCorrecto = opciones.indexOf(respuestaCorrecta);

  return MisRecuerdosQuizQuestion(
    pregunta: pregunta,
    opciones: opciones,
    indiceCorrecto: indiceCorrecto,
  );
}
