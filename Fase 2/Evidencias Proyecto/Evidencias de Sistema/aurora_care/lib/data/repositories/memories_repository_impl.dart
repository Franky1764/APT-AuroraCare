// data/repositories/memories_repository_impl.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/memory_answer_group.dart';
import '../../domain/entities/memory_category.dart';
import '../../domain/entities/memory_question.dart';
import '../../domain/entities/memory_suggested_questions.dart';
import '../../domain/exceptions/memories_exception.dart';
import '../../domain/repositories/memories_repository.dart';

const _keyPrefix = 'mis_recuerdos_v1_';
const _storageVersion = 1;

const List<MemoryCategory> _categoriasPredeterminadas = [
  MemoryCategory(
    id: 'familia',
    name: 'Familia y amistades',
    isPredefined: true,
    iconKey: 'familia',
  ),
  MemoryCategory(
    id: 'musica',
    name: 'Música',
    isPredefined: true,
    iconKey: 'musica',
  ),
  MemoryCategory(
    id: 'fechas',
    name: 'Fechas importantes',
    isPredefined: true,
    iconKey: 'fechas',
  ),
];

/// Implementación local de MemoriesRepository: SharedPreferences +
/// dart:convert, un solo JSON por usuario (clave `mis_recuerdos_v1_<uid>`).
/// Las preguntas sugeridas NUNCA se guardan en el JSON (son constantes de
/// domain/) — solo se guarda, por id, su respuesta y estado. Nada de esto
/// se registra en logs: el contenido puede ser información personal.
class MemoriesRepositoryImpl implements MemoriesRepository {
  MemoriesRepositoryImpl(this._prefs, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final SharedPreferences _prefs;
  final Uuid _uuid;

  /// Cola simple para serializar las escrituras: cada operación de
  /// lectura-modificación-escritura espera a que termine la anterior
  /// antes de leer el blob, para que dos operaciones seguidas (ej. dos
  /// toques rápidos, o dos pantallas) nunca se pisen entre sí.
  Future<void> _colaEscritura = Future<void>.value();

  Future<T> _conEscrituraSerializada<T>(Future<T> Function() accion) {
    final resultado = _colaEscritura.then((_) => accion());
    _colaEscritura = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }

  @override
  Future<List<MemoryCategory>> loadCategories(String uid) async {
    final raw = _readRaw(uid);
    final propias = (raw['categoriasPropias'] as List).cast<dynamic>();
    final categoriasPropias = propias.whereType<Map>().map(
      (m) => MemoryCategory(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        isPredefined: false,
        iconKey: 'personalizada',
      ),
    );
    return [..._categoriasPredeterminadas, ...categoriasPropias];
  }

  bool _esPredeterminada(String categoryId) =>
      _categoriasPredeterminadas.any((c) => c.id == categoryId);

  @override
  Future<MemoryCategory> createCategory({
    required String uid,
    required String name,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['categoriasPropias'] as List).cast<dynamic>();
      final id = 'custom_cat_${_uuid.v4()}';
      propias.add({'id': id, 'name': name});
      raw['categoriasPropias'] = propias;
      await _writeRaw(uid, raw);
      return MemoryCategory(
        id: id,
        name: name,
        isPredefined: false,
        iconKey: 'personalizada',
      );
    });
  }

  @override
  Future<void> renameCategory({
    required String uid,
    required String categoryId,
    required String name,
  }) {
    if (_esPredeterminada(categoryId)) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Las categorías predeterminadas no se pueden renombrar',
      );
    }
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['categoriasPropias'] as List).cast<dynamic>();
      final idx = propias.indexWhere((m) => m is Map && m['id'] == categoryId);
      if (idx == -1) {
        throw ArgumentError.value(categoryId, 'categoryId', 'No existe');
      }
      final actual = (propias[idx] as Map).cast<String, dynamic>();
      propias[idx] = {...actual, 'name': name};
      raw['categoriasPropias'] = propias;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> deleteCategory({
    required String uid,
    required String categoryId,
  }) {
    if (_esPredeterminada(categoryId)) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Las categorías predeterminadas no se pueden borrar',
      );
    }
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['categoriasPropias'] as List).cast<dynamic>();
      final existia = propias.any((m) => m is Map && m['id'] == categoryId);
      if (!existia) {
        throw ArgumentError.value(categoryId, 'categoryId', 'No existe');
      }
      propias.removeWhere((m) => m is Map && m['id'] == categoryId);
      raw['categoriasPropias'] = propias;
      // Borra también sus preguntas propias: ninguna queda huérfana
      // apuntando a una categoría que ya no existe.
      final preguntas = (raw['preguntasPropias'] as List).cast<dynamic>();
      preguntas.removeWhere((m) => m is Map && m['categoryId'] == categoryId);
      raw['preguntasPropias'] = preguntas;
      await _writeRaw(uid, raw);
    });
  }

  String _keyFor(String uid) => '$_keyPrefix$uid';

  /// Lee y decodifica el blob del usuario. Si no existe, está corrupto o
  /// es de una versión que este código no reconoce, se trata como "sin
  /// datos" (blob vacío EN MEMORIA) sin tocar el almacenamiento: no se
  /// sobrescribe nada hasta que la persona haga una acción que de verdad
  /// guarde algo.
  Map<String, dynamic> _readRaw(String uid) {
    final stored = _prefs.getString(_keyFor(uid));
    if (stored == null) return _blobVacio();
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return _blobVacio();
      if (decoded['version'] != _storageVersion) return _blobVacio();
      decoded['respuestasSugeridas'] ??= <String, dynamic>{};
      decoded['preguntasPropias'] ??= <dynamic>[];
      decoded['categoriasPropias'] ??= <dynamic>[];
      decoded['avisoPrivacidadVisto'] ??= false;
      return decoded;
    } catch (_) {
      // JSON corrupto: se trata como "sin datos". No se registra el
      // contenido (podría ser información personal).
      return _blobVacio();
    }
  }

  Map<String, dynamic> _blobVacio() => {
    'version': _storageVersion,
    'avisoPrivacidadVisto': false,
    'respuestasSugeridas': <String, dynamic>{},
    'preguntasPropias': <dynamic>[],
    'categoriasPropias': <dynamic>[],
  };

  Future<void> _writeRaw(String uid, Map<String, dynamic> data) async {
    bool ok;
    try {
      ok = await _prefs.setString(_keyFor(uid), jsonEncode(data));
    } catch (_) {
      throw const MemoriesStorageException();
    }
    if (!ok) throw const MemoriesStorageException();
  }

  MemoryQuestionStatus _parseStatus(Object? value) {
    return MemoryQuestionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MemoryQuestionStatus.pendiente,
    );
  }

  bool _esSugerida(String questionId) =>
      memorySuggestedQuestions.any((q) => q.id == questionId);

  @override
  Future<List<MemoryQuestion>> loadQuestions({
    required String uid,
    required String categoryId,
  }) async {
    final raw = _readRaw(uid);
    final respuestas = (raw['respuestasSugeridas'] as Map).cast<String, dynamic>();
    final propias = (raw['preguntasPropias'] as List).cast<dynamic>();

    final sugeridas = memorySuggestedQuestions
        .where((q) => q.categoryId == categoryId)
        .map((q) {
          final guardado = respuestas[q.id];
          if (guardado is! Map) return q;
          final status = _parseStatus(guardado['status']);
          final answer = guardado['answer'] as String?;
          return q.copyWith(answer: answer, status: status);
        });

    final custom = propias
        .whereType<Map>()
        .where((m) => m['categoryId'] == categoryId)
        .map(
          (m) => MemoryQuestion(
            id: m['id'] as String,
            categoryId: m['categoryId'] as String,
            quizPrompt: m['quizPrompt'] as String? ?? '',
            answer: m['answer'] as String?,
            status: _parseStatus(m['status']),
            isSuggested: false,
            answerGroup: MemoryAnswerGroup.otro,
          ),
        );

    return [...sugeridas, ...custom];
  }

  @override
  Future<void> saveAnswer({
    required String uid,
    required String questionId,
    required String answer,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      if (_esSugerida(questionId)) {
        final respuestas = (raw['respuestasSugeridas'] as Map).cast<String, dynamic>();
        respuestas[questionId] = {
          'answer': answer,
          'status': MemoryQuestionStatus.respondida.name,
        };
        raw['respuestasSugeridas'] = respuestas;
      } else {
        final propias = (raw['preguntasPropias'] as List).cast<dynamic>();
        final idx = propias.indexWhere((m) => m is Map && m['id'] == questionId);
        if (idx == -1) {
          throw ArgumentError.value(questionId, 'questionId', 'No existe');
        }
        final actual = (propias[idx] as Map).cast<String, dynamic>();
        propias[idx] = {
          ...actual,
          'answer': answer,
          'status': MemoryQuestionStatus.respondida.name,
        };
        raw['preguntasPropias'] = propias;
      }
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> saveAnswers({
    required String uid,
    required Map<String, String> answers,
  }) {
    if (answers.isEmpty) return Future<void>.value();
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final respuestas = (raw['respuestasSugeridas'] as Map).cast<String, dynamic>();
      for (final entry in answers.entries) {
        final questionId = entry.key;
        if (!_esSugerida(questionId)) {
          throw ArgumentError.value(questionId, 'questionId', 'No existe');
        }
        final answer = entry.value.trim();
        if (answer.isEmpty) {
          final actual = respuestas[questionId];
          final estabaOmitida = actual is Map &&
              _parseStatus(actual['status']) == MemoryQuestionStatus.omitida;
          respuestas[questionId] = {
            'answer': null,
            'status': estabaOmitida
                ? MemoryQuestionStatus.omitida.name
                : MemoryQuestionStatus.pendiente.name,
          };
        } else {
          respuestas[questionId] = {
            'answer': answer,
            'status': MemoryQuestionStatus.respondida.name,
          };
        }
      }
      raw['respuestasSugeridas'] = respuestas;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> omitQuestion({
    required String uid,
    required String questionId,
  }) {
    if (!_esSugerida(questionId)) {
      throw ArgumentError.value(
        questionId,
        'questionId',
        'Solo las preguntas sugeridas se pueden omitir',
      );
    }
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final respuestas = (raw['respuestasSugeridas'] as Map).cast<String, dynamic>();
      final actual = respuestas[questionId];
      final answer = actual is Map ? actual['answer'] as String? : null;
      respuestas[questionId] = {
        'answer': answer,
        'status': MemoryQuestionStatus.omitida.name,
      };
      raw['respuestasSugeridas'] = respuestas;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> undoOmit({
    required String uid,
    required String questionId,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final respuestas = (raw['respuestasSugeridas'] as Map).cast<String, dynamic>();
      final actual = respuestas[questionId];
      final answer = actual is Map ? actual['answer'] as String? : null;
      respuestas[questionId] = {
        'answer': answer,
        'status': (answer != null && answer.trim().isNotEmpty)
            ? MemoryQuestionStatus.respondida.name
            : MemoryQuestionStatus.pendiente.name,
      };
      raw['respuestasSugeridas'] = respuestas;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<MemoryQuestion> addCustomQuestion({
    required String uid,
    required String categoryId,
    required String quizPrompt,
    required String answer,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['preguntasPropias'] as List).cast<dynamic>();
      final id = 'custom_${_uuid.v4()}';
      propias.add({
        'id': id,
        'categoryId': categoryId,
        'quizPrompt': quizPrompt,
        'answer': answer,
        'status': MemoryQuestionStatus.respondida.name,
      });
      raw['preguntasPropias'] = propias;
      await _writeRaw(uid, raw);
      return MemoryQuestion(
        id: id,
        categoryId: categoryId,
        quizPrompt: quizPrompt,
        answer: answer,
        status: MemoryQuestionStatus.respondida,
        isSuggested: false,
        answerGroup: MemoryAnswerGroup.otro,
      );
    });
  }

  @override
  Future<void> editCustomQuestion({
    required String uid,
    required String questionId,
    String? quizPrompt,
    String? answer,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['preguntasPropias'] as List).cast<dynamic>();
      final idx = propias.indexWhere((m) => m is Map && m['id'] == questionId);
      if (idx == -1) {
        throw ArgumentError.value(questionId, 'questionId', 'No existe');
      }
      final actual = (propias[idx] as Map).cast<String, dynamic>();
      propias[idx] = {
        ...actual,
        'quizPrompt': ?quizPrompt,
        'answer': ?answer,
        'status': MemoryQuestionStatus.respondida.name,
      };
      raw['preguntasPropias'] = propias;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> deleteCustomQuestion({
    required String uid,
    required String questionId,
  }) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      final propias = (raw['preguntasPropias'] as List).cast<dynamic>();
      propias.removeWhere((m) => m is Map && m['id'] == questionId);
      raw['preguntasPropias'] = propias;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<bool> hasSeenPrivacyNotice(String uid) async {
    final raw = _readRaw(uid);
    return raw['avisoPrivacidadVisto'] == true;
  }

  @override
  Future<void> markPrivacyNoticeSeen(String uid) {
    return _conEscrituraSerializada(() async {
      final raw = _readRaw(uid);
      raw['avisoPrivacidadVisto'] = true;
      await _writeRaw(uid, raw);
    });
  }

  @override
  Future<void> deleteAllForUser(String uid) {
    return _conEscrituraSerializada(() => _prefs.remove(_keyFor(uid)));
  }
}
