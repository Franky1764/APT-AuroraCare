// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_providers.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/memories_repository_impl.provider.dart';
import '../../../../domain/entities/memory_category.dart';
import '../../../../domain/entities/memory_question.dart';

/// Categorías (predeterminadas + propias) de un usuario, en el orden en
/// que deben mostrarse en la lista.
final misRecuerdosCategoriesProvider = FutureProvider.autoDispose
    .family<List<MemoryCategory>, String>((ref, uid) {
      final repo = ref.watch(memoriesRepositoryProvider);
      return repo.loadCategories(uid);
    });

/// Preguntas (sugeridas + propias) de una categoría, para un usuario.
/// El family arg es un record (uid, categoryId) — así este provider no
/// depende de FirebaseAuth: el llamador ya resolvió el uid.
final misRecuerdosQuestionsProvider =
    FutureProvider.autoDispose.family<List<MemoryQuestion>, (String uid, String categoryId)>((
      ref,
      args,
    ) async {
      final repo = ref.watch(memoriesRepositoryProvider);
      return repo.loadQuestions(uid: args.$1, categoryId: args.$2);
    });

/// Generador para mezclar la ronda de juego. Sobreescribible en tests.
final misRecuerdosRandomProvider = Provider<Random>((ref) => Random());
