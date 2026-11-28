// domain/entities/memory_answer_group.dart

/// Agrupa preguntas de "Mis recuerdos" por el tipo de respuesta que
/// esperan, para elegir opciones incorrectas parecidas al armar una ronda
/// de juego (ej. si la correcta es un nombre de persona, las incorrectas
/// también deberían serlo, no una fecha).
enum MemoryAnswerGroup {
  persona,
  cancion,
  artista,
  genero,
  instrumento,
  fecha,
  anio,

  /// Preguntas propias: no tienen un grupo predefinido.
  otro,
}
