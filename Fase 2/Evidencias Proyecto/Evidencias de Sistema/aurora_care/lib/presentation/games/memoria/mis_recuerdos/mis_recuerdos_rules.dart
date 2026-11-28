// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_rules.dart
import '../../../../domain/entities/memory_question.dart';

/// Reglas de negocio de "Mis recuerdos". Lógica pura, sin Flutter —
/// testeable sin widgets.
const int minimoRespondidas = 5;
const int minimoDistintas = 4;
const int maxLargoRespuesta = 40;
const int maxLargoPreguntaPropia = 80;
const int maxLargoNombreCategoria = 40;
const int maxCategoriasPropias = 10;

String _normalizar(String texto) => texto.trim().toLowerCase();

List<MemoryQuestion> respondidasDe(List<MemoryQuestion> preguntas) =>
    preguntas.where((q) => q.status == MemoryQuestionStatus.respondida).toList();

/// Jugable si hay al menos [minimoRespondidas] respondidas Y al menos
/// [minimoDistintas] respuestas distintas entre sí (sin distinguir
/// mayúsculas ni espacios).
bool esCategoriaJugable(List<MemoryQuestion> preguntas) {
  final respondidas = respondidasDe(preguntas);
  if (respondidas.length < minimoRespondidas) return false;
  final distintas = respondidas.map((q) => _normalizar(q.answer ?? '')).toSet();
  return distintas.length >= minimoDistintas;
}

/// Cuántas respuestas más hacen falta para llegar a [minimoRespondidas]
/// (0 si ya se llegó).
int respondidasFaltantes(List<MemoryQuestion> preguntas) {
  final faltan = minimoRespondidas - respondidasDe(preguntas).length;
  return faltan > 0 ? faltan : 0;
}

/// true si se puede borrar la pregunta propia [questionId] sin dejar la
/// categoría con menos de [minimoRespondidas] respondidas.
bool puedeBorrarPropia(List<MemoryQuestion> preguntas, String questionId) {
  final pregunta = preguntas.firstWhere((q) => q.id == questionId);
  if (pregunta.status != MemoryQuestionStatus.respondida) return true;
  final respondidasSinEsta = respondidasDe(
    preguntas,
  ).where((q) => q.id != questionId).length;
  return respondidasSinEsta >= minimoRespondidas;
}

/// null si es válida; si no, el mensaje de error a mostrar.
String? validarRespuesta(String valor) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return 'Escriba una respuesta.';
  if (limpio.length > maxLargoRespuesta) {
    return 'Use como máximo $maxLargoRespuesta caracteres.';
  }
  return null;
}

String? validarPreguntaPropia(String valor) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return 'Escriba una pregunta.';
  if (limpio.length > maxLargoPreguntaPropia) {
    return 'Use como máximo $maxLargoPreguntaPropia caracteres.';
  }
  return null;
}

/// null si [valor] es un nombre de categoría válido; si no, el mensaje de
/// error a mostrar. No permite un nombre vacío ni uno repetido (sin
/// distinguir mayúsculas ni espacios al inicio/final) respecto a
/// [nombresExistentes] — las predeterminadas y las demás categorías
/// propias de la persona.
String? validarNombreCategoria(
  String valor, {
  required Iterable<String> nombresExistentes,
}) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return 'Escriba un nombre para la categoría.';
  if (limpio.length > maxLargoNombreCategoria) {
    return 'Use como máximo $maxLargoNombreCategoria caracteres.';
  }
  final normalizado = _normalizar(limpio);
  final repetido = nombresExistentes.any((n) => _normalizar(n) == normalizado);
  if (repetido) return 'Ya tiene una categoría con ese nombre.';
  return null;
}

/// true si la persona todavía puede crear otra categoría propia (no
/// llegó a [maxCategoriasPropias]).
bool puedeCrearMasCategorias(int cantidadCategoriasPropias) =>
    cantidadCategoriasPropias < maxCategoriasPropias;
