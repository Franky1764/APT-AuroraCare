import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/memory_answer_group.dart';
import 'package:aurora_care/domain/entities/memory_question.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_builder.dart';

MemoryQuestion _r(
  String id,
  String answer, {
  MemoryAnswerGroup grupo = MemoryAnswerGroup.persona,
}) {
  return MemoryQuestion(
    id: id,
    categoryId: 'familia',
    quizPrompt: '¿Cómo se llama $id?',
    askLabel: 'Nombre de $id',
    answer: answer,
    status: MemoryQuestionStatus.respondida,
    isSuggested: true,
    answerGroup: grupo,
  );
}

void main() {
  test('cada pregunta de la ronda tiene 4 opciones únicas, una correcta', () {
    final preguntas = [
      _r('padre', 'Juan'),
      _r('madre', 'Rosa'),
      _r('pareja', 'Ana'),
      _r('hijo', 'Pedro'),
      _r('hermano', 'Luis'),
    ];

    final ronda = armarRonda(preguntas, random: Random(1));

    expect(ronda.length, 5);
    for (final q in ronda) {
      expect(q.opciones.length, 4);
      expect(q.opciones.toSet().length, 4); // sin duplicados
      expect(q.opciones[q.indiceCorrecto], q.pregunta.answer);
    }
  });

  test('prioriza el mismo answerGroup para las opciones incorrectas', () {
    final preguntas = [
      _r('padre', 'Juan', grupo: MemoryAnswerGroup.persona),
      _r('madre', 'Rosa', grupo: MemoryAnswerGroup.persona),
      _r('pareja', 'Ana', grupo: MemoryAnswerGroup.persona),
      _r('hijo', 'Pedro', grupo: MemoryAnswerGroup.persona),
      _r('cancion', 'Bésame mucho', grupo: MemoryAnswerGroup.cancion),
    ];

    // Busca específicamente la ronda armada para "padre" probando varias
    // semillas si hace falta, ya que la selección de la pregunta en sí
    // también es al azar.
    for (var semilla = 0; semilla < 20; semilla++) {
      final r = armarRonda(preguntas, cantidadPreguntas: 1, random: Random(semilla));
      final pregunta = r.first;
      if (pregunta.pregunta.id != 'padre') continue;
      // Las 3 incorrectas deberían ser Rosa, Ana, Pedro (mismo grupo),
      // nunca "Bésame mucho" (único de otro grupo), ya que hay 3
      // candidatas del mismo grupo disponibles.
      expect(pregunta.opciones, isNot(contains('Bésame mucho')));
      return;
    }
    fail('No se generó ninguna ronda para "padre" en 20 intentos');
  });

  test('completa con otros grupos si no alcanzan del mismo', () {
    final preguntas = [
      _r('padre', 'Juan', grupo: MemoryAnswerGroup.persona),
      _r('madre', 'Rosa', grupo: MemoryAnswerGroup.persona),
      _r('cancion', 'Bésame mucho', grupo: MemoryAnswerGroup.cancion),
      _r('fecha', '12 de mayo', grupo: MemoryAnswerGroup.fecha),
    ];

    final ronda = armarRonda(
      preguntas,
      cantidadPreguntas: 1,
      random: Random(3),
    );
    final pregunta = ronda.first;
    // Solo hay 1 candidata del mismo grupo (persona) además de la
    // correcta: las otras 2 opciones deben completarse con otros grupos.
    expect(pregunta.opciones.length, 4);
    expect(pregunta.opciones.toSet().length, 4);
  });

  test('no repite preguntas en la misma ronda', () {
    final preguntas = List.generate(
      8,
      (i) => _r('p$i', 'respuesta$i'),
    );
    final ronda = armarRonda(preguntas, random: Random(4));
    final ids = ronda.map((q) => q.pregunta.id).toSet();
    expect(ids.length, ronda.length);
  });

  test('ignora preguntas no respondidas', () {
    final preguntas = [
      _r('padre', 'Juan'),
      _r('madre', 'Rosa'),
      MemoryQuestion(
        id: 'omitida',
        categoryId: 'familia',
        quizPrompt: '¿...?',
        status: MemoryQuestionStatus.omitida,
        isSuggested: true,
        answerGroup: MemoryAnswerGroup.persona,
      ),
    ];
    final ronda = armarRonda(preguntas, cantidadPreguntas: 5, random: Random(5));
    expect(ronda.length, 2); // solo las 2 respondidas
    expect(ronda.any((q) => q.pregunta.id == 'omitida'), isFalse);
  });

  test(
    'una categoría 100% propia (sin preguntas sugeridas, todas '
    'answerGroup=otro) arma una ronda válida sin respuestas falsas: las '
    'opciones incorrectas son las respuestas reales de las otras '
    'preguntas propias',
    () {
      final preguntas = [
        for (final par in const {
          'cuadro': 'La Gioconda',
          'pintor': 'Matisse',
          'museo': 'El Louvre',
          'tecnica': 'Óleo',
          'periodo': 'Impresionismo',
        }.entries)
          MemoryQuestion(
            id: 'custom_${par.key}',
            categoryId: 'custom_cat_1',
            quizPrompt: '¿Mi ${par.key} favorito?',
            answer: par.value,
            status: MemoryQuestionStatus.respondida,
            isSuggested: false,
            answerGroup: MemoryAnswerGroup.otro,
          ),
      ];

      final ronda = armarRonda(preguntas, random: Random(7));

      expect(ronda.length, 5);
      for (final q in ronda) {
        expect(q.opciones.length, 4);
        expect(q.opciones.toSet().length, 4);
        expect(q.opciones[q.indiceCorrecto], q.pregunta.answer);
        // Las incorrectas son respuestas reales de otras preguntas de la
        // misma categoría, nunca un texto inventado.
        for (final opcion in q.opciones) {
          expect(preguntas.map((p) => p.answer), contains(opcion));
        }
      }
    },
  );
}
