// domain/entities/memory_question.dart
import 'memory_answer_group.dart';

enum MemoryQuestionStatus { pendiente, respondida, omitida }

/// Una pregunta de "Mis recuerdos": sugerida (constante, ver
/// memory_suggested_questions.dart) o propia (la escribió la persona).
class MemoryQuestion {
  const MemoryQuestion({
    required this.id,
    required this.categoryId,
    required this.quizPrompt,
    this.askLabel,
    this.answer,
    required this.status,
    required this.isSuggested,
    required this.answerGroup,
  });

  final String id;
  final String categoryId;

  /// La pregunta tal como se ve en el juego, ej. "¿Cómo se llama su padre?".
  final String quizPrompt;

  /// Texto con el que se pide el dato al llenar, ej. "Nombre de su padre".
  /// Solo para preguntas sugeridas — las propias usan [quizPrompt] también
  /// al llenar, porque la persona ya la escribió como pregunta completa.
  final String? askLabel;

  final String? answer;
  final MemoryQuestionStatus status;
  final bool isSuggested;
  final MemoryAnswerGroup answerGroup;

  MemoryQuestion copyWith({String? answer, MemoryQuestionStatus? status}) {
    return MemoryQuestion(
      id: id,
      categoryId: categoryId,
      quizPrompt: quizPrompt,
      askLabel: askLabel,
      answer: answer ?? this.answer,
      status: status ?? this.status,
      isSuggested: isSuggested,
      answerGroup: answerGroup,
    );
  }
}
