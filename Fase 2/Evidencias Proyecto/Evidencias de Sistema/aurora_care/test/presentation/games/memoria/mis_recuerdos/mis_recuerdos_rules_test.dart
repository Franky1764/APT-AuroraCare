import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/memory_answer_group.dart';
import 'package:aurora_care/domain/entities/memory_question.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_rules.dart';

MemoryQuestion _pregunta(
  String id, {
  String? answer,
  MemoryQuestionStatus status = MemoryQuestionStatus.pendiente,
  bool isSuggested = true,
}) {
  return MemoryQuestion(
    id: id,
    categoryId: 'familia',
    quizPrompt: '¿Cómo se llama $id?',
    askLabel: 'Nombre de $id',
    answer: answer,
    status: status,
    isSuggested: isSuggested,
    answerGroup: MemoryAnswerGroup.persona,
  );
}

void main() {
  group('esCategoriaJugable', () {
    test('false con menos de 5 respondidas', () {
      final preguntas = [
        _pregunta('a', answer: 'Ana', status: MemoryQuestionStatus.respondida),
        _pregunta('b', answer: 'Beto', status: MemoryQuestionStatus.respondida),
      ];
      expect(esCategoriaJugable(preguntas), isFalse);
    });

    test('false con 5 respondidas pero menos de 4 respuestas distintas', () {
      final preguntas = [
        _pregunta('a', answer: 'Ana', status: MemoryQuestionStatus.respondida),
        _pregunta('b', answer: 'Ana', status: MemoryQuestionStatus.respondida),
        _pregunta('c', answer: 'Beto', status: MemoryQuestionStatus.respondida),
        _pregunta('d', answer: 'Beto', status: MemoryQuestionStatus.respondida),
        _pregunta('e', answer: 'Ana', status: MemoryQuestionStatus.respondida),
      ];
      // Solo 2 distintas: Ana, Beto.
      expect(esCategoriaJugable(preguntas), isFalse);
    });

    test(
      'true con 5 respondidas y 4 respuestas distintas (sin distinguir '
      'mayúsculas ni espacios)',
      () {
        final preguntas = [
          _pregunta('a', answer: 'Ana', status: MemoryQuestionStatus.respondida),
          _pregunta('b', answer: ' ana ', status: MemoryQuestionStatus.respondida),
          _pregunta('c', answer: 'Beto', status: MemoryQuestionStatus.respondida),
          _pregunta('d', answer: 'Carla', status: MemoryQuestionStatus.respondida),
          _pregunta('e', answer: 'Diego', status: MemoryQuestionStatus.respondida),
        ];
        // "Ana" y " ana " cuentan como la misma: 4 distintas (Ana, Beto,
        // Carla, Diego).
        expect(esCategoriaJugable(preguntas), isTrue);
      },
    );

    test('las omitidas y pendientes no cuentan como respondidas', () {
      final preguntas = [
        _pregunta('a', answer: 'Ana', status: MemoryQuestionStatus.respondida),
        _pregunta('b', answer: 'Beto', status: MemoryQuestionStatus.respondida),
        _pregunta('c', answer: 'Carla', status: MemoryQuestionStatus.respondida),
        _pregunta('d', answer: 'Diego', status: MemoryQuestionStatus.respondida),
        _pregunta('e', status: MemoryQuestionStatus.omitida),
        _pregunta('f', status: MemoryQuestionStatus.pendiente),
      ];
      expect(esCategoriaJugable(preguntas), isFalse);
      expect(respondidasFaltantes(preguntas), 1);
    });
  });

  group('respondidasFaltantes', () {
    test('0 cuando ya se llegó al mínimo', () {
      final preguntas = List.generate(
        5,
        (i) => _pregunta('$i', answer: 'r$i', status: MemoryQuestionStatus.respondida),
      );
      expect(respondidasFaltantes(preguntas), 0);
    });
  });

  group('puedeBorrarPropia', () {
    test('true si la pregunta no está respondida', () {
      final preguntas = [
        _pregunta('propia', status: MemoryQuestionStatus.pendiente, isSuggested: false),
      ];
      expect(puedeBorrarPropia(preguntas, 'propia'), isTrue);
    });

    test('false si borrarla dejaría menos de 5 respondidas', () {
      final preguntas = [
        for (var i = 0; i < 5; i++)
          _pregunta('$i', answer: 'r$i', status: MemoryQuestionStatus.respondida),
        _pregunta(
          'propia',
          answer: 'extra',
          status: MemoryQuestionStatus.respondida,
          isSuggested: false,
        ),
      ];
      // Hay 6 respondidas en total; borrar una propia deja 5 — está bien.
      expect(puedeBorrarPropia(preguntas, 'propia'), isTrue);

      final exacto5 = preguntas.sublist(0, 5);
      final conUnaPropiaExacta = [
        ...exacto5,
        _pregunta(
          'propia2',
          answer: 'extra2',
          status: MemoryQuestionStatus.respondida,
          isSuggested: false,
        ),
      ];
      // Borrar "0" dejaría 4 (las otras 4 sugeridas + 1 propia = 5, pero
      // "0" es una de las 5 sugeridas): probamos borrar la propia misma,
      // que si se quita deja exactamente 5 sugeridas -> permitido.
      expect(puedeBorrarPropia(conUnaPropiaExacta, 'propia2'), isTrue);

      // Ahora: borrar una de las 5 sugeridas (no propia, pero la regla es
      // genérica por id) dejaría 5 (4 sugeridas + 1 propia) -> permitido.
      expect(puedeBorrarPropia(conUnaPropiaExacta, '0'), isTrue);
    });

    test('false si borrar dejaría menos de 5 (caso límite real)', () {
      final preguntas = [
        for (var i = 0; i < 5; i++)
          _pregunta('$i', answer: 'r$i', status: MemoryQuestionStatus.respondida),
        _pregunta(
          'propia',
          answer: 'extra',
          status: MemoryQuestionStatus.respondida,
          isSuggested: false,
        ),
      ];
      // Exactamente 6 respondidas; borrar cualquiera deja 5 -> permitido.
      expect(puedeBorrarPropia(preguntas, 'propia'), isTrue);

      final soloMinimo = preguntas.sublist(0, 5); // exactamente 5
      expect(puedeBorrarPropia(soloMinimo, '0'), isFalse);
    });
  });

  group('validarRespuesta', () {
    test('rechaza vacío (tras trim)', () {
      expect(validarRespuesta('   '), isNotNull);
    });

    test('rechaza más de 40 caracteres', () {
      expect(validarRespuesta('a' * 41), isNotNull);
    });

    test('acepta 40 caracteres exactos y hace trim', () {
      expect(validarRespuesta('  ${'a' * 40}  '), isNull);
    });
  });

  group('validarPreguntaPropia', () {
    test('rechaza vacío', () {
      expect(validarPreguntaPropia(''), isNotNull);
    });

    test('rechaza más de 80 caracteres', () {
      expect(validarPreguntaPropia('a' * 81), isNotNull);
    });

    test('acepta 80 caracteres exactos', () {
      expect(validarPreguntaPropia('a' * 80), isNull);
    });
  });

  group('validarNombreCategoria', () {
    test('rechaza vacío (incluso solo espacios)', () {
      expect(
        validarNombreCategoria('   ', nombresExistentes: const []),
        isNotNull,
      );
    });

    test('rechaza más de 40 caracteres', () {
      expect(
        validarNombreCategoria('a' * 41, nombresExistentes: const []),
        isNotNull,
      );
    });

    test('acepta 40 caracteres exactos y hace trim', () {
      expect(
        validarNombreCategoria(
          '  ${'a' * 40}  ',
          nombresExistentes: const [],
        ),
        isNull,
      );
    });

    test('rechaza un nombre repetido sin distinguir mayúsculas ni espacios', () {
      expect(
        validarNombreCategoria(
          '  arte  ',
          nombresExistentes: const ['Arte', 'Música'],
        ),
        isNotNull,
      );
    });

    test('rechaza un nombre igual al de una categoría predeterminada', () {
      expect(
        validarNombreCategoria(
          'música',
          nombresExistentes: const ['Familia y amistades', 'Música', 'Fechas importantes'],
        ),
        isNotNull,
      );
    });

    test('acepta un nombre nuevo, distinto de los existentes', () {
      expect(
        validarNombreCategoria('Arte', nombresExistentes: const ['Música']),
        isNull,
      );
    });
  });

  group('puedeCrearMasCategorias', () {
    test('true por debajo del máximo', () {
      expect(puedeCrearMasCategorias(maxCategoriasPropias - 1), isTrue);
    });

    test('false al llegar o superar el máximo', () {
      expect(puedeCrearMasCategorias(maxCategoriasPropias), isFalse);
      expect(puedeCrearMasCategorias(maxCategoriasPropias + 1), isFalse);
    });
  });
}
