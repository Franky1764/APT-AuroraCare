// domain/repositories/memories_repository.dart
import '../entities/memory_category.dart';
import '../entities/memory_question.dart';

/// "Mis recuerdos": datos personales que la persona completa y luego
/// juega a recordar. SOLO se guardan en el dispositivo — nunca Firestore,
/// FastAPI, OpenAI ni Analytics. No pasa por GameShell/FinishSession
/// (como Respiración guiada): sin puntaje, sin UUID cognitivo.
abstract class MemoriesRepository {
  /// Las 3 categorías predeterminadas, seguidas de las categorías propias
  /// de [uid] (en el orden en que se crearon). Las predeterminadas son
  /// constantes; las propias se leen del almacenamiento local de [uid].
  Future<List<MemoryCategory>> loadCategories(String uid);

  /// Crea una categoría propia para [uid] con nombre [name]. No valida
  /// reglas de negocio (nombre vacío, repetido, límite máximo): eso lo
  /// hace la pantalla antes de llamar, igual que con las preguntas
  /// propias (ver mis_recuerdos_rules.dart). Lanza
  /// [MemoriesStorageException] si falla la escritura.
  Future<MemoryCategory> createCategory({
    required String uid,
    required String name,
  });

  /// Renombra una categoría propia. Lanza [ArgumentError] si [categoryId]
  /// no existe o es una categoría predeterminada.
  Future<void> renameCategory({
    required String uid,
    required String categoryId,
    required String name,
  });

  /// Borra una categoría propia y, en la misma escritura, todas sus
  /// preguntas propias (ninguna pregunta queda huérfana). Lanza
  /// [ArgumentError] si [categoryId] no existe o es una categoría
  /// predeterminada (esas no se pueden borrar).
  Future<void> deleteCategory({
    required String uid,
    required String categoryId,
  });

  /// Preguntas (sugeridas + propias) de [categoryId] para [uid]. Las
  /// sugeridas nunca tocadas llegan con status=pendiente y answer=null.
  /// Si el almacenamiento está corrupto o es de una versión desconocida,
  /// se trata como "sin datos" (todas pendientes, sin preguntas propias)
  /// sin lanzar y sin sobrescribir lo guardado.
  Future<List<MemoryQuestion>> loadQuestions({
    required String uid,
    required String categoryId,
  });

  /// Guarda la respuesta de una pregunta (sugerida o propia) y la marca
  /// como respondida. Lanza [MemoriesStorageException] si falla.
  Future<void> saveAnswer({
    required String uid,
    required String questionId,
    required String answer,
  });

  /// Guarda varias respuestas de preguntas SUGERIDAS en una sola
  /// operación: una sola lectura y una sola escritura del almacenamiento,
  /// para que la pantalla de llenado pueda guardar todos los campos
  /// modificados al tocar "Guardar" sin que una escritura pise a otra.
  ///
  /// [answers] es un mapa questionId → texto ya recortado (trim). Un
  /// valor vacío borra la respuesta: la pregunta vuelve a "pendiente"
  /// (o se mantiene "omitida" si ya lo estaba). Lanza [ArgumentError] si
  /// algún id no es una pregunta sugerida, y [MemoriesStorageException]
  /// si falla la escritura.
  Future<void> saveAnswers({
    required String uid,
    required Map<String, String> answers,
  });

  /// Solo para preguntas sugeridas. Lanza [ArgumentError] si [questionId]
  /// no es una pregunta sugerida.
  Future<void> omitQuestion({required String uid, required String questionId});

  /// Deshace una omisión: vuelve a respondida si ya tenía una respuesta
  /// guardada, o a pendiente si no.
  Future<void> undoOmit({required String uid, required String questionId});

  /// Agrega una pregunta propia a una categoría predeterminada. Queda
  /// respondida de inmediato (se escribe junto con su respuesta).
  Future<MemoryQuestion> addCustomQuestion({
    required String uid,
    required String categoryId,
    required String quizPrompt,
    required String answer,
  });

  /// Solo para preguntas propias. Lanza [ArgumentError] si [questionId]
  /// no es una pregunta propia o no existe.
  Future<void> editCustomQuestion({
    required String uid,
    required String questionId,
    String? quizPrompt,
    String? answer,
  });

  /// Solo para preguntas propias.
  Future<void> deleteCustomQuestion({
    required String uid,
    required String questionId,
  });

  /// ¿Ya se mostró el aviso de privacidad de "Mis recuerdos" a [uid]?
  Future<bool> hasSeenPrivacyNotice(String uid);

  Future<void> markPrivacyNoticeSeen(String uid);

  /// Borra TODOS los datos locales de "Mis recuerdos" para [uid]
  /// (respuestas, preguntas propias, flag de aviso visto). Pensado para
  /// que lo llame el futuro flujo de cancelación de cuenta (ARCO) — ese
  /// flujo todavía no existe en el repo (privacy/placeholder.dart está
  /// vacío); este método es el punto de enganche cuando se construya.
  /// Recibe [uid] explícito — no depende de FirebaseAuth.currentUser —
  /// para poder borrar aunque la sesión ya se haya cerrado.
  Future<void> deleteAllForUser(String uid);
}
